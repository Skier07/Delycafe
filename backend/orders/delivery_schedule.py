from datetime import date, datetime, time, timedelta

from django.utils import timezone

from orders.models import Order

OPEN_TIME = time(10, 0)
# Вс–чт: приём заказов до 20:30, пт–сб: до 21:30.
SLOT_SUNDAY_THROUGH_THURSDAY = time(20, 30)
SLOT_FRIDAY_SATURDAY = time(21, 30)
LEAD_DEFAULT = timedelta(hours=1, minutes=30)
LEAD_TATYSH = timedelta(hours=2)
SLOT_INTERVAL = timedelta(minutes=5)


def lead_for_delivery_type(delivery_type: str) -> timedelta:
    if delivery_type == Order.DeliveryType.TATYSH:
        return LEAD_TATYSH

    return LEAD_DEFAULT


def last_slot_for_date(day: date) -> time:
    # Python weekday: пн=0 … вс=6. Пт=4, сб=5 — до 21:30, вс–чт — до 20:30.
    if day.weekday() in (4, 5):
        return SLOT_FRIDAY_SATURDAY

    return SLOT_SUNDAY_THROUGH_THURSDAY


def combine_local(day: date, value: time) -> datetime:
    return timezone.make_aware(datetime.combine(day, value))


def _round_up_to_interval(value: datetime, interval_minutes: int = 5) -> datetime:
    local_value = timezone.localtime(value)
    total_minutes = local_value.hour * 60 + local_value.minute
    remainder = total_minutes % interval_minutes

    if remainder == 0 and local_value.second == 0 and local_value.microsecond == 0:
        return local_value.replace(second=0, microsecond=0)

    rounded_minutes = total_minutes + (interval_minutes - remainder)

    base = local_value.replace(hour=0, minute=0, second=0, microsecond=0)
    return base + timedelta(minutes=rounded_minutes)


def min_delivery_datetime(now: datetime, delivery_type: str) -> datetime:
    local_now = timezone.localtime(now)
    today = local_now.date()
    open_dt = combine_local(today, OPEN_TIME)
    earliest = local_now + lead_for_delivery_type(delivery_type)

    if earliest < open_dt:
        return open_dt

    return earliest


def max_delivery_datetime(now: datetime) -> datetime:
    local_now = timezone.localtime(now)
    today = local_now.date()

    return combine_local(today, last_slot_for_date(today))


def is_kitchen_closed(now: datetime) -> bool:
    local_now = timezone.localtime(now)
    today = local_now.date()
    open_dt = combine_local(today, OPEN_TIME)
    close_dt = combine_local(today, last_slot_for_date(today))

    if local_now < open_dt:
        return True

    return local_now >= close_dt


def is_ordering_open(now: datetime, delivery_type: str) -> bool:
    """Приём заказов открыт по расписанию кухни (без учёта lead time)."""
    return not is_kitchen_closed(now)


def has_delivery_slots_today(now: datetime, delivery_type: str) -> bool:
    if is_kitchen_closed(now):
        return False

    local_now = timezone.localtime(now)
    min_dt = min_delivery_datetime(local_now, delivery_type)
    max_dt = max_delivery_datetime(local_now)

    return min_dt <= max_dt


def next_ordering_opens_at(now: datetime) -> datetime:
    local_now = timezone.localtime(now)
    today = local_now.date()
    open_today = combine_local(today, OPEN_TIME)

    if local_now < open_today:
        return open_today

    tomorrow = today + timedelta(days=1)
    return combine_local(tomorrow, OPEN_TIME)


def available_slot_times(now: datetime, delivery_type: str) -> list[str]:
    if is_kitchen_closed(now):
        return []

    local_now = timezone.localtime(now)
    min_slot = _round_up_to_interval(min_delivery_datetime(local_now, delivery_type))
    max_slot = max_delivery_datetime(local_now)

    if min_slot > max_slot:
        return [max_slot.strftime('%H:%M')]

    slots: list[str] = []
    cursor = min_slot

    while cursor <= max_slot:
        slots.append(cursor.strftime('%H:%M'))
        cursor += SLOT_INTERVAL

    return slots


def validate_order_delivery_window(
    *,
    now: datetime,
    delivery_type: str,
    delivery_time_type: str,
    delivery_time: str,
) -> None:
    from rest_framework import serializers

    if is_kitchen_closed(now):
        opens_at = next_ordering_opens_at(now)
        raise serializers.ValidationError(
            'Приём заказов сейчас закрыт. '
            f'Оформление снова будет доступно с {opens_at.strftime("%H:%M")}.'
        )

    if delivery_time_type != Order.DeliveryTimeType.BY_TIME:
        return

    allowed = set(available_slot_times(now, delivery_type))
    normalized_time = (delivery_time or '').strip()

    if normalized_time not in allowed:
        raise serializers.ValidationError(
            'Выбранное время доставки недоступно. Обновите время и попробуйте снова.'
        )
