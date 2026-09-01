from django.test import TestCase

from catalog.management.commands.sync_saby_prices import Command
from catalog.models import Category, Product, ProductVariant


class SyncSabyPricesTests(TestCase):
    def setUp(self):
        self.category = Category.objects.create(
            title='Блин',
            slug='blin',
            show_in_app=True,
        )
        self.other_category = Category.objects.create(
            title='Без категории',
            slug='bez-kategorii',
        )
        self.command = Command()

    def test_updates_simple_product_price_and_keeps_category(self):
        product = Product.objects.create(
            category=self.category,
            saby_id=23,
            title='Блин с грибами',
            description='Старое описание',
            price=150,
            is_active=True,
        )

        self.command.apply_prices({23: 180})

        product.refresh_from_db()
        self.assertEqual(product.price, 180)
        self.assertEqual(product.category_id, self.category.id)
        self.assertEqual(product.title, 'Блин с грибами')
        self.assertEqual(product.description, 'Старое описание')
        self.assertTrue(product.is_active)

    def test_updates_anonymous_single_variant_on_simple_product(self):
        product = Product.objects.create(
            category=self.category,
            saby_id=23,
            title='Блин с грибами',
            price=150,
            has_variants=False,
        )
        variant = ProductVariant.objects.create(
            product=product,
            title='Обычный',
            price=150,
        )

        self.command.apply_prices({23: 180})

        product.refresh_from_db()
        variant.refresh_from_db()
        self.assertEqual(product.price, 180)
        self.assertEqual(variant.price, 180)

    def test_updates_each_variant_by_own_saby_id(self):
        pizza = Product.objects.create(
            category=self.category,
            title='Пицца Маргарита',
            price=590,
            has_variants=True,
            is_active=True,
        )
        small = ProductVariant.objects.create(
            product=pizza,
            saby_id=10,
            title='Маленькая',
            price=450,
        )
        medium = ProductVariant.objects.create(
            product=pizza,
            saby_id=11,
            title='Средняя',
            price=590,
        )

        self.command.apply_prices({10: 470, 11: 620})

        pizza.refresh_from_db()
        small.refresh_from_db()
        medium.refresh_from_db()
        self.assertEqual(small.price, 470)
        self.assertEqual(medium.price, 620)
        self.assertEqual(pizza.price, 470)
        self.assertEqual(pizza.category_id, self.category.id)
        self.assertEqual(pizza.title, 'Пицца Маргарита')

    def test_does_not_copy_one_size_price_onto_has_variants_product(self):
        pizza = Product.objects.create(
            category=self.category,
            saby_id=11,
            title='Пицца Маргарита',
            price=450,
            has_variants=True,
        )
        ProductVariant.objects.create(
            product=pizza,
            saby_id=10,
            title='Маленькая',
            price=450,
        )
        ProductVariant.objects.create(
            product=pizza,
            saby_id=11,
            title='Средняя',
            price=590,
        )

        self.command.apply_prices({11: 620})

        pizza.refresh_from_db()
        self.assertEqual(pizza.price, 450)
        self.assertEqual(pizza.variants.get(saby_id=10).price, 450)
        self.assertEqual(pizza.variants.get(saby_id=11).price, 620)

    def test_collect_prices_skips_parents_and_empty_cost(self):
        prices = self.command._collect_prices(
            [
                {'isParent': True, 'id': None, 'cost': None, 'name': 'Блины'},
                {'isParent': False, 'id': 23, 'cost': 180.0},
                {'isParent': False, 'id': 24, 'cost': None},
                {'isParent': False, 'id': 25, 'cost': 0},
            ]
        )

        self.assertEqual(prices, {23: 180})
