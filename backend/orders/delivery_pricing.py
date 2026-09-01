from functools import lru_cache

from .models import DeliveryZone

PICKUP_CODE = 'pickup'


def clear_delivery_zone_cache():
    _get_active_delivery_zone.cache_clear()


@lru_cache(maxsize=64)
def _get_active_delivery_zone(code: str) -> DeliveryZone | None:
    if not code:
        return None

    return (
        DeliveryZone.objects.filter(code=code, is_active=True)
        .prefetch_related('price_tiers')
        .first()
    )


def get_active_delivery_zone(code: str) -> DeliveryZone | None:
    return _get_active_delivery_zone(code)


def delivery_zone_exists(code: str) -> bool:
    return get_active_delivery_zone(code) is not None


def delivery_requires_address(code: str) -> bool:
    zone = get_active_delivery_zone(code)
    if zone is not None:
        return zone.requires_address

    return code != PICKUP_CODE


def is_pickup_delivery(code: str) -> bool:
    return code == PICKUP_CODE


def get_default_locality(code: str) -> str:
    zone = get_active_delivery_zone(code)
    if zone is not None:
        return zone.default_locality

    return ''


def get_delivery_zone_title(code: str) -> str:
    zone = get_active_delivery_zone(code)
    if zone is not None:
        return zone.title

    return code


def lead_minutes_for_delivery(code: str) -> int:
    zone = get_active_delivery_zone(code)
    if zone is not None:
        return zone.lead_minutes

    if code == 'tatysh':
        return 120

    return 90


def calculate_delivery_price(delivery_type: str, products_total: int) -> int:
    zone = get_active_delivery_zone(delivery_type)
    if zone is None:
        return 0

    if zone.pricing_mode == DeliveryZone.PricingMode.FREE:
        return 0

    if zone.pricing_mode == DeliveryZone.PricingMode.FIXED:
        return zone.fixed_price

    tiers = sorted(
        zone.price_tiers.all(),
        key=lambda tier: tier.min_cart_total,
        reverse=True,
    )

    for tier in tiers:
        if products_total >= tier.min_cart_total:
            return tier.price

    return 0
