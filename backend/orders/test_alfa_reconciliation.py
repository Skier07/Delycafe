from datetime import timedelta
from io import StringIO
from unittest.mock import patch

from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone

from orders.models import Order
from payments.reconciliation import reconcile_order_payment
from payments.services import AlfaPaymentError, expire_stale_unpaid_order


@override_settings(
    ALFA_PAYMENT_ENABLED=True,
    ORDER_ADMIN_EMAIL_ENABLED=True,
    ORDER_ADMIN_EMAIL='admin@example.com',
    EMAIL_HOST_USER='test@example.com',
    EMAIL_HOST_PASSWORD='test-password',
)
class AlfaReconciliationTests(TestCase):
    def setUp(self):
        self.order = Order.objects.create(
            phone='79000000000',
            payment_type=Order.PaymentType.SBP,
            payment_external_id='test-bank-id',
            payment_amount=38,
            total_price=38,
        )
        self.response = {
            'orderNumber': f'delycafe-{self.order.pk}',
            'orderStatus': 2,
            'amount': 3800,
            'currency': '810',
            'paymentAmountInfo': {'depositedAmount': 3800, 'refundedAmount': 0},
        }
        self.fetch = self.start_patch(
            'payments.reconciliation._fetch_alfa_status_response',
            return_value=self.response,
        )
        self.send = self.start_patch(
            'orders.order_notification_service.send_mail', return_value=1,
        )
        self.create = self.start_patch(
            'orders.services.SabyOrderService.create_order', side_effect=self.create_saby,
        )
        self.start_patch('orders.services.SabyOrderService.apply_bonuses')
        self.register = self.start_patch(
            'orders.services.SabyOrderService.register_payment',
            return_value={'successFlag': True, 'taskId': 1},
        )
        self.start_patch('orders.saby_order_status_service.SabyOrderStatusService.sync_order_status')

    def start_patch(self, name, **kwargs):
        patcher = patch(name, **kwargs)
        mocked = patcher.start()
        self.addCleanup(patcher.stop)
        return mocked

    def create_saby(self, order):
        order.saby_sale_id = 'test-sale'
        order.saby_order_number = 'test-number'
        order.save(update_fields=['saby_sale_id', 'saby_order_number'])
        return {'resultCode': 0}

    def test_paid_sbp_recovers_email_and_saby_only_once(self):
        self.assertEqual(reconcile_order_payment(self.order, apply=True), 'processed')
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.PAID)
        self.assertIsNotNone(self.order.paid_at)
        self.assertIsNotNone(self.order.admin_email_sent_at)
        self.assertTrue(self.order.saby_payment_registered)
        self.assertEqual(reconcile_order_payment(self.order, apply=True), 'skipped')
        self.send.assert_called_once()
        self.create.assert_called_once()
        self.register.assert_called_once()

    def test_default_command_only_checks_bank(self):
        output = StringIO()
        call_command('sync_alfa_payments', order_id=self.order.pk, stdout=output)
        self.assertIn('bank_paid', output.getvalue())
        self.order.refresh_from_db()
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.UNPAID)
        self.send.assert_not_called()
        self.create.assert_not_called()

    def test_apply_command_recovers_order(self):
        call_command('sync_alfa_payments', order_id=self.order.pk, apply=True, stdout=StringIO())
        self.order.refresh_from_db()
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.PAID)
        self.register.assert_called_once()

    def test_mismatch_or_refund_does_not_process_order(self):
        for change in (
            {'orderNumber': 'delycafe-other'},
            {'amount': 3900},
            {'currency': '840'},
            {'paymentAmountInfo': {'depositedAmount': 100, 'refundedAmount': 0}},
            {'paymentAmountInfo': {'depositedAmount': 3800, 'refundedAmount': 100}},
        ):
            with self.subTest(change=change):
                self.fetch.return_value = {**self.response, **change}
                with self.assertRaises(AlfaPaymentError):
                    reconcile_order_payment(self.order, apply=True)
        self.create.assert_not_called()
        self.send.assert_not_called()

    def test_bank_pending_and_unavailable_do_not_mark_paid(self):
        self.fetch.return_value = {**self.response, 'orderStatus': 0}
        self.assertEqual(reconcile_order_payment(self.order, apply=True), 'pending')
        self.fetch.return_value = None
        with self.assertRaises(AlfaPaymentError):
            reconcile_order_payment(self.order, apply=True)
        self.order.refresh_from_db()
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.UNPAID)
        self.create.assert_not_called()

    def make_stale(self):
        Order.objects.filter(pk=self.order.pk).update(
            created_at=timezone.now() - timedelta(hours=1),
        )

    def test_old_paid_order_is_reconciled_instead_of_expired(self):
        self.make_stale()
        with patch('payments.services._fetch_alfa_status_response', return_value=self.response):
            self.assertFalse(expire_stale_unpaid_order(self.order))
        self.order.refresh_from_db()
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.PAID)
        self.assertEqual(self.order.payment_external_id, 'test-bank-id')
        self.register.assert_called_once()

    def test_old_order_keeps_payment_id_when_bank_unavailable_or_pending(self):
        self.make_stale()
        for response in (None, {'orderStatus': 0}, {'orderStatus': 99}):
            with self.subTest(response=response):
                with patch('payments.services._fetch_alfa_status_response', return_value=response):
                    self.assertFalse(expire_stale_unpaid_order(self.order))
                self.order.refresh_from_db()
                self.assertEqual(self.order.payment_status, Order.PaymentStatus.UNPAID)
                self.assertEqual(self.order.payment_external_id, 'test-bank-id')

    def test_bank_confirmed_expiration_closes_old_order(self):
        self.make_stale()
        with patch('payments.services._fetch_alfa_status_response', return_value={'orderStatus': 6}):
            self.assertTrue(expire_stale_unpaid_order(self.order))
        self.order.refresh_from_db()
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.FAILED)
        self.create.assert_not_called()
