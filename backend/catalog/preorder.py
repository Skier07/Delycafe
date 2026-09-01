from datetime import datetime, time

from django.utils import timezone

from catalog.models import Category, Product


def category_preorder_active(category: Category) -> bool:
    return bool(
        category.preorder_cutoff_enabled and category.preorder_cutoff_time,
    )


def category_can_order_now(category: Category, now: datetime | None = None) -> bool:
    if not category_preorder_active(category):
        return True

    local_now = timezone.localtime(now or timezone.now())
    return local_now.time() < category.preorder_cutoff_time


def product_can_order_now(product: Product, now: datetime | None = None) -> bool:
    return category_can_order_now(product.category, now)


def cannot_order_message(category: Category) -> str:
    if not category_preorder_active(category):
        return ''

    cutoff = category.preorder_cutoff_time
    clock = cutoff.strftime('%H:%M')

    if category.preorder_lead_days:
        return (
            f'Заказ этой позиции сегодня принимается до {clock}. '
            f'Минимум за {category.preorder_lead_days} сут.'
        )

    return f'Заказ этой позиции сегодня принимается до {clock}.'


def format_cutoff_time(value: time | None) -> str:
    if value is None:
        return ''

    return value.strftime('%H:%M')
