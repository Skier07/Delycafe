import json
from json import loads
from datetime import datetime
from unittest.mock import Mock, patch

from django.test import SimpleTestCase, TestCase, override_settings

from orders.models import Order, OrderItem
from orders.services import SabyOrderService, confirm_order_paid


@override_settings(SABY_POINT_ID=187, SABY_PRICE_LIST_ID=4)
class SabyOrderCreationTests(TestCase):
    def setUp(self):
        self.token = patch(
            'orders.services.SabyCatalogService.get_token',
            return_value='test-token',
        ).start()
        self.post = patch('orders.services.requests.post').start()
        patch.object(
            SabyOrderService,
            '_resolve_delivery_datetime',
            return_value=datetime(2026, 9, 23, 13, 0),
        ).start()
        self.addCleanup(patch.stopall)

    def create_order(self, delivery_type):
        order = Order.objects.create(
            phone='79000000000',
            customer_name='Тест',
            delivery_type=delivery_type,
            address='Тестовая улица, 1',
            payment_type=Order.PaymentType.SBP,
            payment_status=Order.PaymentStatus.PAID,
            payment_amount=300,
            total_price=300,
        )
        OrderItem.objects.create(
            order=order,
            product_title='Тестовый товар',
            saby_id=394,
            quantity=1,
            price=300,
            total_price=300,
        )
        return order

    def assert_create_contract(self, delivery_type, expected_pickup):
        order = self.create_order(delivery_type)

        def accept_request(url, *, headers, json, timeout):
            self.assertEqual(url, SabyOrderService.ORDER_URL)
            self.assertIs(json['delivery']['isPickup'], expected_pickup)
            self.assertNotIn('isPickup', json)
            self.assertEqual(json['delivery']['paymentType'], 'online')
            self.assertNotIn('paymentType', json)
            self.assertEqual(json['nomenclatures'][0]['id'], 394)
            if not expected_pickup:
                self.assertIsInstance(json['delivery']['addressJSON'], str)
                address = loads(json['delivery']['addressJSON'])
                self.assertEqual(
                    address['Address'],
                    order.address,
                )
            return Mock(
                status_code=200,
                text='{"resultCode": 0}',
                json=Mock(return_value={
                    'resultCode': 0,
                    'orderNumber': 'test-order',
                    'sale_id': 100,
                    'saleKey': 'test-sale-key',
                }),
            )

        self.post.side_effect = accept_request
        SabyOrderService().create_order(order)
        order.refresh_from_db()
        self.assertEqual(order.saby_order_number, 'test-order')
        self.assertEqual(order.saby_external_id, 'test-sale-key')
        self.assertFalse(order.saby_payment_registered)

    def test_pickup_sends_required_nested_boolean(self):
        self.assert_create_contract(Order.DeliveryType.PICKUP, True)

    def test_delivery_sends_false_not_a_missing_flag(self):
        for delivery_type in (
            Order.DeliveryType.OZERSK,
            Order.DeliveryType.TATYSH,
            Order.DeliveryType.PROMPLOSHADKA,
        ):
            with self.subTest(delivery_type=delivery_type):
                self.assert_create_contract(delivery_type, False)

    def test_validation_details_persist_without_attempting_payment(self):
        order = self.create_order(Order.DeliveryType.OZERSK)
        details = "Невалидные параметры: {'delivery.isPickup': ['Отсутствует обязательное поле']}"
        payload = {
            'jsonrpc': '2.0',
            'error': {
                'code': -32000,
                'message': 'An internal server error occurred.',
                'details': details,
            },
            'id': None,
        }
        self.post.return_value = Mock(
            status_code=500,
            text=json.dumps(payload),
            json=Mock(return_value=payload),
        )
        with (
            patch('orders.order_notification_service.try_send_admin_order_email'),
            patch('orders.services._try_register_saby_payment') as register_payment,
        ):
            confirm_order_paid(order)

        order.refresh_from_db()
        self.assertIn(details, order.saby_dispatch_error)
        self.assertEqual(order.payment_status, Order.PaymentStatus.PAID)
        self.assertEqual(order.saby_sale_id, '')
        self.assertFalse(order.saby_payment_registered)
        register_payment.assert_not_called()
        self.post.assert_called_once()

    @override_settings(SABY_DELIVERY_MODE='item', SABY_DELIVERY_NOM_NUMBER='X7443708')
    def test_177_extra_delivery_stops_receipt_and_callback_does_not_recreate_order(self):
        order = self.create_order(Order.DeliveryType.OZERSK)
        order.delivery_price = 250
        order.payment_amount = order.total_price = 1600
        order.save()
        order.items.update(price=1150, total_price=1150)
        OrderItem.objects.create(order=order, product_title='Картофель фри',
                                 saby_id=395, price=200, quantity=1, total_price=200)
        self.post.return_value = Mock(status_code=200, text='{}', json=Mock(return_value={
            'resultCode': 0, 'orderNumber': '273', 'sale_id': 123,
            'saleKey': 'sale-177', 'totalPrice': 1850,
        }))
        with (
            patch.object(SabyOrderService, 'read_sale', return_value={'totalPrice': 1850}),
            patch('orders.order_notification_service.try_send_admin_order_email'),
            patch('orders.saby_order_status_service.SabyOrderStatusService.sync_order_status'),
        ):
            confirm_order_paid(order)
            confirm_order_paid(order)
        order.refresh_from_db()
        self.assertEqual(order.saby_sale_id, '123')
        self.assertEqual(order.payment_status, Order.PaymentStatus.PAID)
        self.assertFalse(order.saby_payment_registered)
        self.assertIn('1850', order.saby_payment_error)
        self.assertIn('1600', order.saby_payment_error)
        self.post.assert_called_once()
        sent = self.post.call_args.kwargs['json']['nomenclatures']
        self.assertEqual(sum(row['cost'] * row['count'] for row in sent), 1600)
        self.assertEqual(sum(row.get('nomNumber') == 'X7443708' for row in sent), 1)

    @override_settings(SABY_DELIVERY_MODE='native')
    def test_native_delivery_sends_goods_then_registers_full_total_once(self):
        order = self.create_order(Order.DeliveryType.OZERSK)
        order.delivery_price = 250
        order.payment_amount = order.total_price = 550
        order.save()
        self.post.side_effect = [
            Mock(status_code=200, text='{}', json=Mock(return_value={
                'resultCode': 0, 'orderNumber': '274', 'sale_id': 124,
                'saleKey': 'native-sale', 'totalPrice': 550,
            })),
            Mock(status_code=200, text='{}', json=Mock(return_value={
                'successFlag': True, 'taskId': 10,
            })),
        ]
        with (
            patch.object(SabyOrderService, 'read_sale', return_value={'totalPrice': 550}),
            patch.object(SabyOrderService, '_read_sale_resource', return_value={'payments': []}),
            patch('orders.order_notification_service.try_send_admin_order_email'),
            patch('orders.saby_order_status_service.SabyOrderStatusService.sync_order_status'),
        ):
            confirm_order_paid(order)
            confirm_order_paid(order)
        self.assertEqual(self.post.call_count, 2)
        create, register = self.post.call_args_list
        self.assertEqual(len(create.kwargs['json']['nomenclatures']), 1)
        self.assertEqual(create.kwargs['json']['nomenclatures'][0]['cost'], 300)
        self.assertIs(create.kwargs['json']['delivery']['isPickup'], False)
        self.assertEqual(register.kwargs['json']['bankSum'], 550)
        order.refresh_from_db()
        self.assertTrue(order.saby_payment_registered)


class SabyErrorMessageTests(SimpleTestCase):
    def test_existing_and_jsonrpc_error_formats(self):
        service = SabyOrderService()
        cases = [
            ({'errorMessage': 'Old error format'}, 'Old error format'),
            ({'error': {'message': 'JSON-RPC error'}}, 'JSON-RPC error'),
            ({'error': 'unexpected format'}, 'HTTP 500'),
            ({}, 'HTTP 500'),
        ]
        for payload, expected in cases:
            with self.subTest(payload=payload):
                self.assertIn(expected, service._extract_error_message(payload, 500))
