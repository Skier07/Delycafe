from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from uuid import UUID

import requests
from catalog.services.saby_catalog_service import SabyCatalogService
from django.conf import settings
from django.db.models import Q
from django.utils import timezone

logger = logging.getLogger(__name__)


@dataclass
class SabyCustomerData:
    phone: str
    name: str
    saby_external_id: str | None = None
    saby_customer_id: int | None = None
    bonus_balance: int | None = None


class SabyCustomerService:
    SERVICE_URL = 'https://online.sbis.ru/service/'
    CUSTOMER_FIND_URL = 'https://api.sbis.ru/retail/customer/find'
    CUSTOMER_LIST_URL = 'https://api.sbis.ru/retail/customer/list'
    BONUS_BALANCE_URL = (
        'https://api.sbis.ru/retail/customer/{external_id}/bonus-balance'
    )

    def __init__(self, catalog_service: SabyCatalogService | None = None):
        self._catalog_service = catalog_service or SabyCatalogService()

    def find_by_phone(self, phone: str) -> SabyCustomerData | None:
        normalized_phone = self.normalize_phone(phone)

        if not normalized_phone:
            return None

        retail_customer = self._find_in_retail_api(normalized_phone)

        if retail_customer is not None:
            return self._enrich_bonus_balance(retail_customer)

        try:
            crm_customer = self._find_in_crm_api(normalized_phone)
        except Exception as exc:
            # CRM часто недоступен (404 на online.sbis.ru/service/) —
            # не маскируем результат retail.
            logger.warning(
                'Saby CRM lookup failed for %s: %s',
                normalized_phone,
                exc,
            )
            crm_customer = None

        if crm_customer is not None:
            return self._enrich_bonus_balance(crm_customer)

        return None

    def fetch_bonus_balance_for_external_id(
        self,
        external_id: str,
    ) -> int | None:
        if not external_id:
            return None

        return self._fetch_bonus_balance(str(external_id).strip())

    def iter_customers(self, page_size: int = 200):
        token = self._get_token()
        page = 0

        while True:
            response = requests.get(
                self.CUSTOMER_LIST_URL,
                headers=self._auth_headers(token),
                params={
                    'pointId': settings.SABY_POINT_ID,
                    'page': page,
                    'pageSize': page_size,
                },
                timeout=60,
            )

            if response.status_code == 404:
                break

            response.raise_for_status()
            payload = response.json()
            items = self._extract_customer_items(payload)

            if not items:
                break

            for raw_item in items:
                parsed = self._parse_customer_payload(raw_item)

                if parsed is not None:
                    yield self._enrich_bonus_balance(parsed)

            if len(items) < page_size:
                break

            page += 1

    def normalize_phone(self, value: str) -> str:
        digits = re.sub(r'\D', '', str(value or ''))

        if len(digits) == 11 and digits.startswith('8'):
            digits = '7' + digits[1:]

        if len(digits) == 10:
            digits = '7' + digits

        if len(digits) == 11 and digits.startswith('7'):
            return digits

        return ''

    def format_phone_for_app(self, digits: str) -> str:
        if len(digits) == 11 and digits.startswith('7'):
            return f'+{digits}'

        return digits

    def phone_lookup_variants(self, phone: str) -> list[str]:
        normalized = self.normalize_phone(phone)

        if not normalized:
            raw = str(phone or '').strip()
            return [raw] if raw else []

        variants = [
            normalized,
            f'+{normalized}',
            f'8{normalized[1:]}',
            normalized[1:],
        ]

        return list(dict.fromkeys(variants))

    def _enrich_bonus_balance(
        self,
        customer: SabyCustomerData,
    ) -> SabyCustomerData:
        if not customer.saby_external_id:
            logger.info(
                'Saby customer %s has no externalId — cannot fetch bonus-balance',
                customer.phone,
            )
            return customer

        fetched = self._fetch_bonus_balance(customer.saby_external_id)

        if fetched is not None:
            customer.bonus_balance = fetched
        else:
            logger.info(
                'Saby bonus-balance empty/null for phone=%s externalId=%s '
                '(pointId=%s)',
                customer.phone,
                customer.saby_external_id,
                settings.SABY_POINT_ID,
            )

        return customer

    def _find_in_retail_api(self, phone: str) -> SabyCustomerData | None:
        token = self._get_token()

        for phone_variant in self._phone_variants(phone):
            response = requests.get(
                self.CUSTOMER_FIND_URL,
                headers=self._auth_headers(token),
                params={
                    'phone': phone_variant,
                    'pointId': settings.SABY_POINT_ID,
                },
                timeout=30,
            )

            logger.info(
                'Saby retail customer/find phone=%s status=%s body=%s',
                phone_variant,
                response.status_code,
                response.text[:800],
            )

            if response.status_code in {400, 404}:
                continue

            response.raise_for_status()
            payload = response.json()
            parsed = self._parse_customer_payload(payload)

            if parsed is not None:
                if not parsed.phone:
                    parsed.phone = phone
                return parsed

        return None

    def _find_in_crm_api(self, phone: str) -> SabyCustomerData | None:
        token = self._get_token()

        for phone_variant in self._phone_variants(phone):
            payload = self._call_service(
                token=token,
                method='CRMClients.GetCustomerByParams',
                params={
                    'Contacts': [
                        {
                            'Type': 'phone',
                            'Value': phone_variant,
                        },
                    ],
                },
            )

            parsed = self._parse_customer_payload(payload)

            if parsed is not None:
                if not parsed.phone:
                    parsed.phone = phone
                return parsed

        return None

    def _fetch_bonus_balance(
        self,
        external_id: str,
        token: str | None = None,
    ) -> int | None:
        token = token or self._get_token()
        external_id = str(external_id or '').strip()

        if not external_id:
            return None

        response = requests.get(
            self.BONUS_BALANCE_URL.format(external_id=external_id),
            headers=self._auth_headers(token),
            params={
                'pointId': settings.SABY_POINT_ID,
            },
            timeout=30,
        )

        if response.status_code in {400, 404}:
            logger.warning(
                'Saby bonus-balance HTTP %s for externalId=%s body=%s',
                response.status_code,
                external_id,
                response.text[:500],
            )
            return None

        response.raise_for_status()
        payload = response.json()

        if not isinstance(payload, dict):
            return self._to_int(payload)

        # null значит «недоступно в точке», не путать с нулём.
        if (
            'bonusBalance' in payload
            and payload.get('bonusBalance') is None
            and payload.get('bonus_balance') is None
        ):
            return None

        return self._to_int(
            self._pick_first(
                payload,
                'bonusBalance',
                'bonus_balance',
                'availableBonusBalance',
                'totalBonusBalance',
                'balance',
                'bonuses',
            ),
        )

    def _call_service(
        self,
        token: str,
        method: str,
        params: dict[str, Any],
    ) -> Any:
        response = requests.post(
            self.SERVICE_URL,
            headers=self._auth_headers(token),
            json={
                'jsonrpc': '2.0',
                'method': method,
                'params': params,
                'protocol': 6,
                'id': 1,
            },
            timeout=30,
        )
        response.raise_for_status()

        payload = response.json()

        if isinstance(payload, dict) and payload.get('error'):
            raise RuntimeError(payload['error'])

        if isinstance(payload, dict) and 'result' in payload:
            return payload['result']

        return payload

    def _get_token(self) -> str:
        token = self._catalog_service.get_token()

        if isinstance(token, dict):
            return (
                token.get('access_token')
                or token.get('token')
                or ''
            )

        return str(token)

    def _auth_headers(self, token: str) -> dict[str, str]:
        return {
            'X-SBISAccessToken': token,
            'Accept': 'application/json',
        }

    def _phone_variants(self, phone: str) -> list[str]:
        variants = [phone]

        if phone.startswith('7') and len(phone) == 11:
            variants.append(phone[1:])
            variants.append(f'8{phone[1:]}')
            variants.append(f'+{phone}')

        return list(dict.fromkeys(variants))

    def _extract_customer_items(self, payload: Any) -> list[dict[str, Any]]:
        if isinstance(payload, list):
            return [item for item in payload if isinstance(item, dict)]

        if not isinstance(payload, dict):
            return []

        for key in (
            'customers',
            'clients',
            'items',
            'data',
            'result',
            'list',
        ):
            value = payload.get(key)

            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]

            if isinstance(value, dict):
                nested = self._extract_customer_items(value)

                if nested:
                    return nested

        return []

    def _parse_customer_payload(self, payload: Any) -> SabyCustomerData | None:
        if payload is None:
            return None

        if isinstance(payload, list):
            for item in payload:
                parsed = self._parse_customer_payload(item)

                if parsed is not None:
                    return parsed

            return None

        if not isinstance(payload, dict):
            return None

        if 'd' in payload and isinstance(payload['d'], (dict, list)):
            return self._parse_customer_payload(payload['d'])

        if 'result' in payload and isinstance(payload['result'], (dict, list)):
            return self._parse_customer_payload(payload['result'])

        nested_items = self._extract_customer_items(payload)
        looks_like_wrapper = nested_items and not any(
            key in payload
            for key in (
                'phone',
                'Phone',
                'externalId',
                'external_id',
                'customerId',
            )
        )

        if looks_like_wrapper:
            return self._parse_customer_payload(nested_items[0])

        phone_raw = self._pick_first(
            payload,
            'phone',
            'Phone',
            'mobile',
            'Mobile',
            'customerPhone',
            'clientPhone',
        )

        if phone_raw is None:
            phone_raw = self._extract_phone_from_contacts(payload)

        normalized_phone = self.normalize_phone(str(phone_raw or ''))
        external_id = self._extract_external_id(payload)
        customer_id = self._extract_customer_id(payload)

        # Без телефона и UUID клиента разобрать нельзя.
        if not normalized_phone and not external_id:
            return None

        name = self._extract_name(payload)
        bonus_balance = self._to_int(
            self._pick_first(
                payload,
                'bonusBalance',
                'bonus_balance',
                'availableBonusBalance',
                'totalBonusBalance',
                'balance',
                'bonuses',
            ),
        )

        return SabyCustomerData(
            phone=normalized_phone,
            name=name,
            saby_external_id=external_id,
            saby_customer_id=customer_id,
            bonus_balance=bonus_balance,
        )

    def _extract_external_id(self, payload: dict[str, Any]) -> str | None:
        candidates = []

        for key in (
            'externalId',
            'external_id',
            'uuid',
            'UUID',
            'clientUUID',
            'customerUUID',
            'saleKey',
            'key',
        ):
            value = payload.get(key)

            if value not in (None, ''):
                candidates.append(str(value).strip())

        # Иногда UUID лежит в id.
        raw_id = payload.get('id')
        if raw_id not in (None, ''):
            candidates.append(str(raw_id).strip())

        for value in candidates:
            if self._looks_like_uuid(value):
                return value

        # Нечисловой externalId без строгого UUID — тоже пробуем.
        for value in candidates:
            if value and not value.isdigit():
                return value

        return None

    def _extract_customer_id(self, payload: dict[str, Any]) -> int | None:
        for key in (
            'customerId',
            'customer_id',
            'CustomerID',
            'clientId',
            'ClientID',
        ):
            value = self._to_int(payload.get(key))

            if value is not None:
                return value

        raw_id = payload.get('id')

        if raw_id is not None and not self._looks_like_uuid(str(raw_id)):
            return self._to_int(raw_id)

        return None

    @staticmethod
    def _looks_like_uuid(value: str) -> bool:
        try:
            UUID(str(value))
            return True
        except (TypeError, ValueError, AttributeError):
            return False

    def _extract_phone_from_contacts(self, payload: dict[str, Any]) -> str | None:
        contacts = self._pick_first(
            payload,
            'Contacts',
            'contacts',
            'ContactData',
            'contactData',
        )

        if not isinstance(contacts, list):
            return None

        for contact in contacts:
            if not isinstance(contact, dict):
                continue

            contact_type = str(
                contact.get('Type')
                or contact.get('type')
                or '',
            ).lower()

            if 'phone' in contact_type or 'тел' in contact_type:
                value = contact.get('Value') or contact.get('value')

                if value:
                    return str(value)

        return None

    def _extract_name(self, payload: dict[str, Any]) -> str:
        direct_name = self._pick_first(
            payload,
            'name',
            'Name',
            'fullName',
            'FullName',
            'customerName',
            'clientName',
        )

        if direct_name:
            return str(direct_name).strip()

        parts = [
            self._pick_first(payload, 'lastName', 'LastName', 'Surname'),
            self._pick_first(payload, 'firstName', 'FirstName', 'Name'),
            self._pick_first(payload, 'secondName', 'SecondName', 'Patronymic'),
        ]

        return ' '.join(
            str(part).strip()
            for part in parts
            if part
        ).strip()

    def _pick_first(self, payload: dict[str, Any], *keys: str) -> Any:
        for key in keys:
            if key in payload and payload[key] not in (None, ''):
                return payload[key]

        return None

    def _to_int(self, value: Any) -> int | None:
        if value is None:
            return None

        if isinstance(value, bool):
            return None

        if isinstance(value, int):
            return value

        if isinstance(value, float):
            return int(value)

        if isinstance(value, str):
            cleaned = value.replace(',', '.').replace(' ', '').strip()

            if not cleaned:
                return None

            try:
                return int(float(cleaned))
            except ValueError:
                return None

        return None


