from __future__ import annotations

from rest_framework import serializers

from catalog.models import Product, ProductVariant


def resolve_catalog_unit_price(item_data: dict) -> int:
    saby_id = item_data.get('saby_id')

    if saby_id:
        variant = (
            ProductVariant.objects.filter(
                saby_id=saby_id,
                is_active=True,
                product__is_active=True,
                product__show_in_app=True,
            )
            .select_related('product')
            .first()
        )

        if variant is not None:
            return int(variant.price)

        product = Product.objects.filter(
            saby_id=saby_id,
            is_active=True,
            show_in_app=True,
        ).first()

        if product is not None and not product.has_variants:
            return int(product.price)

    product_api_id = str(item_data.get('product_api_id') or '').strip()

    if product_api_id.isdigit():
        product = Product.objects.filter(
            pk=int(product_api_id),
            is_active=True,
            show_in_app=True,
        ).first()

        if product is not None:
            variant_title = str(item_data.get('variant_title') or '').strip()

            if variant_title and product.has_variants:
                variant = product.variants.filter(
                    title=variant_title,
                    is_active=True,
                ).first()

                if variant is not None:
                    return int(variant.price)

            if not product.has_variants:
                return int(product.price)

    title = str(item_data.get('product_title') or '').strip()
    raise serializers.ValidationError(
        {
            'items': (
                f'Не удалось проверить цену для позиции «{title}». '
                'Обновите каталог в приложении.'
            ),
        },
    )


def apply_validated_item_prices(items_data: list[dict]) -> list[dict]:
    validated_items: list[dict] = []

    for item_data in items_data:
        server_price = resolve_catalog_unit_price(item_data)
        client_price = int(item_data['price'])

        if client_price != server_price:
            title = str(item_data.get('product_title') or 'товар')
            raise serializers.ValidationError(
                {
                    'items': (
                        f'Цена для «{title}» устарела. '
                        f'Актуальная цена: {server_price} ₽.'
                    ),
                },
            )

        validated_item = dict(item_data)
        validated_item['price'] = server_price
        validated_items.append(validated_item)

    return validated_items
