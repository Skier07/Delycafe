import csv
from pathlib import Path

from customers.models import Customer
from customers.services.saby_customer_service import (
    SabyCustomerData,
    SabyCustomerService,
    upsert_customer_from_saby,
)
from django.core.management.base import BaseCommand
from django.db.models import Q


class Command(BaseCommand):
    help = (
        'Синхронизация клиентов из Saby Presto '
        '(по телефону, списку или CSV-выгрузке).'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            type=str,
            help='Синхронизировать одного клиента по телефону.',
        )
        parser.add_argument(
            '--file',
            type=str,
            help='Импорт клиентов из CSV (выгрузка из Presto → Клиенты).',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            help='Попробовать загрузить клиентов через API Saby (постранично).',
        )
        parser.add_argument(
            '--refresh-known',
            action='store_true',
            help='Обновить уже известных клиентов из локальной базы.',
        )
        parser.add_argument(
            '--limit',
            type=int,
            default=0,
            help='Ограничить количество обработанных записей.',
        )

    def handle(self, *args, **options):
        service = SabyCustomerService()
        processed = 0
        created_or_updated = 0
        failed = 0

        if options['phone']:
            processed, created_or_updated, failed = self._sync_phone(
                service,
                options['phone'],
            )
        elif options['file']:
            processed, created_or_updated, failed = self._import_file(
                service,
                Path(options['file']),
                options['limit'],
            )
        elif options['all']:
            processed, created_or_updated, failed = self._sync_all(
                service,
                options['limit'],
            )
        elif options['refresh_known']:
            processed, created_or_updated, failed = self._refresh_known(
                service,
                options['limit'],
            )
        else:
            self.stdout.write(
                self.style.WARNING(
                    'Укажите --phone, --file, --all или --refresh-known.',
                ),
            )
            return

        self.stdout.write(
            self.style.SUCCESS(
                'Готово: '
                f'обработано={processed}, '
                f'сохранено={created_or_updated}, '
                f'ошибок={failed}',
            ),
        )

    def _sync_phone(self, service, phone):
        try:
            saby_data = service.find_by_phone(phone)
        except Exception as exc:
            self.stdout.write(self.style.ERROR(f'Ошибка Saby: {exc}'))
            return 1, 0, 1

        if saby_data is None:
            self.stdout.write(
                self.style.WARNING(f'Клиент не найден в Saby: {phone}'),
            )
            return 1, 0, 1

        customer = upsert_customer_from_saby(saby_data)
        self.stdout.write(
            self.style.SUCCESS(
                f'Сохранён: {customer.phone} — {customer.name or "без имени"}',
            ),
        )
        return 1, 1, 0

    def _sync_all(self, service, limit):
        processed = 0
        saved = 0
        failed = 0

        try:
            iterator = service.iter_customers()
        except Exception as exc:
            self.stdout.write(
                self.style.ERROR(
                    f'Не удалось получить список клиентов из Saby: {exc}',
                ),
            )
            return 0, 0, 1

        for saby_data in iterator:
            processed += 1

            try:
                upsert_customer_from_saby(saby_data)
                saved += 1
            except Exception as exc:
                failed += 1
                self.stdout.write(
                    self.style.ERROR(
                        f'Ошибка сохранения {saby_data.phone}: {exc}',
                    ),
                )

            if limit and processed >= limit:
                break

        if processed == 0:
            self.stdout.write(
                self.style.WARNING(
                    'Saby не вернул список клиентов. '
                    'Используйте --file с CSV-выгрузкой из Presto → Клиенты.',
                ),
            )

        return processed, saved, failed

    def _refresh_known(self, service, limit):
        processed = 0
        saved = 0
        failed = 0

        queryset = Customer.objects.filter(
            Q(saby_external_id__isnull=False)
            | Q(saby_synced_at__isnull=False),
        ).order_by('id')

        if limit:
            queryset = queryset[:limit]

        for customer in queryset:
            processed += 1

            try:
                saby_data = service.find_by_phone(customer.phone)

                if saby_data is None:
                    failed += 1
                    continue

                upsert_customer_from_saby(saby_data)
                saved += 1
            except Exception as exc:
                failed += 1
                self.stdout.write(
                    self.style.ERROR(
                        f'Ошибка обновления {customer.phone}: {exc}',
                    ),
                )

        return processed, saved, failed

    def _import_file(self, service, file_path, limit):
        if not file_path.exists():
            self.stdout.write(self.style.ERROR(f'Файл не найден: {file_path}'))
            return 0, 0, 1

        processed = 0
        saved = 0
        failed = 0

        with file_path.open('r', encoding='utf-8-sig', newline='') as file_obj:
            reader = csv.DictReader(file_obj, delimiter=';')

            if not reader.fieldnames:
                file_obj.seek(0)
                reader = csv.DictReader(file_obj, delimiter=',')

            for row in reader:
                phone = self._extract_csv_phone(row)
                name = self._extract_csv_name(row)

                if not phone:
                    continue

                processed += 1

                try:
                    saby_data = service.find_by_phone(phone)

                    if saby_data is None:
                        saby_data = SabyCustomerData(
                            phone=phone,
                            name=name,
                        )

                    if name and not saby_data.name:
                        saby_data.name = name

                    upsert_customer_from_saby(saby_data)
                    saved += 1
                except Exception as exc:
                    failed += 1
                    self.stdout.write(
                        self.style.ERROR(f'Ошибка строки {phone}: {exc}'),
                    )

                if limit and processed >= limit:
                    break

        return processed, saved, failed

    def _extract_csv_phone(self, row: dict) -> str:
        service = SabyCustomerService()

        for key, value in row.items():
            normalized_key = str(key or '').strip().lower()

            if 'тел' in normalized_key or 'phone' in normalized_key:
                phone = service.normalize_phone(str(value or ''))

                if phone:
                    return phone

        for value in row.values():
            phone = service.normalize_phone(str(value or ''))

            if phone:
                return phone

        return ''

    def _extract_csv_name(self, row: dict) -> str:
        for key, value in row.items():
            normalized_key = str(key or '').strip().lower()

            if any(
                token in normalized_key
                for token in ('фио', 'имя', 'name', 'клиент', 'гость')
            ):
                return str(value or '').strip()

        return ''