def find_local_customer_for_saby(
    *,
    phone: str = '',
    saby_external_id: str | None = None,
    existing_customer=None,
):
    from customers.models import Customer

    if existing_customer is not None:
        return existing_customer

    if saby_external_id:
        customer = Customer.objects.filter(
            saby_external_id=str(saby_external_id).strip(),
        ).first()

        if customer is not None:
            return customer

    service = SabyCustomerService()
    variants = service.phone_lookup_variants(phone)

    if not variants:
        return None

    query = Q()
    for variant in variants:
        query |= Q(phone=variant)

    return Customer.objects.filter(query).order_by('id').first()


def upsert_customer_from_saby(
    saby_data: SabyCustomerData,
    *,
    synced_at: datetime | None = None,
    existing_customer=None,
    update_bonus_balance: bool = False,
):
    from customers.models import Customer

    synced_at = synced_at or timezone.now()
    service = SabyCustomerService()
    phone = service.normalize_phone(saby_data.phone) or str(saby_data.phone or '').strip()

    customer = find_local_customer_for_saby(
        phone=phone or saby_data.phone,
        saby_external_id=saby_data.saby_external_id,
        existing_customer=existing_customer,
    )
    update_fields: list[str] = []

    if customer is None:
        customer = Customer(phone=phone or saby_data.phone)
        update_fields.append('phone')
    elif phone and service.normalize_phone(customer.phone) != phone:
        # Единый формат телефона в БД: 7900…
        customer.phone = phone
        update_fields.append('phone')

    if saby_data.name and customer.name != saby_data.name:
        customer.name = saby_data.name
        update_fields.append('name')

    if (
        saby_data.saby_external_id
        and customer.saby_external_id != saby_data.saby_external_id
    ):
        customer.saby_external_id = saby_data.saby_external_id
        update_fields.append('saby_external_id')

    if (
        saby_data.saby_customer_id
        and customer.saby_customer_id != saby_data.saby_customer_id
    ):
        customer.saby_customer_id = saby_data.saby_customer_id
        update_fields.append('saby_customer_id')

    # По умолчанию локальный ledger не трогаем: find по телефону у Saby
    # не отдаёт баланс, а 0/null затирал бы начисления приложения.
    if update_bonus_balance:
        if saby_data.bonus_balance is not None:
            new_balance = max(int(saby_data.bonus_balance), 0)

            if customer.bonus_balance != new_balance:
                customer.bonus_balance = new_balance
                update_fields.append('bonus_balance')
        elif customer.saby_external_id:
            fetched = service.fetch_bonus_balance_for_external_id(
                customer.saby_external_id,
            )

            if fetched is not None and customer.bonus_balance != fetched:
                customer.bonus_balance = max(fetched, 0)
                update_fields.append('bonus_balance')

    customer.saby_synced_at = synced_at
    update_fields.append('saby_synced_at')

    if not customer.is_active:
        customer.is_active = True
        update_fields.append('is_active')

    if update_fields:
        if customer.pk is None:
            customer.save()
        else:
            customer.save(update_fields=list(set(update_fields)))

    logger.info(
        'Saby upsert customer id=%s phone=%s balance=%s externalId=%s '
        'update_balance=%s',
        customer.pk,
        customer.phone,
        customer.bonus_balance,
        customer.saby_external_id,
        update_bonus_balance,
    )

    return customer


