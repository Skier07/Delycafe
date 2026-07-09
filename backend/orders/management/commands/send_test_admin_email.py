from django.core.management.base import BaseCommand

from orders.order_notification_service import build_admin_order_email
from orders.models import Order


class Command(BaseCommand):
    help = 'Отправляет тестовое письмо администратору по последнему оплаченному заказу'

    def add_arguments(self, parser):
        parser.add_argument(
            '--order-id',
            type=int,
            help='ID заказа для тестового письма',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Показать текст письма без отправки',
        )

    def handle(self, *args, **options):
        from orders.order_notification_service import try_send_admin_order_email

        order_id = options.get('order_id')

        if order_id:
            order = Order.objects.filter(pk=order_id).prefetch_related('items').first()
        else:
            order = (
                Order.objects.filter(payment_status=Order.PaymentStatus.PAID)
                .prefetch_related('items')
                .order_by('-paid_at', '-created_at')
                .first()
            )

        if order is None:
            self.stderr.write('Оплаченный заказ не найден.')
            return

        if options['dry_run']:
            subject, body = build_admin_order_email(order)
            self.stdout.write(f'Subject: {subject}\n\n{body}')
            return

        sent = try_send_admin_order_email(order.id)

        if sent:
            self.stdout.write(
                self.style.SUCCESS(
                    f'Письмо по заказу #{order.id} отправлено.'
                )
            )
        else:
            self.stderr.write(
                f'Письмо по заказу #{order.id} не отправлено. '
                'Проверьте EMAIL_* в .env и что заказ уже есть в Saby.'
            )
