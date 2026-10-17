import json
from decimal import Decimal

from django.conf import settings
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
            result = {'order': order_id,
                      'delivery_mode': getattr(settings, 'SABY_DELIVERY_MODE', 'item'),
                      'local': {
                field: getattr(order, field) for field in (
                    'products_total', 'discount_amount', 'delivery_price',
                    'bonus_spent', 'payment_amount', 'payment_status',
                    'saby_bonus_applied', 'saby_payment_registered',
                    'saby_external_id', 'saby_order_number', 'saby_sale_id',
                    'saby_payment_error', 'saby_dispatch_error',
                )
            }}
            if order.saby_sale_id or order.saby_order_number:
                try:
                    sale = service.read_sale(order)
                    result['saby'] = {k: sale.get(k) for k in ('totalPrice', 'totalSum', 'totalDiscount')}
                    result['positions'] = [{k: row.get(k) for k in (
                        'name', 'nomNumber', 'cost', 'count', 'totalPrice', 'totalSum'
                    )} for row in sale.get('nomenclatures', [])]
                    total = service._money(sale.get('totalPrice'), 'totalPrice')
                    expected = Decimal(order.payment_amount or order.total_price)
                    result['saby_minus_payment'] = str(total - expected)
                    # Это разница с суммой строк, а не доказательство конкретного
                    # тарифа: на неё также могут влиять скидки и другие надбавки.
                    positions = sale.get('nomenclatures', [])
                    if positions and all(row.get('totalPrice') is not None for row in positions):
                        position_total = sum(service._money(row['totalPrice'], 'position.totalPrice')
                                             for row in positions)
                        result['saby_minus_positions'] = str(total - position_total)
                except SabyOrderError as exc:
                    result['sale_error'] = str(exc)
                try:
                    state = service._read_sale_resource(order, '/state')
                    result['state'] = {k: state.get(k) for k in ('state', 'payState', 'payments')}
                except SabyOrderError as exc:
                    result['state_error'] = str(exc)
            self.stdout.write(json.dumps(result, ensure_ascii=False, indent=2))
