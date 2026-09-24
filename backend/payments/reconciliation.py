"""Сверка пропущенных подтверждений без создания новых платежей."""

from decimal import Decimal, InvalidOperation

from orders.models import Order
from orders.services import confirm_order_paid
from payments.services import AlfaPaymentError, _fetch_alfa_status_response


def validate_paid_response(order, response):
    """Не передавать в исполнение чужой, неполный или возвращённый платёж."""
    expected = f'delycafe-{order.pk}'
    if response.get('orderNumber') != expected:
        raise AlfaPaymentError('Номер заказа в ответе банка не совпадает.')
    try:
        amount = Decimal(str(response.get('amount')))
        expected_amount = Decimal(order.payment_amount) * 100
        info = response.get('paymentAmountInfo') or {}
        deposited = Decimal(str(info.get('depositedAmount', amount)))
        refunded = Decimal(str(info.get('refundedAmount', 0)))
        if expected_amount <= 0 or amount != expected_amount or deposited != amount:
            raise AlfaPaymentError('Сумма зачисления банка не совпадает с заказом.')
        if refunded != 0:
            raise AlfaPaymentError('По платежу есть возврат; требуется сверка вручную.')
    except (InvalidOperation, TypeError, ValueError, AttributeError) as exc:
        raise AlfaPaymentError('Некорректные суммы в ответе банка.') from exc
    if str(response.get('currency')) != '810':
        raise AlfaPaymentError('Неожиданная валюта платежа.')


def reconcile_order_payment(order, *, apply=False):
    order.refresh_from_db()
    if order.payment_status != Order.PaymentStatus.UNPAID:
        return 'skipped'
    if order.status == Order.Status.CANCELED:
        return 'skipped'
    response = _fetch_alfa_status_response(order)
    if response is None:
        raise AlfaPaymentError('Не удалось получить статус платежа в банке.')
    if str(response.get('orderStatus')) != '2':
        return 'pending'
    validate_paid_response(order, response)
    if not apply:
        return 'bank_paid'
    confirm_order_paid(order)
    order.refresh_from_db()
    return 'processed'
