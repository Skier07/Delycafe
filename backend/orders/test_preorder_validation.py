from datetime import datetime, time
from unittest.mock import patch
from zoneinfo import ZoneInfo

from django.test import TestCase
from django.utils import timezone
from rest_framework import serializers

from catalog.models import Category, Product
from orders.serializers import OrderCreateSerializer


class OrderPreorderValidationTests(TestCase):
    def setUp(self):
        self.pies = Category.objects.create(
            title='Пироги',
            slug='pirogi',
            show_in_app=True,
            preorder_cutoff_enabled=True,
            preorder_lead_days=1,
            preorder_cutoff_time=time(17, 0),
        )
        self.pizza_category = Category.objects.create(
            title='Пицца',
            slug='pizza',
            show_in_app=True,
        )
        self.pie = Product.objects.create(
            category=self.pies,
            saby_id=501,
            title='Пирог с капустой',
            price=450,
            is_active=True,
        )
        self.pizza = Product.objects.create(
            category=self.pizza_category,
            saby_id=502,
            title='Пицца Маргарита',
            price=590,
            is_active=True,
        )
        self.tz = ZoneInfo('Asia/Yekaterinburg')
        self.at_18 = timezone.make_aware(datetime(2026, 9, 1, 18, 0), self.tz)

    def _order_payload(self, products):
        return {
            'phone': '+79001234567',
            'delivery_type': 'pickup',
            'delivery_time_type': 'asap',
            'items': [
                {
                    'product_title': product.title,
                    'variant_title': '',
                    'product_api_id': f'api_{product.pk}',
                    'saby_id': product.saby_id,
                    'quantity': 1,
                    'price': product.price,
                }
                for product in products
            ],
        }

    @patch('django.utils.timezone.now')
    def test_rejects_mixed_order_with_pie_after_cutoff(self, mock_now):
        mock_now.return_value = self.at_18
        serializer = OrderCreateSerializer()

        with self.assertRaises(serializers.ValidationError):
            serializer.validate(self._order_payload([self.pie, self.pizza]))

    @patch('django.utils.timezone.now')
    def test_allows_pizza_only_after_cutoff(self, mock_now):
        mock_now.return_value = self.at_18
        serializer = OrderCreateSerializer()

        validated = serializer.validate(self._order_payload([self.pizza]))

        self.assertEqual(len(validated['items']), 1)

    @patch('django.utils.timezone.now')
    def test_allows_pie_when_cutoff_disabled(self, mock_now):
        self.pies.preorder_cutoff_enabled = False
        self.pies.save(update_fields=['preorder_cutoff_enabled'])
        mock_now.return_value = self.at_18
        serializer = OrderCreateSerializer()

        validated = serializer.validate(self._order_payload([self.pie, self.pizza]))

        self.assertEqual(len(validated['items']), 2)
