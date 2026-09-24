from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from orders.models import Order
from payments.reconciliation import reconcile_order_payment


class Command(BaseCommand):
    help = 'Сверяет оплату с Альфой; --apply запускает обработку подтверждённых оплат.'

    def add_arguments(self, parser):
        parser.add_argument('--order-id', type=int)
        parser.add_argument('--limit', type=int, default=100)
        parser.add_argument('--apply', action='store_true')

    def handle(self, *args, **options):
        if options['limit'] <= 0:
            raise CommandError('--limit должен быть больше нуля.')
        if options['order_id'] is not None:
            orders = Order.objects.filter(pk=options['order_id'])
            if not orders.exists():
                raise CommandError('Заказ не найден.')
        else:
            orders = Order.objects.filter(
                payment_status=Order.PaymentStatus.UNPAID,
                created_at__gte=timezone.now() - timedelta(days=7),
            ).exclude(status=Order.Status.CANCELED).exclude(
                payment_external_id='',
            ).order_by('-created_at')[:options['limit']]

        failures = 0
        for order in orders:
            try:
                result = reconcile_order_payment(order, apply=options['apply'])
                self.stdout.write(
                    f'#{order.pk}: {result}; payment={order.payment_status}; '
                    f'email_sent={bool(order.admin_email_sent_at)}; '
                    f'saby_number={order.saby_order_number or "-"}; '
                    f'saby_payment_registered={order.saby_payment_registered}'
                )
                if order.saby_dispatch_error or order.saby_payment_error:
                    self.stderr.write(order.saby_dispatch_error or order.saby_payment_error)
            except Exception as exc:
                failures += 1
                self.stderr.write(f'#{order.pk}: {exc}')
        if failures:
            raise CommandError(f'Ошибок сверки: {failures}; проверьте журнал backend.')
