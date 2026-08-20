from __future__ import annotations

from datetime import timedelta
import hashlib
import secrets
import uuid

import jwt
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from customers.models import CustomerRefreshToken


class AuthTokenError(Exception):
    pass


class RefreshTokenError(Exception):
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
    ttl = timedelta(minutes=settings.CUSTOMER_ACCESS_TOKEN_MINUTES)

    return _encode(
        {
            'typ': 'customer',
            'sub': str(customer_id),
            'phone': phone,
            'jti': uuid.uuid4().hex,
            'iat': int(now.timestamp()),
            'exp': int((now + ttl).timestamp()),
        }
    )


def create_legacy_customer_access_token(*, customer_id: int, phone: str) -> str:
    now = timezone.now()
    ttl = timedelta(days=settings.CUSTOMER_LEGACY_ACCESS_TOKEN_DAYS)

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
        'jti': payload.get('jti'),
    }


def _hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def create_customer_refresh_token(*, customer, family_id=None) -> str:
    raw_token = secrets.token_urlsafe(48)
    CustomerRefreshToken.objects.create(
        customer=customer,
        family_id=family_id or uuid.uuid4(),
        token_hash=_hash_refresh_token(raw_token),
        expires_at=timezone.now()
        + timedelta(days=settings.CUSTOMER_REFRESH_TOKEN_DAYS),
    )
    return raw_token


def rotate_customer_refresh_token(raw_token: str) -> tuple[str, str]:
    now = timezone.now()
    token_hash = _hash_refresh_token(str(raw_token or '').strip())
    error_message = None
    result = None

    with transaction.atomic():
        stored = (
            CustomerRefreshToken.objects.select_for_update()
            .select_related('customer')
            .filter(token_hash=token_hash)
            .first()
        )

        if stored is None:
            error_message = 'Недействительная refresh-сессия.'
        elif stored.revoked_at is not None:
            CustomerRefreshToken.objects.filter(
                family_id=stored.family_id,
                revoked_at__isnull=True,
            ).update(revoked_at=now)
            error_message = (
                'Refresh-сессия уже использована. Выполните вход повторно.'
            )
        elif now >= stored.expires_at:
            stored.revoked_at = now
            stored.save(update_fields=['revoked_at'])
            error_message = (
                'Refresh-сессия истекла. Выполните вход повторно.'
            )
        elif not stored.customer.is_active:
            stored.revoked_at = now
            stored.save(update_fields=['revoked_at'])
            error_message = 'Аккаунт отключён.'
        else:
            stored.last_used_at = now
            stored.revoked_at = now
            stored.save(update_fields=['last_used_at', 'revoked_at'])

            new_raw_token = secrets.token_urlsafe(48)
            CustomerRefreshToken.objects.create(
                customer=stored.customer,
                family_id=stored.family_id,
                token_hash=_hash_refresh_token(new_raw_token),
                expires_at=stored.expires_at,
            )
            access_token = create_customer_access_token(
                customer_id=stored.customer_id,
                phone=stored.customer.phone,
            )
            result = (access_token, new_raw_token)

    if error_message is not None:
        raise RefreshTokenError(error_message)

    if result is None:
        raise RefreshTokenError('Не удалось обновить refresh-сессию.')

    return result


def revoke_customer_refresh_token(raw_token: str) -> None:
    token_hash = _hash_refresh_token(str(raw_token or '').strip())
    CustomerRefreshToken.objects.filter(
        token_hash=token_hash,
        revoked_at__isnull=True,
    ).update(revoked_at=timezone.now())


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
