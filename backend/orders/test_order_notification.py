from django.test import TestCase, override_settings

from catalog.models import Category, Product
from orders.models import Order, OrderItem
from orders.order_notification_service import (
    _should_send_admin_email,
    try_send_admin_order_email,
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
            product=self.product,
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
