from django.core.management.base import BaseCommand

from orders.services import retry_pending_saby_dispatches


class Command(BaseCommand):
    help = (
        'Повторно отправляет в Saby оплаченные заказы, '
        'которые ещё не получили sale_id'
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
        result = retry_pending_saby_dispatches(limit=limit)

        self.stdout.write(
            self.style.SUCCESS(
                'Saby retry: '
                f'проверено {result["checked"]}, '
                f'успешно {result["success"]}, '
                f'ошибок {result["failed"]}',
            )
        )
