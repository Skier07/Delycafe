import json
from io import StringIO
from unittest.mock import Mock, patch

from django.core.management import call_command
from django.test import TestCase, override_settings

from orders.models import Order
from orders.services import SabyOrderService
from orders.management.commands.inspect_saby_totals import Command


class InspectSabyTotalsTests(TestCase):
    @override_settings(SABY_POINT_ID=187, SABY_DELIVERY_DISTRICT_IDS={'ozersk': 7744})
    def test_normalized_probe_uses_exact_returned_json_and_net_goods_without_saving(self):
        order = Order.objects.create(
            phone='79000000000', delivery_type='ozersk', address='Тестовая, 1',
            products_total=1700, discount_amount=100, bonus_spent=60, delivery_price=250,
        )
        normalized = json.dumps({'Address': 'Private address', 'HouseNum': '1',
                                 'Coordinates': {'Lat': 55, 'Lon': 60}})
        replies = [
            Mock(status_code=200, json=Mock(return_value={'addresses': [
                {'addressJSON': normalized}, {'addressJSON': normalized},
            ]})),
            Mock(status_code=200, json=Mock(return_value={'district': 7744, 'cost': 250})),
            Mock(status_code=200, json=Mock(return_value={'district': None, 'cost': None})),
        ]
        before = Order.objects.values().get(pk=order.pk)
        with (
            patch('orders.management.commands.inspect_saby_totals.SabyCatalogService.get_token', return_value='test'),
            patch('orders.management.commands.inspect_saby_totals.requests.get', side_effect=replies) as get,
            patch('orders.services.requests.post') as post,
        ):
            result = Command().normalized_address_probe(order, SabyOrderService())
            post.assert_not_called()
        self.assertEqual(result['candidate_count'], 2)
        self.assertEqual(get.call_args_list[0].kwargs['params']['address'], 'Озерск, Тестовая, 1')
        self.assertEqual(get.call_args_list[1].kwargs['params'], {
            'pointId': 187, 'address': normalized, 'price': 1540,
        })
        self.assertTrue(result['candidates'][0]['configured_district_matches'])
        self.assertTrue(result['candidates'][0]['local_delivery_matches'])
        self.assertFalse(result['candidates'][1]['local_delivery_matches'])
        self.assertNotIn('Private address', json.dumps(result))
        self.assertEqual(before, Order.objects.values().get(pk=order.pk))

    def test_normalized_probe_handles_empty_or_malformed_candidates_without_guessing(self):
        order = Order(delivery_type='ozersk', products_total=1000, discount_amount=0,
                      bonus_spent=0, delivery_price=250, address='Тестовая, 1')
        for data in ({'addresses': []}, {'addresses': [None, {'addressJSON': '{}bad'}]}, {}):
            with (
                self.subTest(data=data),
                patch('orders.management.commands.inspect_saby_totals.SabyCatalogService.get_token', return_value='test'),
                patch('orders.management.commands.inspect_saby_totals.requests.get',
                      return_value=Mock(status_code=200, json=Mock(return_value=data))) as get,
            ):
                result = Command().normalized_address_probe(order, SabyOrderService())
                self.assertEqual(get.call_count, 1)
                self.assertTrue('error' in result or result.get('candidate_count') in (0, 2))

    @override_settings(SABY_DELIVERY_MODE='native', SABY_POINT_ID=187,
                       SABY_DELIVERY_DISTRICT_IDS={'ozersk': 7744})
    def test_delivery_quote_and_wrong_closed_amount_are_read_only(self):
        order = Order.objects.create(
            phone='79000000000', delivery_type='ozersk', address='Тестовая, 1',
            products_total=1540, delivery_price=250, payment_amount=1790,
            total_price=1790, payment_status='paid', saby_sale_id='93726',
            saby_order_number='93726', saby_external_id='test-sale-179',
            saby_payment_error='Суммы не совпадают',
        )
        sale = {'totalPrice': 1540, 'nomenclatures': [{'totalPrice': 1540}],
                'delivery': {'district': 7744, 'isPickup': False,
                             'addressJSON': '{"Address":"Тестовая, 1"}'}}
        state = {'payState': 200, 'payments': [{'amount': 1540, 'isClosed': True,
                                               'paymentType': 'full'}]}
        output = StringIO()
        with (
            patch.object(SabyOrderService, 'read_sale', return_value=sale),
            patch.object(SabyOrderService, '_read_sale_resource', return_value=state),
            patch('orders.management.commands.inspect_saby_totals.SabyCatalogService.get_token', return_value='test'),
            patch('orders.management.commands.inspect_saby_totals.requests.get',
                  return_value=Mock(status_code=200, json=Mock(return_value={'district': 7744, 'cost': 250}))) as get,
            patch('orders.services.requests.post') as post,
        ):
            call_command('inspect_saby_totals', order.pk, delivery_cost=True, stdout=output)
            post.assert_not_called()
        result = json.loads(output.getvalue())
        self.assertEqual(result['saby_minus_payment'], '-250')
        self.assertEqual(result['saby_minus_positions'], '0')
        self.assertEqual(result['configured_delivery']['district_id'], 7744)
        self.assertEqual(result['saby_delivery']['district'], 7744)
        self.assertEqual(result['address_json_fields'], ['Address'])
        self.assertNotIn(order.address, output.getvalue())
        self.assertEqual(result['delivery_cost_probe']['response']['cost'], 250)
        self.assertEqual(get.call_args.kwargs['params']['price'], 1540)
        self.assertIsInstance(get.call_args.kwargs['params']['address'], str)
        order.refresh_from_db()
        self.assertFalse(order.saby_payment_registered)
        self.assertEqual(order.saby_payment_error, 'Суммы не совпадают')

    @override_settings(SABY_DELIVERY_MODE='native')
    def test_native_delivery_and_completed_payment_are_reported_without_mutation(self):
        order = Order.objects.create(
            phone='79000000000', products_total=1350, delivery_price=250,
            total_price=1600, payment_amount=1600,
            payment_status=Order.PaymentStatus.PAID,
            saby_sale_id='123', saby_order_number='273', saby_external_id='sale-uuid',
            saby_payment_error='Старая ошибка: 1850 вместо 1600',
        )
        sale = {'totalPrice': 1600, 'totalSum': 1600, 'nomenclatures': [
            {'name': 'Пицца', 'totalPrice': 1150},
            {'name': 'Картофель фри', 'totalPrice': 200},
        ]}
        state = {'payState': 200, 'payments': [{
            'amount': 1600, 'isClosed': True, 'paymentType': 'full',
        }]}
        output = StringIO()
        with (
            patch.object(SabyOrderService, 'read_sale', return_value=sale),
            patch.object(SabyOrderService, '_read_sale_resource', return_value=state),
            patch('orders.services.requests.post') as post,
        ):
            call_command('inspect_saby_totals', order.pk, stdout=output)
            post.assert_not_called()
        result = json.loads(output.getvalue())
        self.assertEqual(result['delivery_mode'], 'native')
        self.assertEqual(result['saby_minus_payment'], '0')
        self.assertEqual(result['saby_minus_positions'], '250')
        self.assertEqual(result['local']['saby_order_number'], '273')
        order.refresh_from_db()
        self.assertFalse(order.saby_payment_registered)
        self.assertEqual(order.saby_payment_error, 'Старая ошибка: 1850 вместо 1600')

    def test_unpaid_order_without_saby_sale_does_not_request_remote_state(self):
        order = Order.objects.create(phone='79000000000', payment_amount=1600)
        with (
            patch.object(SabyOrderService, 'read_sale') as sale,
            patch.object(SabyOrderService, '_read_sale_resource') as state,
        ):
            call_command('inspect_saby_totals', order.pk, stdout=StringIO())
            sale.assert_not_called()
            state.assert_not_called()
