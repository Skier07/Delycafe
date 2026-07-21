from __future__ import annotations

from datetime import timedelta

import jwt
from django.conf import settings
from django.utils import timezone


class AuthTokenError(Exception):
    pass


def _encode(payload: dict) -> str:
    return jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')


def _decode(token: str, *, expected_type: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=['HS256'],
            options={'require': ['exp', 'typ']},
        )
    except jwt.ExpiredSignatureError as error:
        raise AuthTokenError('Сессия истекла. Войдите снова.') from error
    except jwt.InvalidTokenError as error:
        raise AuthTokenError('Недействительный токен.') from error

    if payload.get('typ') != expected_type:
        raise AuthTokenError('Недействительный токен.')

    return payload


def create_customer_access_token(*, customer_id: int, phone: str) -> str:
    now = timezone.now()
    ttl = timedelta(days=settings.CUSTOMER_ACCESS_TOKEN_DAYS)

    return _encode(
        {
            'typ': 'customer',
            'sub': str(customer_id),
            'phone': phone,
            'iat': int(now.timestamp()),
            'exp': int((now + ttl).timestamp()),
        }
    )


def decode_customer_access_token(token: str) -> dict:
    payload = _decode(token, expected_type='customer')
    customer_id = payload.get('sub')
    phone = payload.get('phone')

    if not customer_id or not phone:
        raise AuthTokenError('Недействительный токен.')

    return {
        'customer_id': int(customer_id),
        'phone': str(phone),
    }


def create_order_access_token(*, order_id: int, phone: str) -> str:
    now = timezone.now()
    ttl = timedelta(hours=settings.ORDER_ACCESS_TOKEN_HOURS)

    return _encode(
        {
            'typ': 'order',
            'order_id': order_id,
            'phone': phone,
            'iat': int(now.timestamp()),
            'exp': int((now + ttl).timestamp()),
        }
    )


def decode_order_access_token(token: str) -> dict:
    payload = _decode(token, expected_type='order')
    order_id = payload.get('order_id')
    phone = payload.get('phone')

    if order_id is None or not phone:
        raise AuthTokenError('Недействительный токен заказа.')

    return {
        'order_id': int(order_id),
        'phone': str(phone),
    }
