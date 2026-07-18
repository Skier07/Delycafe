from __future__ import annotations

from django.utils import timezone

from customers.models import Customer
from legal.documents import LEGAL_DOCS_VERSION, REQUIRED_CONSENT_SLUGS


class LegalConsentError(Exception):
    pass


def customer_has_required_consents(customer: Customer | None) -> bool:
    if customer is None:
        return False

    if customer.legal_docs_version != LEGAL_DOCS_VERSION:
        return False

    return all(
        (
            customer.terms_accepted_at,
            customer.privacy_accepted_at,
            customer.pd_consent_accepted_at,
        )
    )


def consent_status_payload(customer: Customer | None) -> dict:
    if customer is None:
        return {
            'legal_docs_version': LEGAL_DOCS_VERSION,
            'can_place_order': False,
            'terms_accepted': False,
            'privacy_accepted': False,
            'pd_consent_accepted': False,
            'marketing_consent_accepted': False,
            'required_slugs': list(REQUIRED_CONSENT_SLUGS),
        }

    version_matches = customer.legal_docs_version == LEGAL_DOCS_VERSION

    return {
        'legal_docs_version': LEGAL_DOCS_VERSION,
        'accepted_version': customer.legal_docs_version or '',
        'can_place_order': customer_has_required_consents(customer),
        'terms_accepted': bool(customer.terms_accepted_at) and version_matches,
        'privacy_accepted': bool(customer.privacy_accepted_at) and version_matches,
        'pd_consent_accepted': bool(customer.pd_consent_accepted_at) and version_matches,
        'marketing_consent_accepted': bool(customer.marketing_consent_at),
        'required_slugs': list(REQUIRED_CONSENT_SLUGS),
    }


def save_customer_consents(
    *,
    customer: Customer,
    terms: bool,
    privacy: bool,
    pd_consent: bool,
    marketing: bool = False,
) -> Customer:
    if not (terms and privacy and pd_consent):
        raise LegalConsentError(
            'Для оформления заказов нужно принять все обязательные документы.'
        )

    now = timezone.now()
    update_fields = ['updated_at', 'legal_docs_version']

    customer.terms_accepted_at = now
    customer.privacy_accepted_at = now
    customer.pd_consent_accepted_at = now
    customer.legal_docs_version = LEGAL_DOCS_VERSION
    update_fields.extend(
        [
            'terms_accepted_at',
            'privacy_accepted_at',
            'pd_consent_accepted_at',
        ]
    )

    if marketing:
        customer.marketing_consent_at = now
        update_fields.append('marketing_consent_at')
    elif customer.marketing_consent_at is None:
        customer.marketing_consent_at = None

    customer.save(update_fields=list(dict.fromkeys(update_fields)))
    return customer


def ensure_customer_can_place_order(customer: Customer | None) -> None:
    if not customer_has_required_consents(customer):
        raise LegalConsentError(
            'Чтобы оформить заказ, примите условия в разделе «Меню → Политика».'
        )
