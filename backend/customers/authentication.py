from __future__ import annotations

from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from customers.models import Customer
from customers.services.auth_token_service import (
    AuthTokenError,
    decode_customer_access_token,
    decode_order_access_token,
)


class CustomerPrincipal:
    is_authenticated = True
    is_anonymous = False

    def __init__(self, customer: Customer):
        self.customer = customer


class OrderAccessPrincipal:
    is_authenticated = True
    is_anonymous = False

    def __init__(self, *, order_id: int, phone: str):
        self.order_id = order_id
        self.phone = phone


class CustomerTokenAuthentication(BaseAuthentication):
    keyword = 'Bearer'

    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')

        if not auth_header.startswith(f'{self.keyword} '):
            return None

        token = auth_header[len(self.keyword) + 1 :].strip()

        if not token:
            return None

        try:
            payload = decode_customer_access_token(token)
        except AuthTokenError as error:
            raise AuthenticationFailed(str(error)) from error

        customer = Customer.objects.filter(
            id=payload['customer_id'],
            phone=payload['phone'],
        ).first()

        if customer is None:
            raise AuthenticationFailed('Пользователь не найден.')

        return (CustomerPrincipal(customer), payload)


class OrderAccessTokenAuthentication(BaseAuthentication):
    header_name = 'HTTP_X_ORDER_ACCESS'

    def authenticate(self, request):
        token = request.META.get(self.header_name, '').strip()

        if not token:
            return None

        try:
            payload = decode_order_access_token(token)
        except AuthTokenError as error:
            raise AuthenticationFailed(str(error)) from error

        return (
            OrderAccessPrincipal(
                order_id=payload['order_id'],
                phone=payload['phone'],
            ),
            payload,
        )


def get_request_customer(request) -> Customer | None:
    user = getattr(request, 'user', None)

    if isinstance(user, CustomerPrincipal):
        return user.customer

    return None


def get_request_order_access(request) -> OrderAccessPrincipal | None:
    user = getattr(request, 'user', None)

    if isinstance(user, OrderAccessPrincipal):
        return user

    return None
