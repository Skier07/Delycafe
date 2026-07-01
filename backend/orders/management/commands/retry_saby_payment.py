from django.core.management.base import BaseCommand

from orders.services import retry_pending_saby_payments


class Command(BaseCommand):
    help = (
        'Повторно регистрирует оплату в Saby (чек ATOL) '
        'для оплаченных заказов без saby_payment_registered'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit',
            type=int,
            default=50,
            help='Максимум заказов за один запуск',
        )

    def handle(self, *args, **options):
        limit = options['limit']
        result = retry_pending_saby_payments(limit=limit)

        self.stdout.write(
            self.style.SUCCESS(
                'Saby payment retry: '
                f'проверено {result["checked"]}, '
                f'успешно {result["success"]}, '
                f'ошибок {result["failed"]}',
            )
        )
