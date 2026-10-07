import json

from django.core.management.base import BaseCommand, CommandError
from orders.models import Order
from orders.services import SabyOrderService, SabyOrderError


class Command(BaseCommand):
    help = 'Read-only comparison of order totals and receipt tasks.'

    def add_arguments(self, parser):
        parser.add_argument('order_ids', nargs='+', type=int)

    def handle(self, *args, **options):
        service = SabyOrderService()
        for order_id in options['order_ids']:
            try:
                order = Order.objects.get(pk=order_id)
            except Order.DoesNotExist as exc:
                raise CommandError(f'Order #{order_id} not found') from exc
            result = {'order': order_id, 'local': {
                field: getattr(order, field) for field in (
                    'products_total', 'discount_amount', 'delivery_price',
                    'bonus_spent', 'payment_amount', 'payment_status',
                    'saby_bonus_applied', 'saby_payment_registered',
                    'saby_external_id', 'saby_payment_error',
                )
            }}
            if order.saby_sale_id or order.saby_order_number:
                try:
                    sale = service.read_sale(order)
                    result['saby'] = {k: sale.get(k) for k in ('totalPrice', 'totalSum', 'totalDiscount')}
                    result['positions'] = [{k: row.get(k) for k in (
                        'name', 'nomNumber', 'cost', 'count', 'totalPrice', 'totalSum'
                    )} for row in sale.get('nomenclatures', [])]
                except SabyOrderError as exc:
                    result['sale_error'] = str(exc)
                try:
                    state = service._read_sale_resource(order, '/state')
                    result['state'] = {k: state.get(k) for k in ('state', 'payState', 'payments')}
                except SabyOrderError as exc:
                    result['state_error'] = str(exc)
            self.stdout.write(json.dumps(result, ensure_ascii=False, indent=2))
