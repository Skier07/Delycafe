import json
from io import StringIO
from unittest.mock import patch

from django.core.management import call_command
from django.test import TestCase, override_settings

from orders.models import Order
from orders.services import SabyOrderService


class InspectSabyTotalsTests(TestCase):
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
