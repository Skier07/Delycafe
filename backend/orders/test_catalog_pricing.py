from django.test import TestCase
from rest_framework import serializers

from catalog.models import Category, Product, ProductVariant
from orders.catalog_pricing import (
    _extract_product_pk,
    _extract_saby_id,
    apply_validated_item_prices,
    resolve_catalog_unit_price,
)


class CatalogPricingHelpersTests(TestCase):
    def test_extract_product_pk_supports_api_prefix(self):
        self.assertEqual(_extract_product_pk('api_42'), 42)
        self.assertEqual(_extract_product_pk('42'), 42)
        self.assertIsNone(_extract_product_pk('saby_23'))

    def test_extract_saby_id_from_field_and_prefix(self):
        self.assertEqual(_extract_saby_id({'saby_id': 15}), 15)
        self.assertEqual(
            _extract_saby_id({'product_api_id': 'saby_23'}),
            23,
        )


class CatalogPricingResolveTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.category = Category.objects.create(
            title='Блины',
            slug='bliny',
            show_in_app=True,
        )

        cls.product = Product.objects.create(
            category=cls.category,
            saby_id=1001,
            title='Блин с сыром',
            price=150,
            show_in_app=True,
            is_active=True,
        )

        cls.pizza = Product.objects.create(
            category=cls.category,
            title='Пицца Маргарита',
            price=0,
            has_variants=True,
            show_in_app=True,
            is_active=True,
        )

        cls.medium = ProductVariant.objects.create(
            product=cls.pizza,
            saby_id=2002,
            title='Средняя',
            price=590,
            is_active=True,
        )

    def test_resolve_by_saby_id(self):
        price = resolve_catalog_unit_price(
            {
                'product_title': self.product.title,
                'saby_id': self.product.saby_id,
                'product_api_id': 'api_999',
                'price': 999,
            },
        )

        self.assertEqual(price, 150)

    def test_resolve_by_api_prefixed_product_id(self):
        price = resolve_catalog_unit_price(
            {
                'product_title': self.product.title,
                'product_api_id': f'api_{self.product.pk}',
                'price': 999,
            },
        )

        self.assertEqual(price, 150)

    def test_resolve_variant_by_saby_id(self):
        price = resolve_catalog_unit_price(
            {
                'product_title': self.pizza.title,
                'variant_title': self.medium.title,
                'saby_id': self.medium.saby_id,
                'product_api_id': f'api_{self.pizza.pk}',
                'price': 999,
            },
        )

        self.assertEqual(price, 590)

    def test_apply_validated_item_prices_uses_server_price(self):
        validated = apply_validated_item_prices(
            [
                {
                    'product_title': self.product.title,
                    'variant_title': '',
                    'product_api_id': f'api_{self.product.pk}',
                    'saby_id': self.product.saby_id,
                    'quantity': 2,
                    'price': 120,
                },
            ],
        )

        self.assertEqual(validated[0]['price'], 150)

    def test_unknown_product_raises_validation_error(self):
        with self.assertRaises(serializers.ValidationError):
            resolve_catalog_unit_price(
                {
                    'product_title': 'Неизвестный товар',
                    'product_api_id': 'api_999999',
                    'price': 100,
                },
            )
