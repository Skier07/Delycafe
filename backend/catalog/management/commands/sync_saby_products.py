from django.core.management.base import BaseCommand
from django.db import transaction

from catalog.models import Category, Product
from catalog.services.saby_catalog_service import (
    SabyCatalogService,
)


class Command(BaseCommand):
    help = 'Синхронизация каталога Saby'

    MIN_PRODUCTS_LIMIT = 50

    def handle(self, *args, **options):
        self.stdout.write(
            self.style.SUCCESS(
                '=== Синхронизация каталога Saby ==='
            )
        )

        service = SabyCatalogService()

        try:
            catalog = service.sync_catalog()

        except Exception as exc:
            self.stdout.write(
                self.style.ERROR(
                    f'Ошибка получения каталога: {exc}'
                )
            )
            return

        if not catalog:
            self.stdout.write(
                self.style.ERROR(
                    'Каталог пустой'
                )
            )
            return

        products = catalog.get('nomenclatures', [])

        if len(products) < self.MIN_PRODUCTS_LIMIT:
            self.stdout.write(
                self.style.ERROR(
                    f'Получено слишком мало товаров: {len(products)}'
                )
            )
            return

        self.stdout.write(
            self.style.SUCCESS(
                f'Получено товаров: {len(products)}'
            )
        )

        self.sync_products(catalog)

    @transaction.atomic
    def sync_products(self, catalog):

        products = catalog.get(
            'nomenclatures',
            [],
        )

        service = SabyCatalogService()

        actual_saby_ids = set()

        created_count = 0
        updated_count = 0

        categories_map = {}

    #
    # Сначала синхронизируем категории
    #
        for item in products:

            if not item.get('isParent'):
                continue

            category = service.get_or_create_category(
                category_id=item.get('id'),
                category_name=item.get('name'),
            )

            categories_map[item.get('id')] = category

    #
    # Затем синхронизируем товары
    #
        for item in products:

            if item.get('isParent'):
                continue

            saby_id = item.get('id')

            if not saby_id:
                continue

            actual_saby_ids.add(saby_id)

            title = (item.get('name') or '').strip()

            if not title:
                continue

            parent_id = item.get('hierarchicalParent')

            category = categories_map.get(parent_id)

            if category and not category.show_in_app:
                continue


            if category is None:
                category = Category.objects.filter(
                    title='Без категории'
                ).first()

                if category is None:
                    category = Category.objects.create(
                        title='Без категории',
                        slug='bez-kategorii',
                        is_active=True,
                    )

            product = Product.objects.filter(
                saby_id=saby_id
            ).first()

            defaults = {
                'title': title,
                'saby_name': title,
                'description': item.get('description') or '',
                'price': int(float(item.get('cost') or 0)),
                'source': Product.Source.SABY,
            }

            if not product or not product.manual_category:
                defaults['category'] = category

            product, created = Product.objects.update_or_create(
                saby_id=saby_id,
                defaults=defaults,
            )

            if created:
                product.needs_review = True
                product.is_active = False

                product.save(
                    update_fields=[
                        'needs_review',
                        'is_active',
                    ]
                )

                created_count += 1

            else:
                updated_count += 1

        disabled_count = (
            Product.objects
            .filter(source=Product.Source.SABY)
            .exclude(saby_id__in=actual_saby_ids)
            .update(is_active=False)
        )

        self.stdout.write(
            self.style.SUCCESS(
                f'Создано: {created_count}'
            )
        )

        self.stdout.write(
            self.style.SUCCESS(
                f'Обновлено: {updated_count}'
            )
        )

        self.stdout.write(
            self.style.WARNING(
                f'Отключено: {disabled_count}'
            )
        )
