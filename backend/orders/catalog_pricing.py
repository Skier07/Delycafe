from __future__ import annotations

from rest_framework import serializers

from catalog.models import Product, ProductVariant


def _extract_product_pk(product_api_id: str) -> int | None:
    raw = str(product_api_id or '').strip()

    if not raw:
        return None

    if raw.isdigit():
        return int(raw)

    if raw.startswith('api_'):
        suffix = raw[4:]

        if suffix.isdigit():
            return int(suffix)

    return None


def _extract_saby_id(item_data: dict) -> int | None:
    saby_id = item_data.get('saby_id')

    if saby_id is not None:
        return int(saby_id)

    product_api_id = str(item_data.get('product_api_id') or '').strip()

    if product_api_id.startswith('saby_'):
        suffix = product_api_id[5:]

        if suffix.isdigit():
            return int(suffix)

    return None


def _resolve_item(item_data):
    """Resolve identity and price together; never fall back from an unknown Saby ID."""
    def invalid():
        raise serializers.ValidationError({'items': 'Товар или размер недоступен. Обновите каталог.'})

    try:
        saby_id = _extract_saby_id(item_data)
    except (TypeError, ValueError):
        invalid()
    pk = _extract_product_pk(item_data.get('product_api_id'))
    product = variant = None
    if saby_id:
        variant = ProductVariant.objects.select_related('product__category').filter(
            saby_id=saby_id, is_active=True).first()
        product = variant.product if variant else Product.objects.select_related('category').filter(saby_id=saby_id).first()
        if product is None or (pk is not None and product.pk != pk):
            invalid()
    elif pk is not None:
        product = Product.objects.select_related('category').filter(pk=pk).first()
    if (product is None or not product.is_active
            or not product.category.is_active or not product.category.show_in_app):
        invalid()
    title = str(item_data.get('variant_title') or '').strip()
    if product.has_variants:
        if variant is None:
            variant = product.variants.filter(title=title, is_active=True).first()
        if variant is None or (title and title != variant.title):
            invalid()
    elif variant is not None or title:
        invalid()
    selected = variant or product
    if not selected.saby_id:
        invalid()
    return product, variant, selected


def resolve_catalog_product(item_data: dict) -> Product | None:
    return _resolve_item(item_data)[0]


def resolve_catalog_unit_price(item_data: dict) -> int:
    return int(_resolve_item(item_data)[2].price)


def apply_validated_item_prices(items_data: list[dict]) -> list[dict]:
    result = []
    for item in items_data:
        product, variant, selected = _resolve_item(item)
        result.append({**item, 'price': int(selected.price),
                       'product_api_id': f'api_{product.pk}',
                       'product_title': product.title,
                       'variant_title': variant.title if variant else '',
                       'saby_id': selected.saby_id})
    return result
