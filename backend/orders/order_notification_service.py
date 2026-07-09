import logging

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone

from orders.models import Order

logger = logging.getLogger(__name__)


def _email_configured() -> bool:
    if not getattr(settings, 'ORDER_ADMIN_EMAIL_ENABLED', True):
        return False

    if not (getattr(settings, 'ORDER_ADMIN_EMAIL', '') or '').strip():
        return False

    if not (getattr(settings, 'EMAIL_HOST_USER', '') or '').strip():
        return False

    if not (getattr(settings, 'EMAIL_HOST_PASSWORD', '') or '').strip():
        return False

    return True


def _should_send_admin_email(order: Order) -> bool:
    if order.admin_email_sent_at:
        return False

    if order.payment_status != Order.PaymentStatus.PAID:
        return False

    if order.status == Order.Status.CANCELED:
        return False

    if not (order.saby_sale_id or order.saby_order_number):
        return False

    return True


def _format_delivery_line(order: Order) -> str:
    delivery = order.get_delivery_type_display()

    if order.delivery_type == Order.DeliveryType.PICKUP:
        return f'{delivery}'

    address_parts = [
        part.strip()
        for part in (
            order.address_locality,
            order.address,
            (
                f'подъезд {order.address_entrance}'
                if order.address_entrance
                else ''
            ),
            f'этаж {order.address_floor}' if order.address_floor else '',
            (
                f'кв. {order.address_apartment}'
                if order.address_apartment
                else ''
            ),
        )
        if part
    ]

    if address_parts:
        return f'{delivery}: {", ".join(address_parts)}'

    return delivery


def _format_time_line(order: Order) -> str:
    if (
        order.delivery_time_type == Order.DeliveryTimeType.BY_TIME
        and order.delivery_time
    ):
        return f'Ко времени {order.delivery_time.strip()}'

    return 'Как можно скорее'


def _format_payment_line(order: Order) -> str:
    payment = order.get_payment_type_display()

    if order.payment_type == Order.PaymentType.SBP:
        return f'{payment} (СБП)'

    return payment


def build_admin_order_email(order: Order) -> tuple[str, str]:
    items = list(order.items.all())
    items_lines = []

    for item in items:
        title = item.product_title
        if item.variant_title:
            title = f'{title} ({item.variant_title})'

        items_lines.append(
            f'- {title} × {item.quantity} — {item.total_price} ₽'
        )

    if not items_lines:
        items_lines.append('- (позиции не найдены)')

    amount = order.payment_amount or order.total_price
    paid_at = timezone.localtime(order.paid_at) if order.paid_at else None
    paid_at_text = (
        paid_at.strftime('%d.%m.%Y %H:%M')
        if paid_at is not None
        else 'не указано'
    )

    saby_number = (order.saby_order_number or '').strip() or '—'
    customer_name = (order.customer_name or '').strip() or 'Не указано'
    phone = (order.phone or '').strip() or 'Не указан'
    comment = (order.comment or '').strip()

    subject = (
        f'Заказ №{order.id} — {amount} ₽, '
        f'{order.get_delivery_type_display()}'
    )

    body_lines = [
        f'Оплачен новый заказ из приложения DelyCafe.',
        '',
        f'Заказ: №{order.id}',
        f'Saby: №{saby_number}',
        f'Сумма: {amount} ₽',
        f'Оплата: {_format_payment_line(order)}',
        f'Оплачен: {paid_at_text}',
        '',
        f'Клиент: {customer_name}',
        f'Телефон: {phone}',
        f'Доставка: {_format_delivery_line(order)}',
        f'Время: {_format_time_line(order)}',
        '',
        'Состав заказа:',
        *items_lines,
    ]

    if comment:
        body_lines.extend(['', f'Комментарий: {comment}'])

    body_lines.extend(['', 'Источник: приложение DelyCafe'])

    return subject, '\n'.join(body_lines)


def try_send_admin_order_email(order_id: int) -> bool:
    """Отправляет администратору письмо об оплаченном заказе (один раз)."""
    if not _email_configured():
        logger.info(
            'Admin order email skipped for order #%s: email is not configured',
            order_id,
        )
        return False

    try:
        with transaction.atomic():
            order = (
                Order.objects.select_for_update()
                .prefetch_related('items')
                .get(pk=order_id)
            )

            if not _should_send_admin_email(order):
                return False

            subject, body = build_admin_order_email(order)
            recipient = settings.ORDER_ADMIN_EMAIL.strip()

            send_mail(
                subject=subject,
                message=body,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[recipient],
                fail_silently=False,
            )

            order.admin_email_sent_at = timezone.now()
            order.save(
                update_fields=['admin_email_sent_at', 'updated_at'],
            )

        logger.info(
            'Admin order email sent for order #%s to %s',
            order_id,
            settings.ORDER_ADMIN_EMAIL,
        )
        return True
    except Order.DoesNotExist:
        logger.warning(
            'Admin order email skipped: order #%s not found',
            order_id,
        )
        return False
    except Exception:
        logger.exception(
            'Failed to send admin order email for order #%s',
            order_id,
        )
        return False
