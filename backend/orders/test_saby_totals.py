from decimal import Decimal
from unittest.mock import Mock, patch
from django.test import TestCase, override_settings
from orders.models import Order, OrderItem
from orders.services import SabyOrderService, SabyOrderError, register_saby_payment


@override_settings(SABY_PRICE_LIST_ID=4, SABY_DELIVERY_NOM_NUMBER='DELIVERY-TEST')
class SabyTotalsTests(TestCase):
    def order(self, pickup=False, bonus=0):
        order = Order.objects.create(phone='79000000000',
            delivery_type=Order.DeliveryType.PICKUP if pickup else Order.DeliveryType.OZERSK,
            payment_status=Order.PaymentStatus.PAID,
            delivery_price=0 if pickup else 250,
            discount_amount=86 if pickup else 0, bonus_spent=bonus,
            total_price=(1624 if pickup else 1430)-bonus,
            payment_amount=(1624 if pickup else 1430)-bonus,
            saby_external_id='sale-uuid', saby_sale_id='123')
        lines = [(680, 1), (830, 1), (200, 1)] if pickup else [(820, 1), (90, 4)]
        for index, (price, qty) in enumerate(lines):
            OrderItem.objects.create(order=order, product_title=f'Product {index}',
                price=price, quantity=qty, total_price=price*qty, saby_id=index+1)
        return order

    def test_164_includes_delivery_without_discount(self):
        rows = SabyOrderService()._build_nomenclatures(self.order())
        self.assertEqual(sum(r['cost']*r['count'] for r in rows), 1430)
        self.assertEqual(rows[-1]['nomNumber'], 'DELIVERY-TEST')
        self.assertEqual(rows[-1]['cost'], 250)

    @override_settings(SABY_DELIVERY_NOM_NUMBER='X7443708')
    def test_common_service_uses_saved_price_for_each_zone(self):
        for zone, price in (
            (Order.DeliveryType.OZERSK, 250),
            (Order.DeliveryType.OZERSK, 300),
            (Order.DeliveryType.PROMPLOSHADKA, 400),
            (Order.DeliveryType.TATYSH, 550),
        ):
            with self.subTest(zone=zone, price=price):
                order = self.order()
                order.delivery_type = zone
                order.delivery_price = price
                order.payment_amount = order.total_price = 1180 + price
                rows = SabyOrderService()._build_nomenclatures(order)
                self.assertEqual(rows[-1], {
                    'nomNumber': 'X7443708', 'priceListId': 4,
                    'count': 1, 'name': 'Доставка', 'cost': price,
                })
                self.assertEqual(sum(r['cost'] * r['count'] for r in rows),
                                 order.payment_amount)

    def test_free_delivery_does_not_add_a_service(self):
        order = self.order()
        order.delivery_price = 0
        order.payment_amount = order.total_price = 1180
        rows = SabyOrderService()._build_nomenclatures(order)
        self.assertFalse(any('nomNumber' in row for row in rows))
        self.assertEqual(sum(r['cost'] * r['count'] for r in rows), 1180)

    @override_settings(SABY_DELIVERY_NOM_NUMBER='')
    def test_missing_delivery_mapping_stops_incomplete_order(self):
        with self.assertRaises(SabyOrderError):
            SabyOrderService()._build_nomenclatures(self.order())

    def test_165_pickup_rounding_and_bonus_target(self):
        order = self.order(pickup=True, bonus=33)
        service = SabyOrderService()
        rows = service._build_nomenclatures(order)
        self.assertEqual(sum(Decimal(str(r['cost'])) * r['count'] for r in rows), 1591)
        self.assertTrue(all(r['cost'] < before for r, before in zip(rows, [646, 788, 190])))
        service._assert_sale_total(order, {'totalPrice': 1591.0})
        with self.assertRaises(SabyOrderError):
            service._assert_sale_total(order, {'totalPrice': 1624})

    def test_legacy_sale_without_bonus_discount_is_rejected(self):
        order = self.order(pickup=True, bonus=33)
        service = SabyOrderService()
        with patch.object(service, 'read_sale', return_value={'totalPrice': 1624}), patch('orders.services.requests.post') as write:
            with self.assertRaises(SabyOrderError):
                service.apply_bonuses(order)
            write.assert_not_called()
        order.refresh_from_db()
        self.assertFalse(order.saby_bonus_applied)

    def test_local_discount_verified_without_native_saby_bonus_program(self):
        order = self.order(pickup=True, bonus=33)
        service = SabyOrderService()
        with patch.object(service, 'read_sale', return_value={'totalPrice': 1591}), patch('orders.services.requests.post') as write:
            service.apply_bonuses(order)
            write.assert_not_called()
        order.refresh_from_db()
        self.assertTrue(order.saby_bonus_applied)

    def test_error_survives_payment_transaction_rollback(self):
        order = self.order(pickup=True, bonus=33)
        with patch.object(SabyOrderService, 'apply_bonuses', side_effect=SabyOrderError('mismatch')), patch.object(SabyOrderService, 'register_payment') as register:
            with self.assertRaises(SabyOrderError):
                register_saby_payment(order)
            register.assert_not_called()
        order.refresh_from_db()
        self.assertEqual(order.saby_payment_error, 'mismatch')
        self.assertFalse(order.saby_payment_registered)

    def test_pending_receipt_is_not_submitted_again(self):
        order = self.order()
        service = SabyOrderService()
        with patch.object(service, 'read_sale', return_value={'totalPrice': 1430}), patch.object(service, '_read_sale_resource', return_value={'payments': [{'id': 1, 'isClosed': None}]}), patch('orders.services.requests.post') as post:
            with self.assertRaises(SabyOrderError):
                service.register_payment(order)
            post.assert_not_called()

    def test_matching_totals_send_exact_bank_amount(self):
        order = self.order(pickup=True, bonus=33)
        service = SabyOrderService()
        with patch.object(service, 'read_sale', return_value={'totalPrice': 1591}), patch.object(service, '_read_sale_resource', return_value={'payments': []}), patch('orders.services.SabyCatalogService.get_token', return_value='test'), patch('orders.services.requests.post', return_value=Mock(status_code=200, json=Mock(return_value={'successFlag': True}))) as post:
            service.register_payment(order)
            self.assertEqual(post.call_args.kwargs['json']['bankSum'], 1591)

    def test_http_200_with_rejected_task_is_not_success(self):
        order = self.order()
        service = SabyOrderService()
        with patch.object(service, 'read_sale', return_value={'totalPrice': 1430}), patch.object(service, '_read_sale_resource', return_value={'payments': []}), patch('orders.services.SabyCatalogService.get_token', return_value='test'), patch('orders.services.requests.post', return_value=Mock(status_code=200, json=Mock(return_value={'successFlag': False}))):
            with self.assertRaises(SabyOrderError):
                service.register_payment(order)

    def test_pickup_without_bonuses_keeps_existing_unit_rounding(self):
        rows = SabyOrderService()._build_nomenclatures(self.order(pickup=True))
        self.assertEqual([r['cost'] for r in rows], [646, 788, 190])

    def test_bonus_does_not_reduce_delivery(self):
        rows = SabyOrderService()._build_nomenclatures(self.order(bonus=33))
        self.assertEqual(rows[-1]['cost'], 250)
        self.assertEqual(sum(Decimal(str(r['cost'])) * r['count'] for r in rows), 1397)

    def test_fractional_unit_discount_preserves_quantity_and_exact_amount(self):
        rows = SabyOrderService._discount_local_bonuses(
            [{'id': 1, 'cost': 90, 'count': 3, 'name': 'Блины'}], 1)
        self.assertEqual(sum(r['count'] for r in rows), 3)
        self.assertEqual(sum(Decimal(str(r['cost'])) * r['count'] for r in rows), 269)
        self.assertEqual({r['cost'] for r in rows}, {89.66, 89.67})
        self.assertTrue(all(r['id'] == 1 for r in rows))

    def test_excessive_bonus_is_rejected(self):
        with self.assertRaises(SabyOrderError):
            SabyOrderService._discount_local_bonuses([{'cost': 90, 'count': 1}], 91)

    def test_missing_product_mapping_stops_incomplete_order(self):
        order = self.order()
        order.items.update(saby_id=None)
        with self.assertRaises(SabyOrderError):
            SabyOrderService()._build_nomenclatures(order)

    def test_old_success_flag_does_not_bypass_amount_check(self):
        order = self.order(pickup=True, bonus=33)
        order.saby_bonus_applied = True
        order.save()
        service = SabyOrderService()
        with patch.object(service, 'read_sale', return_value={'totalPrice': 1624}), patch('orders.services.requests.post') as post:
            with self.assertRaises(SabyOrderError):
                service.register_payment(order)
            post.assert_not_called()
