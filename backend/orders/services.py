import logging
from datetime import datetime, timedelta

import requests
from django.conf import settings
from django.db import transaction
from django.db.models import Q, Sum
from django.utils import timezone

from catalog.services.saby_catalog_service import SabyCatalogService
from customers.models import BonusTransaction
from orders.delivery_schedule import min_delivery_datetime
from orders.models import Order

logger = logging.getLogger(__name__)


class SabyOrderError(Exception):
    """Ошибка создания заказа в Saby Presto."""


class OrderReturnError(Exception):
    """Ошибка частичного возврата заказа."""


def rollback_order(order: Order):
    """
    Полный откат бонусов по заказу (отмена / полный возврат).

    Учитывает уже оформленные частичные возвраты: откатывает только остаток
    начисления и невозвращённую часть списания.
    """
    from customers.models import Customer
    from orders.models import OrderReturn

    if order.bonus_compensated:
        return

    if order.customer_id is None:
        return

    with transaction.atomic():
        # Нельзя select_related('customer'): nullable FK даёт LEFT JOIN,
        # а PostgreSQL запрещает FOR UPDATE на nullable стороне join.
        locked_order = Order.objects.select_for_update().get(pk=order.pk)

        if locked_order.bonus_compensated:
            return

        customer = (
            Customer.objects.select_for_update()
            .get(pk=locked_order.customer_id)
        )

        already_reversed = (
            OrderReturn.objects.filter(order_id=locked_order.id)
            .aggregate(total=Sum('bonus_earned_reversed'))
            .get('total')
            or 0
        )
        already_restored = (
            OrderReturn.objects.filter(order_id=locked_order.id)
            .aggregate(total=Sum('bonus_spent_restored'))
            .get('total')
            or 0
        )

        earn_to_claw = max(int(locked_order.bonus_earned or 0) - already_reversed, 0)
        spent_to_restore = max(int(locked_order.bonus_spent or 0) - already_restored, 0)

        if earn_to_claw > 0:
            earn_was_credited = BonusTransaction.objects.filter(
                customer=customer,
                order_id=locked_order.id,
                transaction_type=BonusTransaction.TransactionType.EARN,
            ).exists()

            if earn_was_credited:
                customer.bonus_balance = max(
                    0,
                    customer.bonus_balance - earn_to_claw,
                )

                BonusTransaction.objects.create(
                    customer=customer,
                    transaction_type=BonusTransaction.TransactionType.REFUND,
                    amount=-earn_to_claw,
                    order_id=locked_order.id,
                    comment=(
                        f'Отмена заказа №{locked_order.id}. '
                        f'Отмена начисления бонусов.'
                    ),
                )

        if spent_to_restore > 0:
            customer.bonus_balance += spent_to_restore

            BonusTransaction.objects.create(
                customer=customer,
                transaction_type=BonusTransaction.TransactionType.REFUND,
                amount=spent_to_restore,
                order_id=locked_order.id,
                comment=(
                    f'Отмена заказа №{locked_order.id}. '
                    f'Возврат списанных бонусов.'
                ),
            )

        if locked_order.first_order_discount_applied:
            completed_discount_orders = (
                Order.objects.filter(
                    customer=customer,
                    first_order_discount_applied=True,
                    status=Order.Status.DONE,
                )
                .exclude(id=locked_order.id)
                .exists()
            )

            if not completed_discount_orders:
                customer.first_order_discount_available = True
                customer.first_order_discount_used = False

        customer.save()

        locked_order.bonus_compensated = True
        locked_order.save(update_fields=['bonus_compensated'])

        order.bonus_compensated = True


