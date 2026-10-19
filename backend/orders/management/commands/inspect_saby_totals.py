import json
from decimal import Decimal

import requests

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from orders.models import Order
from orders.services import SabyOrderService, SabyOrderError
from catalog.services.saby_catalog_service import SabyCatalogService


class Command(BaseCommand):
    help = 'Read-only comparison of order totals and receipt tasks.'

    def add_arguments(self, parser):
        parser.add_argument('order_ids', nargs='+', type=int)
        parser.add_argument(
            '--delivery-cost', action='store_true',
            help='Also GET the delivery quote; does not update orders or local tariffs.',
        )
        parser.add_argument(
            '--normalized-address', action='store_true',
            help='GET suggested addresses and quote up to three candidates; never selects or saves an address.',
        )

    def normalized_address_probe(self, order, service):
        if order.delivery_type == Order.DeliveryType.PICKUP:
            return {'skipped': 'pickup'}
        address = service._build_delivery_address_json(order, False)
        params = {'address': ', '.join(filter(None, (
            address.get('Locality'), address.get('Address'),
        )))}
        for source, target in (('AptNum', 'aptNum'), ('Entrance', 'entrance'), ('Floor', 'floor')):
            if address.get(source):
                params[target] = str(address[source])
        goods = max(order.products_total - order.discount_amount - order.bonus_spent, 0)
        result = {'price_basis': goods, 'candidates': []}
        try:
            headers = {'X-SBISAccessToken': SabyCatalogService().get_token()}
            response = requests.get(
                'https://api.sbis.ru/retail/delivery/suggested-address',
                headers=headers, params=params, timeout=30,
            )
            result['http_status'] = response.status_code
            response.raise_for_status()
            data = response.json()
            candidates = data.get('addresses') if isinstance(data, dict) else None
            if not isinstance(candidates, list):
                result['error'] = 'Unexpected suggested addresses format'
                return result
            result['candidate_count'] = len(candidates)
            result['truncated'] = len(candidates) > 3
            for index, candidate in enumerate(candidates[:3]):
                row = {'index': index}
                result['candidates'].append(row)
                normalized = candidate.get('addressJSON') if isinstance(candidate, dict) else None
                if not isinstance(normalized, str):
                    row['error'] = 'Missing JSON string in suggested address'
                    continue
                try:
                    fields = json.loads(normalized)
                    if not isinstance(fields, dict):
                        raise ValueError('Invalid address object')
                    # Do not print customer addresses, coordinates or apartment numbers.
                    row['address_json_fields'] = sorted(fields)
                    row['has_house'] = bool(fields.get('HouseNum'))
                    quote = requests.get(
                        'https://api.sbis.ru/retail/delivery/cost',
                        headers=headers, params={
                            'pointId': settings.SABY_POINT_ID,
                            'address': normalized, 'price': goods,
                        }, timeout=30,
                    )
                    row['http_status'] = quote.status_code
                    quote.raise_for_status()
                    costs = quote.json()
                    if not isinstance(costs, dict):
                        raise ValueError('Invalid quote object')
                    row['quote'] = {key: costs.get(key) for key in (
                        'district', 'cost', 'costForFreeDelivery', 'sumThresholds',
                    )}
                    district = getattr(settings, 'SABY_DELIVERY_DISTRICT_IDS', {}).get(order.delivery_type)
                    row['configured_district_matches'] = district is not None and costs.get('district') == district
                    row['local_delivery_matches'] = costs.get('cost') is not None and Decimal(str(costs['cost'])) == Decimal(order.delivery_price)
                except (requests.RequestException, ValueError, ArithmeticError):
                    row['error'] = 'Normalized address quote failed'
        except (requests.RequestException, ValueError):
            result['error'] = 'Address normalization request failed'
        return result

    def delivery_cost_probe(self, order, service):
        if order.delivery_type == Order.DeliveryType.PICKUP:
            return {'skipped': 'pickup'}
        goods_total = max(order.products_total - order.discount_amount - order.bonus_spent, 0)
        address = service._build_delivery_address_json(order, False)
        result = {'price_basis': goods_total}
        try:
            response = requests.get(
                'https://api.sbis.ru/retail/delivery/cost',
                headers={'X-SBISAccessToken': SabyCatalogService().get_token()},
                params={
                    'pointId': settings.SABY_POINT_ID,
                    'address': json.dumps(address, ensure_ascii=False),
                    'price': goods_total,
                },
                timeout=30,
            )
            result['http_status'] = response.status_code
            data = response.json()
            if isinstance(data, dict):
                result['response'] = {key: data[key] for key in (
                    'district', 'cost', 'costForFreeDelivery', 'minDeliverySum',
                    'nextThreshold', 'nextCost', 'sumThresholds',
                    'error', 'errorMessage', 'message', 'resultCode',
                ) if key in data}
            else:
                result['error'] = 'Unexpected delivery quote format'
        except (requests.RequestException, ValueError):
            result['error'] = 'Delivery quote request failed'
        return result

    def handle(self, *args, **options):
        service = SabyOrderService()
        for order_id in options['order_ids']:
            try:
                order = Order.objects.get(pk=order_id)
            except Order.DoesNotExist as exc:
                raise CommandError(f'Order #{order_id} not found') from exc
            result = {'order': order_id,
                      'delivery_mode': getattr(settings, 'SABY_DELIVERY_MODE', 'item'),
                      'configured_delivery': {
                          'zone': order.delivery_type,
                          'point_id': settings.SABY_POINT_ID,
                          'district_id': getattr(settings, 'SABY_DELIVERY_DISTRICT_IDS', {}).get(order.delivery_type),
                      },
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
                    delivery = sale.get('delivery')
                    if isinstance(delivery, dict):
                        result['saby_delivery'] = {k: delivery[k] for k in (
                            'district', 'districtId', 'isPickup', 'cost',
                            'deliveryCost', 'deliveryPrice',
                        ) if k in delivery}
                        address = delivery.get('addressJSON')
                        result['address_json_type'] = type(address).__name__
                        if isinstance(address, str):
                            try:
                                address = json.loads(address)
                            except (ValueError, TypeError):
                                address = None
                        if isinstance(address, dict):
                            # Field names are sufficient for format diagnosis; no address values.
                            result['address_json_fields'] = sorted(address)
                    else:
                        result['saby_delivery'] = None
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
            if options['delivery_cost']:
                result['delivery_cost_probe'] = self.delivery_cost_probe(order, service)
            if options['normalized_address']:
                result['normalized_address_probe'] = self.normalized_address_probe(order, service)
            self.stdout.write(json.dumps(result, ensure_ascii=False, indent=2))