def sync_customer_from_saby(
    phone: str,
    *,
    existing_customer=None,
    update_bonus_balance: bool = False,
):
    """
    Подтянуть клиента из Saby (имя / UUID).

    Баланс бонусов по умолчанию не меняется — источник правды приложение.
    update_bonus_balance=True только для явной сверки (админка), если
    известен externalId и endpoint bonus-balance отвечает.
    """
    service = SabyCustomerService()
    lookup_phone = phone

    if existing_customer is not None and not lookup_phone:
        lookup_phone = existing_customer.phone

    saby_data = service.find_by_phone(lookup_phone)

    if saby_data is None:
        if (
            update_bonus_balance
            and existing_customer is not None
            and existing_customer.saby_external_id
        ):
            balance = service.fetch_bonus_balance_for_external_id(
                existing_customer.saby_external_id,
            )

            if balance is None:
                return None

            saby_data = SabyCustomerData(
                phone=service.normalize_phone(existing_customer.phone)
                or existing_customer.phone,
                name=existing_customer.name or '',
                saby_external_id=existing_customer.saby_external_id,
                saby_customer_id=existing_customer.saby_customer_id,
                bonus_balance=balance,
            )
        elif existing_customer is not None:
            # Клиент в Presto не найден по телефону — локальный аккаунт
            # оставляем без изменений баланса.
            return None
        else:
            return None

    return upsert_customer_from_saby(
        saby_data,
        existing_customer=existing_customer,
        update_bonus_balance=update_bonus_balance,
    )
