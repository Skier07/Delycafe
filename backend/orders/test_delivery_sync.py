import copy
from io import StringIO
from types import SimpleNamespace
from unittest.mock import Mock, patch

import requests
from django.core.management import call_command
from django.db import connection
from django.test import TestCase, TransactionTestCase, override_settings
from rest_framework.exceptions import ValidationError
from rest_framework.test import APIRequestFactory

from orders.delivery_pricing import calculate_delivery_price
from orders.delivery_views import DeliveryConfigAPIView
from orders.models import DeliveryInfoSection, DeliveryZone, Order
from orders.saby_delivery_sync import DeliverySyncError, sync_delivery_tariffs
from orders.serializers import OrderCreateSerializer


class DeliverySyncTransactionTests(TransactionTestCase):
    def test_network_fetch_does_not_hold_database_transaction(self):
        def fetch():
            self.assertFalse(connection.in_atomic_block)
            return {}

        with patch('orders.saby_delivery_sync.fetch_districts', side_effect=fetch), \
             patch('orders.saby_delivery_sync._apply_tariffs', return_value=[]) as apply:
            self.assertEqual(sync_delivery_tariffs(), [])
        apply.assert_called_once_with({}, dry_run=False)


PAYLOAD = {'districts': [
    {'districtId': 7744, 'cost': 350, 'costForFreeDelivery': 2200,
     'sumThresholds': [{'From': 50, 'Price': 350}, {'From': 1000, 'Price': 280}, {'From': 2200, 'Price': 0}]},
    {'districtId': 7746, 'cost': 450, 'costForFreeDelivery': 1000000000,
     'sumThresholds': [{'From': 0, 'Price': 450}]},
    {'districtId': 7745, 'cost': 600, 'costForFreeDelivery': 1000000000,
     'sumThresholds': [{'From': 0, 'Price': 600}]},
], 'outcome': {'hasMore': False}}


