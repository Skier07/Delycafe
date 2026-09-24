from unittest.mock import patch

from django.test import TestCase, override_settings

from catalog.models import Category, Product
from orders.models import Order, OrderItem
from orders.services import confirm_order_paid
from orders.order_notification_service import (
    _should_send_admin_email,
    try_send_admin_order_email,
)


@override_settings(
    ORDER_ADMIN_EMAIL_ENABLED=True,
    ORDER_ADMIN_EMAIL='admin@example.com',
    EMAIL_HOST_USER='smtp@example.com',
    EMAIL_HOST_PASSWORD='test-password',
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
)
class AdminOrderEmailTests(TestCase):
    def setUp(self):
        self.category = Category.objects.create(
            title='Соусы',
            slug='sousy',
        )
        self.product = Product.objects.create(
            category=self.category,
            title='Соус барбекю',
            price=40,
            saby_id=525,
        )
        self.order = Order.objects.create(
            customer_name='Тест',
            phone='79001234567',
            delivery_type=Order.DeliveryType.PICKUP,
            payment_type=Order.PaymentType.CARD,
            payment_status=Order.PaymentStatus.PAID,
            status=Order.Status.ACCEPTED,
            total_price=40,
            payment_amount=40,
        )
        OrderItem.objects.create(
            order=self.order,
            product_title=self.product.title,
            quantity=1,
            price=40,
            total_price=40,
            saby_id=self.product.saby_id,
        )

    def test_should_send_without_saby_number(self):
        self.assertEqual(self.order.saby_order_number, '')
        self.assertEqual(self.order.saby_sale_id, '')
        self.assertTrue(_should_send_admin_email(self.order))

    def test_should_not_resend_after_sent(self):
        self.order.admin_email_sent_at = self.order.created_at
        self.order.save(update_fields=['admin_email_sent_at'])
        self.assertFalse(_should_send_admin_email(self.order))

    @override_settings(
        ORDER_ADMIN_EMAIL_ENABLED=True,
        ORDER_ADMIN_EMAIL='admin@example.com',
        EMAIL_HOST_USER='smtp@example.com',
        EMAIL_HOST_PASSWORD='secret',
        EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    )
    def test_send_paid_order_without_saby(self):
        sent = try_send_admin_order_email(self.order.id)
        self.assertTrue(sent)

        self.order.refresh_from_db()
        self.assertIsNotNone(self.order.admin_email_sent_at)

    def test_zero_messages_does_not_mark_email_sent(self):
        with patch('orders.order_notification_service.send_mail', return_value=0):
            self.assertFalse(try_send_admin_order_email(self.order.id))
        self.order.refresh_from_db()
        self.assertIsNone(self.order.admin_email_sent_at)

    def test_smtp_timeout_does_not_prevent_saby_dispatch(self):
        with (
            patch(
                'orders.order_notification_service.send_mail',
                side_effect=TimeoutError('SMTP timed out'),
            ),
            patch('orders.services._dispatch_order_to_saby_core') as dispatch,
        ):
            confirm_order_paid(self.order)
        dispatch.assert_called_once()
        self.order.refresh_from_db()
        self.assertEqual(self.order.payment_status, Order.PaymentStatus.PAID)
        self.assertIsNone(self.order.admin_email_sent_at)

    def test_unpaid_order_does_not_send_email(self):
        self.order.payment_status = Order.PaymentStatus.UNPAID
        self.order.save(update_fields=['payment_status'])
        with patch('orders.order_notification_service.send_mail') as send:
            self.assertFalse(try_send_admin_order_email(self.order.id))
        send.assert_not_called()
