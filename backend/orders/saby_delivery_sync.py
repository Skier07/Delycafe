"""Read-only Saby API access; update local tariffs as one validated transaction."""
from decimal import Decimal, InvalidOperation

import requests
from django.conf import settings
from django.db import transaction, connection
from contextlib import contextmanager
from threading import Lock

from catalog.services.saby_catalog_service import SabyCatalogService
from .models import DeliveryPriceTier, DeliveryZone


class DeliverySyncError(Exception):
    pass


_local_sync_lock = Lock()


@contextmanager
def _sync_lock():
    # Separate from tariff rows: readers are never locked behind HTTP calls.
    if connection.vendor == "postgresql":
        with connection.cursor() as cursor:
            cursor.execute("SELECT pg_try_advisory_lock(%s)", [741840197])
            acquired = cursor.fetchone()[0]
        if not acquired:
            raise DeliverySyncError("Тарифы уже обновляются. Повторите запрос.")
        try:
            yield
        finally:
            with connection.cursor() as cursor:
                cursor.execute("SELECT pg_advisory_unlock(%s)", [741840197])
    else:
        # SQLite is used only by local tests. Production uses PostgreSQL.
        if not _local_sync_lock.acquire(blocking=False):
            raise DeliverySyncError("Тарифы уже обновляются. Повторите запрос.")
        try:
            yield
        finally:
            _local_sync_lock.release()

def whole_rubles(value, field):
    if isinstance(value, bool) or value is None:
        raise DeliverySyncError(f'Некорректное поле Saby: {field}.')
    try:
        number = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise DeliverySyncError(f'Некорректное поле Saby: {field}.') from None
    if not number.is_finite() or number < 0 or number != number.to_integral_value() or number > 2147483647:
        raise DeliverySyncError(f'{field}: нужны неотрицательные целые рубли, без округления.')
    return int(number)


def parse_tariff(district):
    # A nonempty threshold list is authoritative. Do not infer missing tiers from cost.
    rows = district.get('sumThresholds')
    if rows is not None and not isinstance(rows, list):
        raise DeliverySyncError('Неверный формат sumThresholds.')
    if rows:
        tiers = []
        for row in rows:
            if not isinstance(row, dict):
                raise DeliverySyncError('Неверный формат строки тарифа.')
            tiers.append((whole_rubles(row.get('From'), 'From'),
                          whole_rubles(row.get('Price'), 'Price')))
        tiers.sort()
        if len({start for start, _ in tiers}) != len(tiers):
            raise DeliverySyncError('Повторяющиеся пороги доставки Saby.')
        # Preserve the first threshold (including 50 ₽); never invent a free tier below it.
        return tiers
    cost = whole_rubles(district.get('cost'), 'cost')
    free_from = district.get('costForFreeDelivery')
    tiers = [(0, cost)]
    if free_from is not None:
        free_from = whole_rubles(free_from, 'costForFreeDelivery')
        if free_from > 0 and cost > 0:
            tiers.append((free_from, 0))
    return tiers


def fetch_districts():
    try:
        token = SabyCatalogService().get_token()
        if not isinstance(token, str) or not token:
            raise DeliverySyncError('Saby не вернул токен доступа.')
        response = requests.get(
            'https://api.sbis.ru/retail/district/list',
            headers={'X-SBISAccessToken': token},
            params={'pointId': settings.SABY_POINT_ID, 'withCoordinates': 'false'},
            timeout=20,
        )
        response.raise_for_status()
        data = response.json()
    except (requests.RequestException, ValueError):
        raise DeliverySyncError('Не удалось получить тарифы доставки Saby.') from None
    if not isinstance(data, dict) or not isinstance(data.get('districts'), list):
        raise DeliverySyncError('Saby вернул неверный список районов.')
    outcome = data.get('outcome')
    if not isinstance(outcome, dict) or outcome.get('hasMore') is not False:
        raise DeliverySyncError('Saby вернул неполный список районов; тарифы не изменены.')
    districts = {}
    for district in data['districts']:
        if not isinstance(district, dict) or type(district.get('districtId')) is not int:
            raise DeliverySyncError('В ответе Saby нет корректного districtId.')
        key = district['districtId']
        if key in districts:
            raise DeliverySyncError('В ответе Saby повторяется districtId.')
        districts[key] = district
    return districts


def sync_delivery_tariffs(*, dry_run=False):
    with _sync_lock():
        districts = fetch_districts()
        return _apply_tariffs(districts, dry_run=dry_run)


@transaction.atomic
def _apply_tariffs(districts, *, dry_run=False):
    mapping = settings.SABY_DELIVERY_DISTRICT_IDS
    if not mapping or any(type(value) is not int or value <= 0 for value in mapping.values()):
        raise DeliverySyncError('Не настроены SABY_DELIVERY_DISTRICT_IDS.')
    if 'pickup' in mapping or len(set(mapping.values())) != len(mapping):
        raise DeliverySyncError('Районы доставки должны быть уникальными и не включать самовывоз.')
    # Only validation and writes hold tariff row locks.
    zones = list(DeliveryZone.objects.select_for_update().filter(code__in=mapping).order_by('pk'))
    if {zone.code for zone in zones} != set(mapping):
        raise DeliverySyncError('Не все настроенные зоны существуют в базе.')
    plans = []
    for zone in zones:
        district = districts.get(mapping[zone.code])
        if district is None:
            raise DeliverySyncError(f'В Saby отсутствует район для зоны {zone.code}.')
        tiers = parse_tariff(district)
        mode = 'tiered'
        fixed = 0
        if len(tiers) == 1 and tiers[0][0] == 0:
            fixed = tiers[0][1]
            mode = 'free' if fixed == 0 else 'fixed'
        plans.append((zone, mode, fixed, tiers if mode == 'tiered' else []))

    result = []
    for zone, mode, fixed, tiers in plans:
        existing = sorted(zone.price_tiers.values_list('min_cart_total', 'price'))
        changed = (zone.pricing_mode, zone.fixed_price, existing) != (mode, fixed, tiers)
        result.append({'zone': zone.code, 'district': mapping[zone.code],
                       'mode': mode, 'fixed_price': fixed, 'tiers': tiers, 'changed': changed})
        if changed and not dry_run:
            zone.pricing_mode, zone.fixed_price = mode, fixed
            zone.save(update_fields=['pricing_mode', 'fixed_price'])
            zone.price_tiers.all().delete()
            DeliveryPriceTier.objects.bulk_create([
                DeliveryPriceTier(zone=zone, min_cart_total=start, price=price, sort_order=index)
                for index, (start, price) in enumerate(tiers)
            ])
    return result
