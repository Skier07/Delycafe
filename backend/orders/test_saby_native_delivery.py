from datetime import datetime
from decimal import Decimal
from unittest.mock import Mock, patch

from django.test import TestCase, override_settings

from orders.models import Order, OrderItem
from orders.services import SabyOrderError, SabyOrderService, confirm_order_paid


DISTRICTS = {'ozersk': 7744, 'promploshadka': 7746, 'tatysh': 7745}

# Тарифы из ответа retail/district/list точки 187 от 17.10.2026.
TARIFFS = {
    7744: [(50, 300), (1000, 250), (2000, 0)],
    7746: [(0, 400)],
    7745: [(0, 550)],
}


def saby_tariff(district_id, goods_total):
    eligible = [price for threshold, price in TARIFFS[district_id]
                if goods_total >= threshold]
    if not eligible:
        raise AssertionError('API fixture has no tariff below the first threshold')
    return eligible[-1]


@override_settings(
    SABY_POINT_ID=187, SABY_PRICE_LIST_ID=4,
    SABY_DELIVERY_MODE='native', SABY_DELIVERY_DISTRICT_IDS=DISTRICTS,
)
class SabyNativeDeliveryTests(TestCase):
    def make_order(self, goods_total, delivery_price, zone='ozersk'):
        order = Order.objects.create(
            phone='79000000000', delivery_type=zone, address='Тестовый адрес',
            payment_status=Order.PaymentStatus.PAID,
            products_total=goods_total, delivery_price=delivery_price,
            payment_amount=goods_total + delivery_price,
            total_price=goods_total + delivery_price,
        )
        OrderItem.objects.create(
            order=order, product_title='Тестовый товар', saby_id=394,
            price=goods_total, quantity=1, total_price=goods_total,
        )
        return order

    def test_native_orders_match_confirmed_tariffs_and_register_once(self):
        cases = [
            ('ozersk', 600, 300),   # №173: итог 900 вместо 1200.
            ('ozersk', 720, 300),   # №174: итог 1020 вместо 1270.
            ('ozersk', 1350, 250),  # №177: итог 1600 вместо 1850.
            ('ozersk', 999, 300),
            ('ozersk', 1000, 250),
            ('ozersk', 1999, 250),
            ('ozersk', 2000, 0),
            ('promploshadka', 600, 400),
            ('tatysh', 600, 550),
        ]
        for zone, goods_total, delivery_price in cases:
            with self.subTest(zone=zone, goods=goods_total):
                order = self.make_order(goods_total, delivery_price, zone)
                remote_sale = {}

                def accept_post(url, *, json, **kwargs):
                    if url == SabyOrderService.ORDER_URL:
                        self.assertFalse(any('nomNumber' in row for row in json['nomenclatures']))
                        self.assertEqual(json['delivery']['district'], DISTRICTS[zone])
                        self.assertIs(json['delivery']['isPickup'], False)
                        sent_sum = sum(Decimal(str(row['cost'])) * row['count']
                                       for row in json['nomenclatures'])
                        self.assertEqual(sent_sum, goods_total)
                        remote_sale['totalPrice'] = float(
                            sent_sum + saby_tariff(json['delivery']['district'], sent_sum))
                        data = {
                            'resultCode': 0, 'sale_id': order.pk + 10000,
                            'saleKey': f'test-sale-{order.pk}', **remote_sale,
                        }
                    else:
                        self.assertEqual(url, SabyOrderService.REGISTER_PAYMENT_URL.format(
                            external_id=f'test-sale-{order.pk}'))
                        self.assertEqual(json['bankSum'], goods_total + delivery_price)
                        self.assertEqual(json['bankSum'], remote_sale['totalPrice'])
                        data = {'successFlag': True, 'taskId': order.pk}
                    return Mock(status_code=200, json=Mock(return_value=data),
                                text=str(data))

                with (
                    patch('orders.services.requests.post', side_effect=accept_post) as post,
                    patch('orders.services.SabyCatalogService.get_token', return_value='test'),
                    patch.object(SabyOrderService, 'read_sale', side_effect=lambda order: dict(remote_sale)),
                    patch.object(SabyOrderService, '_read_sale_resource', return_value={'payments': []}),
                    patch.object(SabyOrderService, '_resolve_delivery_datetime', return_value=datetime(2026, 10, 17, 13, 0)),
                    patch('orders.order_notification_service.try_send_admin_order_email'),
                    patch('orders.saby_order_status_service.SabyOrderStatusService.sync_order_status'),
                ):
                    confirm_order_paid(order)
                    confirm_order_paid(order)
                    self.assertEqual(post.call_count, 2)
                order.refresh_from_db()
                self.assertTrue(order.saby_payment_registered)
                self.assertEqual(order.saby_payment_error, '')

    @override_settings(SABY_DELIVERY_MODE='item', SABY_DELIVERY_NOM_NUMBER='X7443708')
    def test_item_mode_plus_saby_tariff_reproduces_reported_totals(self):
        service = SabyOrderService()
        for goods, delivery, observed in [(600, 300, 1200), (720, 300, 1270), (1350, 250, 1850)]:
            with self.subTest(goods=goods):
                order = self.make_order(goods, delivery)
                rows = service._build_nomenclatures(order)
                base = sum(row['cost'] * row['count'] for row in rows)
                remote_total = base + saby_tariff(7744, base)
                self.assertEqual(remote_total, observed)
                with self.assertRaises(SabyOrderError):
                    service._assert_sale_total(order, {'totalPrice': remote_total})

    def test_missing_or_invalid_district_stops_before_remote_creation(self):
        order = self.make_order(600, 300)
        for districts in ({}, {'ozersk': None}, {'ozersk': True}, {'ozersk': -1}):
            with (
                self.subTest(districts=districts),
                override_settings(SABY_DELIVERY_DISTRICT_IDS=districts),
                patch('orders.services.requests.post') as post,
            ):
                with self.assertRaisesMessage(SabyOrderError, 'Не задан район Saby'):
                    SabyOrderService().create_order(order)
                post.assert_not_called()

    @override_settings(SABY_DELIVERY_DISTRICT_IDS={})
    def test_pickup_does_not_require_or_send_district(self):
        order = self.make_order(600, 0, 'pickup')
        payload = SabyOrderService()._build_payload(order, [])
        self.assertIs(payload['delivery']['isPickup'], True)
        self.assertNotIn('district', payload['delivery'])
