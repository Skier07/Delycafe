from django.core.management.base import BaseCommand

from orders.models import Order
from payments.services import (
    _fetch_alfa_status_response,
    _persist_alfa_payment_session,
    _resolve_alfa_payment_url,
    _usable_stored_alfa_payment_url,
)


class Command(BaseCommand):
    help = (
        'Обновляет payment_url неоплаченных заказов: берёт formUrl из Альфы, '
        'если шлюз его отдаёт, иначе оставляет текущую ссылку.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--order-id',
            type=int,
            help='Обновить только указанный заказ',
        )

    def handle(self, *args, **options):
        queryset = Order.objects.filter(
            payment_status=Order.PaymentStatus.UNPAID,
            payment_provider='alfa',
        ).exclude(
            payment_external_id='',
        )

        order_id = options.get('order_id')
        if order_id:
            queryset = queryset.filter(id=order_id)

        updated = 0

        for order in queryset.iterator():
            external_id = (order.payment_external_id or '').strip()
            if not external_id:
                continue

            form_url = ''
            response = _fetch_alfa_status_response(order)
            if response:
                form_url = response.get('formUrl') or response.get('form_url') or ''
                external_id = str(
                    response.get('orderId') or response.get('order_id') or external_id,
                ).strip()

            payment_url = _resolve_alfa_payment_url(
                external_id,
                order,
                form_url or _usable_stored_alfa_payment_url(order),
            )

            if not payment_url:
                self.stdout.write(
                    self.style.WARNING(
                        f'Заказ #{order.id}: не удалось собрать payment_url',
                    ),
                )
                continue

            if payment_url == (order.payment_url or '').strip():
                self.stdout.write(
                    f'Заказ #{order.id}: без изменений ({payment_url[:80]}...)',
                )
                continue

            _persist_alfa_payment_session(
                order,
                external_id,
                form_url or payment_url,
            )
            updated += 1
            self.stdout.write(
                self.style.SUCCESS(
                    f'Заказ #{order.id}: payment_url обновлён',
                ),
            )

        self.stdout.write(f'Готово. Обновлено заказов: {updated}')
