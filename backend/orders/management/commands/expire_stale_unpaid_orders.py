from django.core.management.base import BaseCommand

from payments.services import expire_all_stale_unpaid_orders


class Command(BaseCommand):
    help = (
        'Проверяет старые заказы в банке: подтверждает оплату, '
        'а при завершённой неоплаченной сессии закрывает заказ'
    )

    def handle(self, *args, **options):
        expired = expire_all_stale_unpaid_orders()
        self.stdout.write(
            self.style.SUCCESS(
                f'Закрыто просроченных неоплаченных заказов: {expired}',
            )
        )
