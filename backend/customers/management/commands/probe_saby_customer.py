"""Диагностика: ищет клиента только через Retail API (без CRM)."""

import json

import requests
from django.conf import settings
from django.core.management.base import BaseCommand

from catalog.services.saby_catalog_service import SabyCatalogService
from customers.services.saby_customer_service import SabyCustomerService


class Command(BaseCommand):
    help = (
        'Проверить customer/find в Saby Retail по телефону '
        '(сырой ответ по каждому варианту номера).'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            type=str,
            required=True,
            help='Телефон клиента (любой формат).',
        )

    def handle(self, *args, **options):
        service = SabyCustomerService()
        phone = service.normalize_phone(options['phone'])

        if not phone:
            self.stderr.write(self.style.ERROR('Некорректный телефон.'))
            return

        token_raw = SabyCatalogService().get_token()
        token = (
            token_raw.get('access_token')
            or token_raw.get('token')
            or token_raw
            if isinstance(token_raw, dict)
            else str(token_raw)
        )

        self.stdout.write(
            f'pointId={settings.SABY_POINT_ID} normalized={phone}',
        )

        found_any = False

        for variant in service._phone_variants(phone):
            url = SabyCustomerService.CUSTOMER_FIND_URL
            response = requests.get(
                url,
                headers={
                    'X-SBISAccessToken': token,
                    'Accept': 'application/json',
                },
                params={
                    'phone': variant,
                    'pointId': settings.SABY_POINT_ID,
                },
                timeout=30,
            )

            self.stdout.write('')
            self.stdout.write(
                self.style.NOTICE(
                    f'GET customer/find phone={variant!r} '
                    f'status={response.status_code}',
                ),
            )
            body = response.text[:2000]
            try:
                pretty = json.dumps(
                    response.json(),
                    ensure_ascii=False,
                    indent=2,
                )[:2000]
                self.stdout.write(pretty)
            except Exception:
                self.stdout.write(body)

            if response.status_code == 200:
                parsed = service._parse_customer_payload(response.json())
                if parsed is not None:
                    found_any = True
                    enriched = service._enrich_bonus_balance(parsed)
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'PARSED phone={enriched.phone} '
                            f'externalId={enriched.saby_external_id} '
                            f'customerId={enriched.saby_customer_id} '
                            f'bonus={enriched.bonus_balance} '
                            f'name={enriched.name!r}',
                        ),
                    )

        self.stdout.write('')
        if found_any:
            self.stdout.write(self.style.SUCCESS('Retail: клиент найден.'))
        else:
            self.stdout.write(
                self.style.WARNING(
                    'Retail: клиент НЕ найден ни по одному варианту номера.',
                ),
            )