@override_settings(SABY_DELIVERY_MODE='native', SABY_DELIVERY_DISTRICT_IDS={
    'ozersk': 7744, 'promploshadka': 7746, 'tatysh': 7745,
})
class DeliverySyncTests(TestCase):
    def setUp(self):
        self.token = patch('orders.saby_delivery_sync.SabyCatalogService.get_token', return_value='test').start()
        self.http = patch('orders.saby_delivery_sync.requests.get').start()
        self.http.return_value = Mock(json=Mock(return_value=copy.deepcopy(PAYLOAD)))
        self.addCleanup(patch.stopall)

    def config(self):
        return DeliveryConfigAPIView.as_view()(APIRequestFactory().get('/')).data

    def test_prices_descriptions_and_legacy_api_change_together(self):
        sync_delivery_tariffs()
        for total, expected in [(50, 350), (999, 350), (1000, 280), (2199, 280), (2200, 0)]:
            self.assertEqual(calculate_delivery_price('ozersk', total), expected)
        self.assertEqual(calculate_delivery_price('promploshadka', 200), 450)
        self.assertEqual(calculate_delivery_price('tatysh', 200), 600)
        config = self.config()
        self.assertEqual(config['price_basis'], 'after_discounts')
        zones = {zone['code']: zone for zone in config['zones']}
        self.assertIn('280 ₽', zones['ozersk']['checkout_description'])
        self.assertIn('450 ₽', zones['promploshadka']['checkout_description'])
        self.assertIn('производственную территорию', zones['promploshadka']['checkout_description'])
        self.assertTrue(any('280 ₽' in row['content'] for row in config['info_sections']))
        self.assertFalse(any('{{' in row['content'] for row in config['info_sections']))

    def test_sync_does_not_change_orders_pickup_or_editor_notes(self):
        order = Order.objects.create(phone='79000000000', delivery_price=250, payment_amount=1600, total_price=1600, payment_status='paid')
        zone = DeliveryZone.objects.get(code='tatysh')
        zone.checkout_description = '{{delivery_tariff:tatysh}}\nПозвоните у шлагбаума.'
        zone.save()
        pickup = DeliveryZone.objects.get(code='pickup').checkout_description
        sync_delivery_tariffs()
        order.refresh_from_db()
        self.assertEqual((order.delivery_price, order.payment_amount), (250, 1600))
        self.assertEqual(DeliveryZone.objects.get(code='pickup').checkout_description, pickup)
        self.assertTrue(any('Позвоните у шлагбаума.' in row['checkout_description'] for row in self.config()['zones']))

    def test_dry_run_and_repeat_sync(self):
        call_command('sync_saby_delivery_tariffs', '--dry-run', stdout=StringIO(), stderr=StringIO())
        self.assertEqual(calculate_delivery_price('ozersk', 500), 300)
        self.assertTrue(any(row['changed'] for row in sync_delivery_tariffs()))
        self.assertFalse(any(row['changed'] for row in sync_delivery_tariffs()))

    def test_invalid_or_partial_payload_preserves_all_tariffs(self):
        variants = []
        for bad in [-1, 250.5, 'NaN', None, True]:
            value = copy.deepcopy(PAYLOAD)
            value['districts'][2]['sumThresholds'][0]['Price'] = bad
            variants.append(value)
        value = copy.deepcopy(PAYLOAD)
        value['outcome']['hasMore'] = True
        variants.append(value)
        value = copy.deepcopy(PAYLOAD)
        value['districts'].pop()
        variants.append(value)
        value = copy.deepcopy(PAYLOAD)
        value['districts'][0]['sumThresholds'].append({'From': 1000, 'Price': 250})
        variants.append(value)
        for value in variants:
            with self.subTest(payload=value):
                self.http.return_value.json.return_value = value
                with self.assertRaises(DeliverySyncError):
                    sync_delivery_tariffs()
                self.assertEqual(calculate_delivery_price('ozersk', 500), 300)
                self.assertEqual(calculate_delivery_price('tatysh', 500), 550)

    def test_network_failure_preserves_prices_and_blocks_order_before_payment(self):
        self.http.side_effect = requests.Timeout()
        with patch.object(OrderCreateSerializer, '_create_or_reuse_atomic') as create:
            with self.assertRaises(ValidationError):
                OrderCreateSerializer().create_or_reuse({'delivery_type': 'ozersk'})
            create.assert_not_called()
        self.assertEqual(calculate_delivery_price('ozersk', 500), 300)

    def test_every_delivery_checkout_refreshes_but_pickup_does_not(self):
        with patch.object(OrderCreateSerializer, '_create_or_reuse_atomic', return_value='order'):
            self.assertEqual(OrderCreateSerializer().create_or_reuse({'delivery_type': 'ozersk'}), 'order')
            self.assertEqual(calculate_delivery_price('ozersk', 500), 350)
            self.http.reset_mock()
            OrderCreateSerializer().create_or_reuse({'delivery_type': 'pickup'})
            self.http.assert_not_called()

    def test_update_from_another_worker_does_not_use_stale_cache(self):
        self.assertEqual(calculate_delivery_price('tatysh', 500), 550)
        # QuerySet.update bypasses local signals, as a separate process would.
        DeliveryZone.objects.filter(code='tatysh').update(fixed_price=650)
        self.assertEqual(calculate_delivery_price('tatysh', 500), 650)

    def test_bonus_boundary_uses_same_net_goods_sum_as_saby(self):
        sync_delivery_tariffs()
        pricing = OrderCreateSerializer()._calculate_order_pricing(
            customer=SimpleNamespace(bonus_balance=100),
            items_data=[{'price': 1000, 'quantity': 1}],
            delivery_type='ozersk', requested_bonus_spent=50,
        )
        self.assertEqual(pricing['delivery_price'], 350)
        self.assertEqual(pricing['total_price'], 1300)
        with self.assertRaises(ValueError):
            calculate_delivery_price('ozersk', 49)

    def test_fixed_cost_fallback_free_delivery_and_bad_auth(self):
        value = copy.deepcopy(PAYLOAD)
        value['districts'][0]['sumThresholds'] = []
        self.http.return_value.json.return_value = value
        sync_delivery_tariffs()
        self.assertEqual(calculate_delivery_price('ozersk', 1000), 350)
        self.assertEqual(calculate_delivery_price('ozersk', 2200), 0)
        self.token.return_value = {'error': 'access denied'}
        with self.assertRaises(DeliverySyncError):
            sync_delivery_tariffs()

    def test_custom_text_warning_and_template_rendering(self):
        DeliveryZone.objects.filter(code='ozersk').update(checkout_description='Мой старый текст 300 ₽')
        warning = StringIO()
        call_command('sync_saby_delivery_tariffs', stdout=StringIO(), stderr=warning)
        self.assertIn('{{delivery_tariff:ozersk}}', warning.getvalue())
        self.assertEqual(DeliveryZone.objects.get(code='ozersk').checkout_description, 'Мой старый текст 300 ₽')
