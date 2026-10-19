"""Offline regression coverage for checkout identity, reservations and bank events."""
from unittest.mock import patch
import uuid

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from catalog.models import Category, Product
from customers.models import Customer
from customers.services.auth_token_service import create_customer_access_token
from legal.services import save_customer_consents
from orders.models import Order
from orders.serializers import OrderCreateSerializer
from orders.services import confirm_order_paid, dispatch_order_to_saby, SabyOrderError
from payments.services import (
    AlfaPaymentError, _apply_alfa_status_response, close_unpaid_alfa_order,
)


@override_settings(ALFA_PAYMENT_ENABLED=False, SABY_DELIVERY_MODE='item',
                   ORDER_ADMIN_EMAIL_ENABLED=False)
class CheckoutSecurityTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create(phone='79000000101', name='Owner', bonus_balance=500)
        save_customer_consents(customer=self.customer, terms=True, privacy=True, pd_consent=True)
        category = Category.objects.create(title='Test', slug='security', show_in_app=True)
        self.product = Product.objects.create(category=category, title='Product', price=1000,
                                             saby_id=880001, is_active=True, show_in_app=True)
        self.payload = {
            'phone': self.customer.phone, 'customer_name': 'Owner',
            'delivery_type': 'pickup', 'delivery_time_type': 'asap', 'payment_type': 'card',
            'bonus_spent': 100,
            'items': [{'product_api_id': f'api_{self.product.pk}', 'product_title': 'Untrusted name',
                       'saby_id': self.product.saby_id, 'quantity': 1, 'price': 1}],
        }

    def login(self):
        token = create_customer_access_token(customer_id=self.customer.pk, phone=self.customer.phone)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + token)

    def checkout(self, payload=None):
        with patch('orders.serializers.validate_order_delivery_window'):
            return self.client.post('/api/orders/', payload or self.payload, format='json')

    def test_guest_cannot_spend_bonus_change_profile_or_cancel_order(self):
        other = Order.objects.create(customer=self.customer, phone=self.customer.phone,
                                     payment_external_id='payable-session')
        self.assertEqual(self.checkout().status_code, 403)
        self.customer.refresh_from_db()
        other.refresh_from_db()
        self.assertEqual((self.customer.bonus_balance, self.customer.name), (500, 'Owner'))
        self.assertEqual(other.status, 'new')
        self.assertEqual(Order.objects.count(), 1)

    def test_authenticated_checkout_uses_canonical_item_and_debits_once(self):
        self.login()
        response = self.checkout()
        self.assertEqual(response.status_code, 201, response.data)
        order = Order.objects.get(pk=response.data['id'])
        item = order.items.get()
        self.assertEqual((item.product_title, item.price, item.saby_id), ('Product', 1000, 880001))
        self.assertEqual(order.payment_amount, 850)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.bonus_balance, 400)

    def test_conflicting_or_disabled_saby_identity_rejected(self):
        self.login()
        expensive = Product.objects.create(category=self.product.category, title='Expensive',
                                           price=5000, saby_id=880002, is_active=False)
        for saby_id in (expensive.saby_id, 999999):
            payload = {**self.payload, 'items': [{**self.payload['items'][0], 'saby_id': saby_id}]}
            self.assertEqual(self.checkout(payload).status_code, 400)
        self.assertFalse(Order.objects.exists())

    def test_timeout_retry_with_operation_key_cannot_debit_bonus_twice(self):
        self.login()
        payload = {**self.payload, 'checkout_key': str(uuid.uuid4()), 'bonus_spent': 500}
        first = self.checkout(payload)
        second = self.checkout(payload)
        self.assertEqual(first.status_code, 201, first.data)
        self.assertEqual(second.status_code, 201, second.data)
        self.assertEqual(first.data['id'], second.data['id'])
        self.assertEqual(Order.objects.count(), 1)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.bonus_balance, 500 - first.data['bonus_spent'])
        modified = self.checkout({**payload, 'comment': 'different request'})
        self.assertEqual(modified.status_code, 400)

    def test_retry_of_paid_operation_does_not_create_another_bank_session(self):
        self.login()
        payload = {**self.payload, 'checkout_key': str(uuid.uuid4())}
        first = self.checkout(payload)
        Order.objects.filter(pk=first.data['id']).update(payment_status='paid')
        with override_settings(ALFA_PAYMENT_ENABLED=True), \
             patch('orders.views.create_alfa_payment') as create_payment:
            second = self.checkout(payload)
        self.assertEqual(second.status_code, 201, second.data)
        self.assertEqual(second.data['id'], first.data['id'])
        self.assertEqual(second.data['payment_status'], 'paid')
        create_payment.assert_not_called()

    def test_inactive_category_rejected(self):
        self.login()
        self.product.category.is_active = False
        self.product.category.save()
        self.assertEqual(self.checkout().status_code, 400)

    def test_cart_change_keeps_other_payable_order_and_reservation(self):
        self.login()
        first = self.checkout()
        self.assertEqual(first.status_code, 201, first.data)
        order = Order.objects.get(pk=first.data['id'])
        order.payment_external_id = 'still-payable'
        order.save()
        second = self.checkout({**self.payload, 'items': [{**self.payload['items'][0], 'quantity': 2}]})
        self.assertEqual(second.status_code, 201, second.data)
        order.refresh_from_db()
        self.assertEqual(order.status, 'new')
        self.assertFalse(order.bonus_compensated)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.bonus_balance, 300)

    def test_late_paid_historical_cancelled_order_is_held_for_review(self):
        order = Order.objects.create(customer=self.customer, phone=self.customer.phone,
                                     status='canceled', bonus_spent=100, bonus_compensated=True)
        with patch('orders.services._dispatch_order_to_saby_core') as dispatch, \
             patch('orders.services._record_bonus_earn') as earn:
            result = confirm_order_paid(order)
        dispatch.assert_not_called()
        earn.assert_not_called()
        self.assertEqual(result.payment_status, 'paid')
        self.assertIn('ручная сверка', result.saby_payment_error)
        with self.assertRaises(SabyOrderError):
            dispatch_order_to_saby(result)

    def test_close_stale_object_cannot_downgrade_paid_order(self):
        stale = Order.objects.create(phone=self.customer.phone, payment_external_id='bank')
        Order.objects.filter(pk=stale.pk).update(payment_status='paid')
        close_unpaid_alfa_order(stale)
        stale.refresh_from_db()
        self.assertEqual(stale.payment_status, 'paid')
        self.assertEqual(stale.payment_external_id, 'bank')

    def test_failed_callback_checks_bank_and_keeps_paid_status(self):
        order = Order.objects.create(phone=self.customer.phone, payment_status='paid',
                                     payment_external_id='bank')
        with patch('payments.callback_handlers.get_alfa_payment_status',
                   side_effect=AlfaPaymentError('offline')) as bank:
            response = self.client.post('/api/payments/alfa/callback/', {
                'orderNumber': f'delycafe-{order.pk}', 'operation': 'declinedbytimeout', 'status': '1',
            })
        self.assertEqual(response.status_code, 200)
        bank.assert_called_once()
        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')

    def test_every_paid_status_requires_matching_bank_totals(self):
        order = Order.objects.create(phone=self.customer.phone, payment_amount=1600, total_price=1600,
                                     payment_external_id='correct-session')
        valid = {'orderStatus': 2, 'orderNumber': f'delycafe-{order.pk}', 'amount': 160000,
                 'currency': '810', 'orderId': 'correct-session'}
        for bad in ({'amount': 1}, {'orderNumber': 'other'}, {'currency': '840'},
                    {'orderId': 'other'}, {'amount': 'NaN'},
                    {'paymentAmountInfo': {'depositedAmount': 160000, 'refundedAmount': 100}}):
            with self.subTest(bad=bad), patch('payments.services.confirm_order_paid') as confirm:
                with self.assertRaises(AlfaPaymentError):
                    _apply_alfa_status_response(order, {**valid, **bad})
                confirm.assert_not_called()
        with patch('payments.services.confirm_order_paid') as confirm:
            _apply_alfa_status_response(order, valid)
            confirm.assert_called_once()

    def test_unknown_bank_status_does_not_refund_reservation(self):
        order = Order.objects.create(phone=self.customer.phone, customer=self.customer, bonus_spent=100)
        _apply_alfa_status_response(order, {'orderStatus': 'unexpected'})
        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'unpaid')
        self.assertFalse(order.bonus_compensated)
