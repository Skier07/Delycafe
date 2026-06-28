import logging
from urllib.parse import parse_qs

from django.http import HttpRequest

from orders.models import Order
from orders.services import confirm_order_paid

from .services import AlfaPaymentError, get_alfa_payment_status

logger = logging.getLogger(__name__)

SUCCESS_OPERATIONS = frozenset({'deposited', 'approved'})
FAILED_OPERATIONS = frozenset({
    'reversed',
    'refunded',
    'declinedbytimeout',
    'declinedcardpresent',
})


def extract_alfa_callback_data(request: HttpRequest) -> dict[str, str]:
    data: dict[str, str] = {}

    for source in (request.GET, request.POST):
        for key, value in source.items():
            data[str(key)] = str(value)

    if not data and request.body:
        try:
            parsed = parse_qs(
                request.body.decode('utf-8'),
                keep_blank_values=True,
            )
            for key, values in parsed.items():
                if values:
                    data[str(key)] = str(values[0])
        except (UnicodeDecodeError, ValueError):
            logger.exception('Failed to parse Alfa callback body')

    if not data and hasattr(request, 'data') and request.data:
        for key, value in dict(request.data).items():
            data[str(key)] = str(value)

    return data


def find_order_for_alfa_callback(data: dict[str, str]) -> Order | None:
    external_id = (
        data.get('mdOrder')
        or data.get('orderId')
        or data.get('order_id')
    )

    if external_id:
        order = Order.objects.filter(
            payment_external_id=external_id,
        ).first()
        if order is not None:
            return order

    order_number = data.get('orderNumber') or data.get('order_number')
    if not order_number:
        return None

    clean_number = str(order_number).replace('delycafe-', '')
    if not clean_number.isdigit():
        return None

    return Order.objects.filter(id=int(clean_number)).first()


def is_alfa_callback_paid(data: dict[str, str]) -> bool:
    operation = str(data.get('operation') or '').lower()
    status = str(data.get('status') or '')

    return status == '1' and operation in SUCCESS_OPERATIONS


def is_alfa_callback_failed(data: dict[str, str]) -> bool:
    operation = str(data.get('operation') or '').lower()
    status = str(data.get('status') or '')

    if status == '1' and operation in FAILED_OPERATIONS:
        return True

    return operation in FAILED_OPERATIONS and status == '0'


def handle_alfa_callback(data: dict[str, str]) -> dict:
    logger.info('Alfa callback payload: %s', data)

    order = find_order_for_alfa_callback(data)
    if order is None:
        logger.warning('Alfa callback: order not found for payload %s', data)
        return {
            'result': 'not_found',
            'detail': 'Заказ не найден.',
        }

    if is_alfa_callback_paid(data):
        confirm_order_paid(order)
        order.refresh_from_db()
        logger.info(
            'Alfa callback: order #%s marked paid (%s)',
            order.id,
            order.payment_status,
        )
        return {
            'result': 'ok',
            'order_id': order.id,
            'payment_status': order.payment_status,
            'status': order.status,
        }

    if is_alfa_callback_failed(data):
        order.payment_status = Order.PaymentStatus.FAILED
        order.save(update_fields=['payment_status', 'updated_at'])
        logger.info('Alfa callback: order #%s marked failed', order.id)
        return {
            'result': 'failed',
            'order_id': order.id,
            'payment_status': order.payment_status,
        }

    if order.payment_external_id:
        try:
            get_alfa_payment_status(order)
            order.refresh_from_db()
            logger.info(
                'Alfa callback: synced order #%s via getOrderStatusExtended',
                order.id,
            )
            return {
                'result': 'synced',
                'order_id': order.id,
                'payment_status': order.payment_status,
                'status': order.status,
            }
        except AlfaPaymentError as error:
            logger.warning(
                'Alfa callback: status sync failed for order #%s: %s',
                order.id,
                error,
            )

    logger.info(
        'Alfa callback: ignored for order #%s (operation=%s, status=%s)',
        order.id,
        data.get('operation'),
        data.get('status'),
    )
    return {
        'result': 'ignored',
        'order_id': order.id,
        'payment_status': order.payment_status,
    }


def sync_order_from_return_url(request: HttpRequest) -> Order | None:
    data = extract_alfa_callback_data(request)
    order = find_order_for_alfa_callback(data)

    if order is None or not order.payment_external_id:
        return None

    try:
        get_alfa_payment_status(order)
        order.refresh_from_db()
        return order
    except AlfaPaymentError as error:
        logger.warning(
            'Payment return URL: failed to sync order #%s: %s',
            order.id,
            error,
        )
        return order
