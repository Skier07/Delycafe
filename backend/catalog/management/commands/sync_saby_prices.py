from django.core.management.base import BaseCommand
from django.db import transaction

from catalog.models import Product, ProductVariant
from catalog.services.saby_catalog_service import SabyCatalogService


class Command(BaseCommand):
    help = (
        'Обновляет только цены из Saby. '
        'Не меняет категории, названия, описания и активность.'
    )

    MIN_PRODUCTS_LIMIT = 50

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('=== Обновление цен из Saby ==='))

        try:
            catalog = SabyCatalogService().get_catalog()
        except Exception as exc:
            self.stdout.write(self.style.ERROR(f'Ошибка получения каталога: {exc}'))
            return

        if not isinstance(catalog, dict):
            self.stdout.write(self.style.ERROR('Каталог пустой или неверный ответ Saby'))
            return

        items = catalog.get('nomenclatures') or []
        prices = self._collect_prices(items)

        if len(prices) < self.MIN_PRODUCTS_LIMIT:
            self.stdout.write(
                self.style.ERROR(
                    f'Слишком мало позиций с ценой: {len(prices)}. Цены не менялись.'
                )
            )
            return

        self.stdout.write(self.style.SUCCESS(f'Цен в ответе Saby: {len(prices)}'))
        stats = self.apply_prices(prices)

        self.stdout.write(self.style.SUCCESS(f'Товаров без вариантов: {stats["products"]}'))
        self.stdout.write(self.style.SUCCESS(f'Вариантов: {stats["variants"]}'))
        self.stdout.write(
            self.style.SUCCESS(
                f'Карточек с вариантами (мин. цена): {stats["variant_products"]}'
            )
        )
        self.stdout.write(self.style.WARNING(f'Не найдено в Django: {stats["missing"]}'))

    def _collect_prices(self, items):
        prices = {}

        for item in items:
            if item.get('isParent'):
                continue

            saby_id = self._parse_saby_id(item.get('id'))
            price = self._parse_price(item.get('cost'))

            if saby_id is None or price is None:
                continue

            prices[saby_id] = price

        return prices

    @transaction.atomic
    def apply_prices(self, prices):
        stats = {
            'products': 0,
            'variants': 0,
            'variant_products': 0,
            'missing': 0,
        }

        if not prices:
            return stats

        seen_ids = set()
        touched_variant_product_ids = set()

        variants = list(
            ProductVariant.objects.filter(saby_id__in=prices.keys()).select_related(
                'product',
            )
        )

        for variant in variants:
            seen_ids.add(variant.saby_id)
            new_price = prices[variant.saby_id]

            if variant.price == new_price:
                continue

            variant.price = new_price
            variant.save(update_fields=['price'])
            stats['variants'] += 1

            if variant.product.has_variants:
                touched_variant_product_ids.add(variant.product_id)

        products = list(
            Product.objects.filter(saby_id__in=prices.keys()).prefetch_related(
                'variants',
            )
        )

        for product in products:
            seen_ids.add(product.saby_id)
            new_price = prices[product.saby_id]

            if product.has_variants:
                continue

            if product.price != new_price:
                product.price = new_price
                product.save(update_fields=['price'])
                stats['products'] += 1

            self._sync_single_anonymous_variant(product, new_price, stats)

        for product in Product.objects.filter(
            id__in=touched_variant_product_ids,
            has_variants=True,
        ).prefetch_related('variants'):
            active_prices = [
                variant.price
                for variant in product.variants.all()
                if variant.is_active
            ]

            if not active_prices:
                continue

            min_price = min(active_prices)

            if product.price != min_price:
                product.price = min_price
                product.save(update_fields=['price'])
                stats['variant_products'] += 1

        stats['missing'] = len(set(prices) - seen_ids)
        return stats

    def _sync_single_anonymous_variant(self, product, new_price, stats):
        variants = [
            variant
            for variant in product.variants.all()
            if variant.is_active
        ]

        if len(variants) != 1:
            return

        variant = variants[0]

        if variant.saby_id not in (None, product.saby_id):
            return

        if variant.price == new_price:
            return

        variant.price = new_price
        variant.save(update_fields=['price'])
        stats['variants'] += 1

    @staticmethod
    def _parse_saby_id(value):
        if value is None or value == '':
            return None

        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _parse_price(value):
        if value is None or value == '':
            return None

        try:
            price = int(float(value))
        except (TypeError, ValueError):
            return None

        if price <= 0:
            return None

        return price
