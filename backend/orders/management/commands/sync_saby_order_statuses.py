from django.core.management.base import BaseCommand

from orders.saby_order_status_service import SabyOrderStatusService


class Command(BaseCommand):
    help = 'Синхронизирует статусы активных заказов из Saby Presto'

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit',
            type=int,
            default=100,
            help='Максимум заказов за один запуск',
        )

    def handle(self, *args, **options):
        limit = options['limit']
        updated = SabyOrderStatusService().sync_active_orders(limit=limit)

        self.stdout.write(
            self.style.SUCCESS(
                f'Обработано заказов: {updated} (лимит {limit})',
            )
        )
