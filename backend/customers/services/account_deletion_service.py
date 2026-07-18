from __future__ import annotations

import logging

from django.db import transaction
from django.utils import timezone

from customers.models import Customer, PhoneAuthSession
from orders.models import Order

logger = logging.getLogger(__name__)


def _phone_variants(phone: str) -> set[str]:
    normalized = ''.join(char for char in str(phone or '') if char.isdigit())

    variants = {normalized, str(phone or '').strip()}

    if len(normalized) == 11 and normalized.startswith('7'):
        variants.add(f'+{normalized}')
        variants.add(f'8{normalized[1:]}')

    return {value for value in variants if value}


@transaction.atomic
def delete_customer_account(customer: Customer) -> None:
    """Удаляет профиль клиента и связанные данные, сохраняя заказы для учёта."""
    phone = customer.phone
    phone_variants = _phone_variants(phone)
    customer_id = customer.id

    Order.objects.filter(
        customer_id=customer_id,
        payment_status=Order.PaymentStatus.UNPAID,
        status=Order.Status.NEW,
    ).update(
        status=Order.Status.CANCELED,
        updated_at=timezone.now(),
    )

    Order.objects.filter(customer_id=customer_id).update(customer=None)

    PhoneAuthSession.objects.filter(phone__in=phone_variants).delete()

    customer.delete()

    logger.info('Customer account deleted: id=%s phone=%s', customer_id, phone)
