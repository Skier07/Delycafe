from django.test import TestCase

from customers.models import BonusTransaction, Customer
from orders.models import Order
from orders.serializers import OrderCreateSerializer
from orders.services import _record_bonus_earn


class BonusLedgerTests(TestCase):
    def setUp(self):
        self.customer = Customer.objects.create(
            phone='79000000001',
            bonus_balance=500,
        )

    def _create_order(self, *, bonus_spent):
        return OrderCreateSerializer().create(
            {
                'phone': self.customer.phone,
                'customer_name': 'Тест',
                'delivery_type': Order.DeliveryType.OZERSK,
                'address': 'Озёрск, тестовый адрес',
                'delivery_time_type': Order.DeliveryTimeType.ASAP,
                'payment_type': Order.PaymentType.CARD,
                'bonus_spent': bonus_spent,
                'items': [
                    {
                        'product_title': 'Тестовый товар',
                        'product_api_id': 'test-product',
                        'saby_id': 1,
                        'quantity': 1,
                        'price': 1000,
                    }
                ],
            }
        )

    def test_selected_bonuses_are_spent_and_earn_only_after_payment(self):
        order = self._create_order(bonus_spent=500)

        self.customer.refresh_from_db()
        self.assertEqual(order.bonus_spent, 250)
        self.assertEqual(order.bonus_earned, 22)
        self.assertEqual(self.customer.bonus_balance, 250)
        self.assertTrue(
            BonusTransaction.objects.filter(
                customer=self.customer,
                order_id=order.id,
                transaction_type=BonusTransaction.TransactionType.SPEND,
                amount=-250,
            ).exists()
        )

        _record_bonus_earn(order)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.bonus_balance, 250)

        order.payment_status = Order.PaymentStatus.PAID
        order.save(update_fields=['payment_status', 'updated_at'])
        _record_bonus_earn(order)
        _record_bonus_earn(order)

        self.customer.refresh_from_db()
        self.assertEqual(self.customer.bonus_balance, 272)
        self.assertEqual(
            BonusTransaction.objects.filter(
                customer=self.customer,
                order_id=order.id,
                transaction_type=BonusTransaction.TransactionType.EARN,
                amount=22,
            ).count(),
            1,
        )

    def test_bonuses_are_not_spent_when_customer_does_not_select_them(self):
        order = self._create_order(bonus_spent=0)

        self.customer.refresh_from_db()
        self.assertEqual(order.bonus_spent, 0)
        self.assertEqual(self.customer.bonus_balance, 500)
        self.assertFalse(
            BonusTransaction.objects.filter(
                customer=self.customer,
                order_id=order.id,
                transaction_type=BonusTransaction.TransactionType.SPEND,
            ).exists()
        )
