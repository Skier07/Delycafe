"""Render tariff placeholders for both current and older app releases."""
import re

from .delivery_pricing import native_delivery_pricing

TOKEN = re.compile(r'\{\{delivery_tariff:([a-z0-9_-]+)\}\}')


def tariff_text(zone):
    if zone.pricing_mode == 'free':
        return 'Доставка бесплатно.'
    if zone.pricing_mode == 'fixed':
        return f'Стоимость доставки: {zone.fixed_price} ₽.'
    tiers = sorted(zone.price_tiers.all(), key=lambda tier: tier.min_cart_total)
    lines = []
    for index, tier in enumerate(tiers):
        following = tiers[index + 1] if index + 1 < len(tiers) else None
        if following:
            interval = (f'До {following.min_cart_total} ₽' if tier.min_cart_total == 0
                        else f'От {tier.min_cart_total} до {following.min_cart_total - 1} ₽')
        else:
            interval = f'От {tier.min_cart_total} ₽'
        price = 'бесплатно' if tier.price == 0 else f'{tier.price} ₽'
        lines.append(f'{interval} — {price}.')
    if native_delivery_pricing() and tiers:
        lines.append('Сумма товаров учитывается после скидок и списания бонусов.')
    return '\n'.join(lines)


def render_delivery_text(text, zones):
    def replace(match):
        zone = zones.get(match.group(1))
        return tariff_text(zone) if zone else 'Условия доставки уточняются.'
    return TOKEN.sub(replace, text)
