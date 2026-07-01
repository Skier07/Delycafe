import logging
from datetime import datetime, timedelta

import requests
from django.conf import settings
from django.db.models import Q
from django.utils import timezone

from catalog.services.saby_catalog_service import SabyCatalogService
from customers.models import BonusTransaction
from orders.delivery_schedule import min_delivery_datetime
from orders.models import Order

logger = logging.getLogger(__name__)


class SabyOrderError(Exception):
    """Ошибка создания заказа в Saby Presto."""


def rollback_order(order: Order):
    """
    Возвращает бонусы и при необходимости
    восстанавливает скидку первого заказа.
    """

    if order.bonus_compensated:
        return

    customer = order.customer
    if customer is None:
        return

    if order.bonus_earned > 0:
        customer.bonus_balance -= order.bonus_earned

        BonusTransaction.objects.create(
            customer=customer,
            transaction_type=BonusTransaction.TransactionType.REFUND,
            amount=-order.bonus_earned,
            order_id=order.id,
            comment=(
                f'Отмена заказа №{order.id}. '
                f'Отмена начисления бонусов.'
            ),
        )

    if order.bonus_spent > 0:
        customer.bonus_balance += order.bonus_spent

        BonusTransaction.objects.create(
            customer=customer,
            transaction_type=BonusTransaction.TransactionType.REFUND,
            amount=order.bonus_spent,
            order_id=order.id,
            comment=(
                f'Отмена заказа №{order.id}. '
                f'Возврат списанных бонусов.'
            ),
        )

    if order.first_order_discount_applied:
        completed_discount_orders = (
            Order.objects.filter(
                customer=customer,
                first_order_discount_applied=True,
                status=Order.Status.DONE,
            )
            .exclude(id=order.id)
            .exists()
        )

        if not completed_discount_orders:
            customer.first_order_discount_available = True
            customer.first_order_discount_used = False

    customer.save()

    order.bonus_compensated = True
    order.save(update_fields=['bonus_compensated'])


def format_phone_for_saby(phone: str) -> str:
    digits = ''.join(char for char in str(phone or '') if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return f'+{digits}'

    return str(phone or '').strip()


LOCALITY_BY_DELIVERY_TYPE = {
    Order.DeliveryType.OZERSK: 'Озерск',
    Order.DeliveryType.PROMPLOSHADKA: 'Промплощадка',
    Order.DeliveryType.TATYSH: 'Татыш',
}


def build_saby_comment(order: Order) -> str:
    """Комментарий для операторов Saby Presto (время, тип доставки, клиент)."""
    lines = [
        f'Доставка: {order.get_delivery_type_display()}',
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
    external_id = (
        saby_response.get('externalId')
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
    if order.saby_payment_registered:
        logger.info(
            'Order #%s Saby payment already registered, skipping',
            order.id,
        )
        return None

    if order.payment_status != Order.PaymentStatus.PAID:
        logger.warning(
            'Order #%s is not paid, skipping Saby payment registration',
            order.id,
        )
        return None

    if not order_already_in_saby(order):
        raise SabyOrderError(
            'Нельзя зарегистрировать оплату в Saby: заказ ещё не создан.'
        )

    try:
        response = SabyOrderService().register_payment(order)
    except SabyOrderError as exc:
        order.saby_payment_error = str(exc)
        order.save(update_fields=['saby_payment_error', 'updated_at'])
        raise

    order.saby_payment_registered = True
    order.saby_payment_error = ''
    order.save(
        update_fields=[
            'saby_payment_registered',
            'saby_payment_error',
            'updated_at',
        ]
    )
    return response


def _try_register_saby_payment(order: Order) -> None:
    try:
        register_saby_payment(order)
    except SabyOrderError:
        logger.exception(
            'Failed to register Saby payment for order #%s',
            order.id,
        )


def dispatch_order_to_saby(order: Order) -> dict | None:
    """Отправляет оплаченный заказ в Saby. Повторный вызов безопасен."""
    if order_already_in_saby(order):
        logger.info('Order #%s already exists in Saby, skipping dispatch', order.id)
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


def confirm_order_paid(order: Order) -> Order:
    """Фиксирует оплату и отправляет заказ в Saby."""
    was_paid = order.payment_status == Order.PaymentStatus.PAID
    update_fields = []

    if not was_paid:
        order.payment_status = Order.PaymentStatus.PAID
        update_fields.append('payment_status')

        if order.status == Order.Status.NEW:
            order.status = Order.Status.ACCEPTED
            update_fields.append('status')

        if not order.paid_at:
            order.paid_at = timezone.now()
            update_fields.append('paid_at')

    if update_fields:
        update_fields.append('updated_at')
        order.save(update_fields=update_fields)

    order.refresh_from_db()

    if not order_already_in_saby(order):
        try:
            dispatch_order_to_saby(order)
        except SabyOrderError:
            pass
    elif not order.saby_payment_registered:
        _try_register_saby_payment(order)

    order.refresh_from_db()

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
        nomenclatures = []

        for item in order.items.all():
            if not item.saby_id:
                continue

            entry = {
                'id': item.saby_id,
                'priceListId': settings.SABY_PRICE_LIST_ID,
                'count': item.quantity,
                'name': item.product_title,
                'cost': item.price,
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
            or LOCALITY_BY_DELIVERY_TYPE.get(order.delivery_type, '')
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