def format_phone_for_saby(phone: str) -> str:
    digits = ''.join(char for char in str(phone or '') if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return f'+{digits}'

    return str(phone or '').strip()


from orders.delivery_pricing import get_default_locality, get_delivery_zone_title


def build_saby_comment(order: Order) -> str:
    """Комментарий для операторов Saby Presto (время, тип доставки, клиент)."""
    lines = [
        f'Доставка: {get_delivery_zone_title(order.delivery_type)}',
    ]

    if (
        order.delivery_time_type == Order.DeliveryTimeType.BY_TIME
        and order.delivery_time
    ):
        lines.append(
            f'Время: Ко времени {order.delivery_time.strip()}'
        )
    else:
        lines.append('Время: Как можно скорее')

    if order.discount_amount > 0:
        if order.delivery_type == Order.DeliveryType.PICKUP:
            lines.append(
                f'Скидка самовывоза 5% (в ценах позиций): −{order.discount_amount} ₽'
            )
        else:
            lines.append(f'Скидка: −{order.discount_amount} ₽')

    if order.bonus_spent > 0:
        lines.append(f'Списание бонусов: −{order.bonus_spent} ₽')

    lines.append('Источник: приложение Delycafe')

    header = '\n'.join(lines)
    customer_comment = (order.comment or '').strip()

    if customer_comment:
        return f'{header}\n---\n{customer_comment}'

    return header


def order_already_in_saby(order: Order) -> bool:
    return bool(order.saby_sale_id or order.saby_order_number)


def saby_external_id(order: Order) -> str:
    return (order.saby_external_id or str(order.id)).strip()


def save_saby_order_response(order: Order, saby_response: dict) -> None:
    order_number = (
        saby_response.get('orderNumber')
        or saby_response.get('order_number')
    )
    sale_id = (
        saby_response.get('sale_id')
        or saby_response.get('saleId')
    )
    # saleKey — UUID для bonus-write-off / register-payment.
    external_id = (
        saby_response.get('saleKey')
        or saby_response.get('sale_key')
        or saby_response.get('externalId')
        or saby_response.get('external_id')
    )

    update_fields = []

    if order_number is not None and str(order_number).strip():
        order.saby_order_number = str(order_number)
        update_fields.append('saby_order_number')

    if sale_id is not None and str(sale_id).strip():
        order.saby_sale_id = str(sale_id)
        update_fields.append('saby_sale_id')

    if external_id is not None and str(external_id).strip():
        order.saby_external_id = str(external_id)
        update_fields.append('saby_external_id')

    if update_fields:
        order.saby_dispatch_error = ''
        update_fields.append('saby_dispatch_error')
        order.save(update_fields=update_fields)


def register_saby_payment(order: Order) -> dict | None:
    """Регистрирует онлайн-оплату в Saby и пробивает чек (кнопка «Оплачено»)."""
    with transaction.atomic():
        locked_order = Order.objects.select_for_update().get(pk=order.pk)

        if locked_order.saby_payment_registered:
            logger.info(
                'Order #%s Saby payment already registered, skipping',
                locked_order.id,
            )
            return None

        if locked_order.payment_status != Order.PaymentStatus.PAID:
            logger.warning(
                'Order #%s is not paid, skipping Saby payment registration',
                locked_order.id,
            )
            return None

        if not order_already_in_saby(locked_order):
            raise SabyOrderError(
                'Нельзя зарегистрировать оплату в Saby: заказ ещё не создан.'
            )

        try:
            SabyOrderService().apply_bonuses(locked_order)
            locked_order.refresh_from_db()
            response = SabyOrderService().register_payment(locked_order)
        except SabyOrderError as exc:
            locked_order.saby_payment_error = str(exc)
            locked_order.save(
                update_fields=['saby_payment_error', 'updated_at'],
            )
            raise

        locked_order.saby_payment_registered = True
        locked_order.saby_payment_error = ''
        locked_order.save(
            update_fields=[
                'saby_payment_registered',
                'saby_payment_error',
                'updated_at',
            ]
        )
        order_pk = locked_order.pk

    # Локальный ledger: начисляем 3% в приложении (идемпотентно).
    paid_order = Order.objects.get(pk=order_pk)
    _record_bonus_earn(paid_order)

    return response


def _try_register_saby_payment(order: Order) -> None:
    try:
        register_saby_payment(order)
    except SabyOrderError:
        logger.exception(
            'Failed to register Saby payment for order #%s',
            order.id,
        )


def _record_bonus_earn(order: Order) -> None:
    """Начисляет бонусы на локальный баланс после успешной оплаты."""
    from customers.models import Customer

    if (
        order.payment_status != Order.PaymentStatus.PAID
        or order.bonus_earned <= 0
        or order.customer_id is None
    ):
        return

    with transaction.atomic():
        customer = (
            Customer.objects.select_for_update()
            .get(pk=order.customer_id)
        )

        already_recorded = BonusTransaction.objects.filter(
            customer_id=customer.pk,
            order_id=order.id,
            transaction_type=BonusTransaction.TransactionType.EARN,
        ).exists()

        if already_recorded:
            return

        BonusTransaction.objects.create(
            customer=customer,
            transaction_type=BonusTransaction.TransactionType.EARN,
            amount=order.bonus_earned,
            order_id=order.id,
            comment=(
                f'Начисление {order.bonus_earned} бонусов (3%) '
                f'по заказу #{order.id}'
            ),
        )
        customer.bonus_balance += order.bonus_earned
        customer.save(update_fields=['bonus_balance', 'updated_at'])


def apply_partial_order_return(
    order: Order,
    items: list[tuple],
    *,
    comment: str = '',
):
    """
    Частичный возврат позиций с пропорциональным откатом бонусов.

    items: список (OrderItem | id, quantity).
    """
    from customers.models import Customer
    from orders.models import OrderItem, OrderReturn, OrderReturnItem

    if not items:
        raise OrderReturnError('Нужна хотя бы одна позиция возврата')

    with transaction.atomic():
        locked_order = Order.objects.select_for_update().get(pk=order.pk)

        if locked_order.bonus_compensated:
            raise OrderReturnError(
                'Заказ уже полностью компенсирован — частичный возврат невозможен',
            )

        if locked_order.payment_status not in (
            Order.PaymentStatus.PAID,
            Order.PaymentStatus.REFUNDED,
        ):
            raise OrderReturnError('Возврат только для оплаченных заказов')

        already_reversed = (
            OrderReturn.objects.filter(order_id=locked_order.id)
            .aggregate(total=Sum('bonus_earned_reversed'))
            .get('total')
            or 0
        )
        already_restored = (
            OrderReturn.objects.filter(order_id=locked_order.id)
            .aggregate(total=Sum('bonus_spent_restored'))
            .get('total')
            or 0
        )

        remaining_earn = max(
            int(locked_order.bonus_earned or 0) - already_reversed,
            0,
        )
        remaining_spent = max(
            int(locked_order.bonus_spent or 0) - already_restored,
            0,
        )

        products_base = max(int(locked_order.products_total or 0), 1)
        returned_sum = 0
        normalized: list[tuple[OrderItem, int]] = []

        for raw_item, qty in items:
            qty = int(qty)
            if qty <= 0:
                raise OrderReturnError('Количество возврата должно быть > 0')

            if isinstance(raw_item, OrderItem):
                order_item = raw_item
            else:
                order_item = OrderItem.objects.get(pk=raw_item)

            if order_item.order_id != locked_order.id:
                raise OrderReturnError(
                    f'Позиция #{order_item.id} не принадлежит заказу',
                )

            already_qty = (
                OrderReturnItem.objects.filter(order_item_id=order_item.id)
                .aggregate(total=Sum('quantity'))
                .get('total')
                or 0
            )
            if already_qty + qty > order_item.quantity:
                raise OrderReturnError(
                    f'По позиции «{order_item.product_title}» можно вернуть '
                    f'ещё {order_item.quantity - already_qty} шт.',
                )

            line_total = int(order_item.price) * qty
            returned_sum += line_total
            normalized.append((order_item, qty))

        earn_reverse = 0
        if remaining_earn > 0 and locked_order.customer_id:
            earn_was_credited = BonusTransaction.objects.filter(
                customer_id=locked_order.customer_id,
                order_id=locked_order.id,
                transaction_type=BonusTransaction.TransactionType.EARN,
            ).exists()
            if earn_was_credited:
                earn_reverse = min(
                    remaining_earn,
                    locked_order.bonus_earned * returned_sum // products_base,
                )

        spent_restore = 0
        if remaining_spent > 0:
            spent_restore = min(
                remaining_spent,
                locked_order.bonus_spent * returned_sum // products_base,
            )

        order_return = OrderReturn.objects.create(
            order=locked_order,
            comment=comment or '',
            products_total=returned_sum,
            bonus_earned_reversed=earn_reverse,
            bonus_spent_restored=spent_restore,
            bonuses_applied=True,
        )

        for order_item, qty in normalized:
            OrderReturnItem.objects.create(
                order_return=order_return,
                order_item=order_item,
                quantity=qty,
                product_title=order_item.product_title,
                price=order_item.price,
                total_price=order_item.price * qty,
            )

        if locked_order.customer_id and (earn_reverse or spent_restore):
            customer = (
                Customer.objects.select_for_update()
                .get(pk=locked_order.customer_id)
            )
            if earn_reverse > 0:
                customer.bonus_balance = max(
                    0,
                    customer.bonus_balance - earn_reverse,
                )
                BonusTransaction.objects.create(
                    customer=customer,
                    transaction_type=BonusTransaction.TransactionType.REFUND,
                    amount=-earn_reverse,
                    order_id=locked_order.id,
                    comment=(
                        f'Частичный возврат заказа №{locked_order.id}. '
                        f'Отмена начисления {earn_reverse} бонусов.'
                    ),
                )
            if spent_restore > 0:
                customer.bonus_balance += spent_restore
                BonusTransaction.objects.create(
                    customer=customer,
                    transaction_type=BonusTransaction.TransactionType.REFUND,
                    amount=spent_restore,
                    order_id=locked_order.id,
                    comment=(
                        f'Частичный возврат заказа №{locked_order.id}. '
                        f'Возврат {spent_restore} списанных бонусов.'
                    ),
                )
            customer.save(update_fields=['bonus_balance', 'updated_at'])

        return order_return


def settle_order_return(order_return) -> None:
    """Применяет бонусный откат к уже сохранённому возврату (админка)."""
    from customers.models import Customer
    from orders.models import OrderReturn, OrderReturnItem

    if order_return.pk is None:
        return

    with transaction.atomic():
        locked_return = (
            OrderReturn.objects.select_for_update().get(pk=order_return.pk)
        )
        if locked_return.bonuses_applied:
            return

        item_rows = list(
            OrderReturnItem.objects.filter(order_return_id=locked_return.pk)
            .select_related('order_item')
        )
        if not item_rows:
            return

        locked_order = Order.objects.select_for_update().get(
            pk=locked_return.order_id,
        )

        if locked_order.bonus_compensated:
            raise OrderReturnError(
                'Заказ уже полностью компенсирован — частичный возврат невозможен',
            )

        if locked_order.payment_status not in (
            Order.PaymentStatus.PAID,
            Order.PaymentStatus.REFUNDED,
        ):
            raise OrderReturnError('Возврат только для оплаченных заказов')

        other_returns = OrderReturn.objects.filter(
            order_id=locked_order.id,
        ).exclude(pk=locked_return.pk)

        already_reversed = (
            other_returns.aggregate(total=Sum('bonus_earned_reversed'))
            .get('total')
            or 0
        )
        already_restored = (
            other_returns.aggregate(total=Sum('bonus_spent_restored'))
            .get('total')
            or 0
        )

        remaining_earn = max(
            int(locked_order.bonus_earned or 0) - already_reversed,
            0,
        )
        remaining_spent = max(
            int(locked_order.bonus_spent or 0) - already_restored,
            0,
        )

        products_base = max(int(locked_order.products_total or 0), 1)
        returned_sum = 0

        for row in item_rows:
            qty = int(row.quantity)
            if qty <= 0:
                raise OrderReturnError('Количество возврата должно быть > 0')

            order_item = row.order_item
            if order_item.order_id != locked_order.id:
                raise OrderReturnError(
                    f'Позиция #{order_item.id} не принадлежит заказу',
                )

            already_qty = (
                OrderReturnItem.objects.filter(order_item_id=order_item.id)
                .exclude(order_return_id=locked_return.pk)
                .aggregate(total=Sum('quantity'))
                .get('total')
                or 0
            )
            if already_qty + qty > order_item.quantity:
                raise OrderReturnError(
                    f'По позиции «{order_item.product_title}» можно вернуть '
                    f'ещё {order_item.quantity - already_qty} шт.',
                )

            returned_sum += int(order_item.price) * qty
            row.product_title = order_item.product_title
            row.price = order_item.price
            row.total_price = order_item.price * qty
            row.save(
                update_fields=['product_title', 'price', 'total_price'],
            )

        earn_reverse = 0
        if remaining_earn > 0 and locked_order.customer_id:
            earn_was_credited = BonusTransaction.objects.filter(
                customer_id=locked_order.customer_id,
                order_id=locked_order.id,
                transaction_type=BonusTransaction.TransactionType.EARN,
            ).exists()
            if earn_was_credited:
                earn_reverse = min(
                    remaining_earn,
                    locked_order.bonus_earned * returned_sum // products_base,
                )

        spent_restore = 0
        if remaining_spent > 0:
            spent_restore = min(
                remaining_spent,
                locked_order.bonus_spent * returned_sum // products_base,
            )

        locked_return.products_total = returned_sum
        locked_return.bonus_earned_reversed = earn_reverse
        locked_return.bonus_spent_restored = spent_restore
        locked_return.bonuses_applied = True
        locked_return.save(
            update_fields=[
                'products_total',
                'bonus_earned_reversed',
                'bonus_spent_restored',
                'bonuses_applied',
            ],
        )

        if locked_order.customer_id and (earn_reverse or spent_restore):
            customer = (
                Customer.objects.select_for_update()
                .get(pk=locked_order.customer_id)
            )
            if earn_reverse > 0:
                customer.bonus_balance = max(
                    0,
                    customer.bonus_balance - earn_reverse,
                )
                BonusTransaction.objects.create(
                    customer=customer,
                    transaction_type=BonusTransaction.TransactionType.REFUND,
                    amount=-earn_reverse,
                    order_id=locked_order.id,
                    comment=(
                        f'Частичный возврат заказа №{locked_order.id}. '
                        f'Отмена начисления {earn_reverse} бонусов.'
                    ),
                )
            if spent_restore > 0:
                customer.bonus_balance += spent_restore
                BonusTransaction.objects.create(
                    customer=customer,
                    transaction_type=BonusTransaction.TransactionType.REFUND,
                    amount=spent_restore,
                    order_id=locked_order.id,
                    comment=(
                        f'Частичный возврат заказа №{locked_order.id}. '
                        f'Возврат {spent_restore} списанных бонусов.'
                    ),
                )
            customer.save(update_fields=['bonus_balance', 'updated_at'])

        order_return.bonuses_applied = True
        order_return.products_total = returned_sum
        order_return.bonus_earned_reversed = earn_reverse
        order_return.bonus_spent_restored = spent_restore



def _dispatch_order_to_saby_core(order: Order) -> dict | None:
    """Создаёт заказ в Saby. Вызывать только под блокировкой строки заказа."""
    if order_already_in_saby(order):
        logger.info(
            'Order #%s already exists in Saby, skipping dispatch',
            order.id,
        )
        return None

    if order.payment_status != Order.PaymentStatus.PAID:
        logger.warning(
            'Order #%s is not paid yet, skipping Saby dispatch',
            order.id,
        )
        return None

    try:
        response = SabyOrderService().create_order(order)
        order.refresh_from_db()
        _try_register_saby_payment(order)
        return response
    except SabyOrderError as exc:
        order.saby_dispatch_error = str(exc)
        order.save(update_fields=['saby_dispatch_error', 'updated_at'])
        logger.exception('Failed to dispatch order #%s to Saby', order.id)
        raise


def dispatch_order_to_saby(order: Order) -> dict | None:
    """Отправляет оплаченный заказ в Saby. Повторный вызов безопасен."""
    with transaction.atomic():
        locked_order = Order.objects.select_for_update().get(pk=order.pk)
        return _dispatch_order_to_saby_core(locked_order)


def confirm_order_paid(order: Order) -> Order:
    """Фиксирует оплату и отправляет заказ в Saby."""
    order_id = order.pk

    with transaction.atomic():
        locked_order = Order.objects.select_for_update().get(pk=order_id)
        update_fields = []

        if locked_order.payment_status != Order.PaymentStatus.PAID:
            locked_order.payment_status = Order.PaymentStatus.PAID
            update_fields.append('payment_status')

            if locked_order.status == Order.Status.NEW:
                locked_order.status = Order.Status.ACCEPTED
                update_fields.append('status')

            if not locked_order.paid_at:
                locked_order.paid_at = timezone.now()
                update_fields.append('paid_at')

        if update_fields:
            update_fields.append('updated_at')
            locked_order.save(update_fields=update_fields)

    try:
        from orders.order_notification_service import try_send_admin_order_email

        try_send_admin_order_email(order_id)
    except Exception:
        logger.exception(
            'Failed to send admin email for order #%s after payment',
            order_id,
        )

    with transaction.atomic():
        locked_order = Order.objects.select_for_update().get(pk=order_id)

        if not order_already_in_saby(locked_order):
            try:
                _dispatch_order_to_saby_core(locked_order)
            except SabyOrderError:
                pass
        elif not locked_order.saby_payment_registered:
            _try_register_saby_payment(locked_order)

    order = Order.objects.get(pk=order_id)
    _record_bonus_earn(order)

    if order_already_in_saby(order):
        try:
            from orders.saby_order_status_service import SabyOrderStatusService

            SabyOrderStatusService().sync_order_status(order)
        except Exception:
            logger.exception(
                'Failed to sync Saby status for order #%s after payment',
                order.id,
            )

    return order


def retry_pending_saby_dispatches(*, limit: int = 50) -> dict[str, int]:
    """Повторно отправляет в Saby оплаченные заказы без sale_id."""
    pending_orders = list(
        Order.objects.filter(
            payment_status=Order.PaymentStatus.PAID,
            saby_sale_id='',
            saby_order_number='',
        ).order_by('paid_at', 'created_at')[:limit]
    )

    success_count = 0
    failed_count = 0

    for order in pending_orders:
        try:
            dispatch_order_to_saby(order)
            success_count += 1
        except SabyOrderError:
            failed_count += 1

    return {
        'checked': len(pending_orders),
        'success': success_count,
        'failed': failed_count,
    }


def retry_pending_saby_payments(*, limit: int = 50) -> dict[str, int]:
    """Повторно регистрирует оплату в Saby для заказов без чека."""
    pending_orders = list(
        Order.objects.filter(
            payment_status=Order.PaymentStatus.PAID,
            saby_payment_registered=False,
        ).filter(
            Q(saby_sale_id__gt='') | Q(saby_order_number__gt=''),
        ).order_by('paid_at', 'created_at')[:limit]
    )

    success_count = 0
    failed_count = 0

    for order in pending_orders:
        try:
            register_saby_payment(order)
            success_count += 1
        except SabyOrderError:
            failed_count += 1

    return {
        'checked': len(pending_orders),
        'success': success_count,
        'failed': failed_count,
    }


class SabyOrderService:
    ORDER_URL = 'https://api.sbis.ru/retail/order/create'
    REGISTER_PAYMENT_URL = (
        'https://api.sbis.ru/retail/order/{external_id}/register-payment'
    )
    BONUS_WRITE_OFF_URL = (
        'https://api.sbis.ru/retail/order/{external_id}/bonus-write-off'
    )
    BONUS_READ_URL = (
        'https://api.sbis.ru/retail/order/{external_id}/bonus-read'
    )

    def create_order(self, order: Order) -> dict:
        nomenclatures = self._build_nomenclatures(order)

        if not nomenclatures:
            missing = [
                item.product_title
                for item in order.items.all()
                if not item.saby_id
            ]
            raise SabyOrderError(
                'Не удалось отправить заказ в Saby: у позиций нет saby_id. '
                f'Проверьте каталог: {", ".join(missing) or "нет позиций"}.'
            )

        payload = self._build_payload(order, nomenclatures)
        token = SabyCatalogService().get_token()

        logger.info('Saby order create payload for order #%s: %s', order.id, payload)

        response = requests.post(
            self.ORDER_URL,
            headers={
                'X-SBISAccessToken': token,
                'Content-Type': 'application/json',
            },
            json=payload,
            timeout=60,
        )

        logger.info(
            'Saby order create response for order #%s: status=%s body=%s',
            order.id,
            response.status_code,
            response.text,
        )

        try:
            saby_response = response.json()
        except ValueError as exc:
            raise SabyOrderError(
                f'Saby вернул не-JSON ответ (HTTP {response.status_code}).'
            ) from exc

        if response.status_code >= 400:
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        result_code = saby_response.get('resultCode')
        if result_code not in (0, '0', None):
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        if result_code in (0, '0', None):
            save_saby_order_response(order, saby_response)

        order.refresh_from_db()

        if not order.saby_sale_id and not order.saby_order_number:
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        return saby_response

    def apply_bonuses(self, order: Order) -> dict | None:
        """Списывает или инициирует начисление бонусов в Saby (до оплаты)."""
        if order.saby_bonus_applied:
            logger.info(
                'Order #%s Saby bonuses already applied, skipping',
                order.id,
            )
            return None

        if not order_already_in_saby(order):
            raise SabyOrderError(
                'Нельзя применить бонусы в Saby: заказ ещё не создан.'
            )

        response = self.write_off_bonuses(order)

        order.saby_bonus_applied = True
        order.save(update_fields=['saby_bonus_applied', 'updated_at'])

        # История и баланс — после register-payment (см. register_saby_payment).

        return response

    def write_off_bonuses(self, order: Order) -> dict:
        """
        POST bonus-write-off.

        bonusDec > 0 — списание; 0/null — начисление по программе лояльности.
        """
        external_id = saby_external_id(order)
        bonus_dec = int(order.bonus_spent or 0)
        payload = {
            # 0 — начислить по акции Saby без списания.
            'bonusDec': bonus_dec if bonus_dec > 0 else 0,
        }

        token = SabyCatalogService().get_token()
        url = self.BONUS_WRITE_OFF_URL.format(external_id=external_id)

        logger.info(
            'Saby bonus-write-off payload for order #%s: %s',
            order.id,
            payload,
        )

        response = requests.post(
            url,
            headers={
                'X-SBISAccessToken': token,
                'Content-Type': 'application/json',
            },
            json=payload,
            timeout=60,
        )

        logger.info(
            'Saby bonus-write-off response for order #%s: status=%s body=%s',
            order.id,
            response.status_code,
            response.text,
        )

        try:
            saby_response = response.json() if response.content else {}
        except ValueError as exc:
            raise SabyOrderError(
                'Saby вернул не-JSON ответ при списании бонусов '
                f'(HTTP {response.status_code}).'
            ) from exc

        if response.status_code >= 400:
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        result_code = saby_response.get('resultCode')
        if result_code not in (0, '0', None):
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        return saby_response

    def register_payment(self, order: Order) -> dict:
        amount = order.payment_amount or order.total_price

        if amount <= 0:
            raise SabyOrderError(
                'Сумма оплаты для Saby должна быть больше 0.'
            )

        external_id = saby_external_id(order)
        payload = {
            'bankSum': amount,
            'paymentType': 'full',
        }

        retail_place = (getattr(settings, 'SABY_RETAIL_PLACE', '') or '').strip()
        if retail_place:
            payload['retailPlace'] = retail_place

        token = SabyCatalogService().get_token()
        url = self.REGISTER_PAYMENT_URL.format(external_id=external_id)

        logger.info(
            'Saby register-payment payload for order #%s: %s',
            order.id,
            payload,
        )

        response = requests.post(
            url,
            headers={
                'X-SBISAccessToken': token,
                'Content-Type': 'application/json',
            },
            json=payload,
            timeout=60,
        )

        logger.info(
            'Saby register-payment response for order #%s: status=%s body=%s',
            order.id,
            response.status_code,
            response.text,
        )

        try:
            saby_response = response.json()
        except ValueError as exc:
            raise SabyOrderError(
                'Saby вернул не-JSON ответ при регистрации оплаты '
                f'(HTTP {response.status_code}).'
            ) from exc

        if response.status_code >= 400:
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        result_code = saby_response.get('resultCode')
        if result_code not in (0, '0', None):
            raise SabyOrderError(
                self._extract_error_message(saby_response, response.status_code)
            )

        return saby_response

    def _build_nomenclatures(self, order: Order) -> list[dict]:
        """
        При самовывозе cost уже со скидкой 5% (зеркало расчёта в приложении).

        Акция Saby «Скидка на самовывоз» на API-заказы обычно не срабатывает —
        урезание cost нужно, чтобы bankSum = итог продажи и чек АТОЛ закрывался.
        """
        from orders.promotions import PICKUP_DISCOUNT_PERCENT

        nomenclatures = []
        apply_pickup_discount = (
            order.delivery_type == Order.DeliveryType.PICKUP
            and order.discount_amount > 0
            and PICKUP_DISCOUNT_PERCENT > 0
        )

        for item in order.items.all():
            if not item.saby_id:
                continue

            unit_cost = item.price
            if apply_pickup_discount:
                unit_cost = max(
                    0,
                    item.price * (100 - PICKUP_DISCOUNT_PERCENT) // 100,
                )

            entry = {
                'id': item.saby_id,
                'priceListId': settings.SABY_PRICE_LIST_ID,
                'count': item.quantity,
                'name': item.product_title,
                'cost': unit_cost,
            }

            if item.variant_title:
                entry['name'] = (
                    f'{item.product_title} ({item.variant_title})'
                )

            nomenclatures.append(entry)

        return nomenclatures

    def _build_payload(self, order: Order, nomenclatures: list[dict]) -> dict:
        is_pickup = order.delivery_type == Order.DeliveryType.PICKUP
        delivery_time = self._resolve_delivery_datetime(order)

        return {
            'product': 'delivery',
            'pointId': settings.SABY_POINT_ID,
            'externalId': saby_external_id(order),
            'comment': build_saby_comment(order),
            'customer': {
                'name': order.customer_name or 'Клиент',
                'phone': format_phone_for_saby(order.phone),
            },
            'datetime': delivery_time.strftime('%Y-%m-%d %H:%M:%S'),
            'nomenclatures': nomenclatures,
            'delivery': {
                'addressJSON': self._build_delivery_address_json(
                    order,
                    is_pickup,
                ),
            },
            'isPickup': is_pickup,
            'paymentType': 'online',
        }

    def _build_delivery_address_json(
        self,
        order: Order,
        is_pickup: bool,
    ) -> dict:
        if is_pickup:
            return {
                'Address': 'Самовывоз',
                'isPickup': True,
            }

        locality = (
            order.address_locality
            or get_default_locality(order.delivery_type)
        )

        address_json = {
            'Locality': locality,
            'Address': order.address or 'Адрес не указан',
            'isPickup': False,
        }

        if order.address_entrance:
            address_json['Entrance'] = order.address_entrance

        if order.address_floor:
            address_json['Floor'] = order.address_floor

        if order.address_apartment:
            address_json['AptNum'] = order.address_apartment

        return address_json

    def _resolve_delivery_datetime(self, order: Order) -> datetime:
        if (
            order.delivery_time_type == Order.DeliveryTimeType.BY_TIME
            and order.delivery_time
        ):
            today = timezone.localdate()
            for fmt in ('%H:%M', '%H:%M:%S'):
                try:
                    parsed_time = datetime.strptime(
                        order.delivery_time.strip(),
                        fmt,
                    ).time()
                    return timezone.make_aware(
                        datetime.combine(today, parsed_time)
                    )
                except ValueError:
                    continue

        return min_delivery_datetime(
            timezone.localtime(),
            order.delivery_type,
        )

    def _extract_error_message(self, payload: dict, status_code: int) -> str:
        message = (
            payload.get('errorMessage')
            or payload.get('message')
            or payload.get('detail')
            or payload.get('resultMessage')
        )

        if message:
            return f'Saby отклонил заказ: {message}'

        return f'Saby отклонил заказ (HTTP {status_code}).'
