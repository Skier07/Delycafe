from __future__ import annotations

from rest_framework.exceptions import PermissionDenied

from customers.authentication import (
    get_request_customer,
    get_request_order_access,
)
from orders.models import Order


def _normalize_phone(value):
    raw_phone = str(value or '').strip()
    digits = ''.join(char for char in raw_phone if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return digits

    return digits or raw_phone


def authorize_order_access(request, order: Order) -> None:
    customer = get_request_customer(request)

    if customer is not None:
        order_phone = _normalize_phone(order.phone)
        customer_phone = _normalize_phone(customer.phone)

        if order.customer_id == customer.id or order_phone == customer_phone:
            return

        raise PermissionDenied('Нет доступа к этому заказу.')

    order_access = get_request_order_access(request)

    if order_access is None:
        raise PermissionDenied('Требуется авторизация.')

    if order_access.order_id != order.id:
        raise PermissionDenied('Нет доступа к этому заказу.')

    if _normalize_phone(order.phone) != _normalize_phone(order_access.phone):
        raise PermissionDenied('Нет доступа к этому заказу.')
