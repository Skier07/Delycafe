"""Промо-механики приложения (бонусы, скидка самовывоза).

Источник правды для приложения — локальный ledger (Customer.bonus_balance +
BonusTransaction). API баланса Presto по телефону у Saby пока нет: ручная
правка в админке отображается в приложении, но может не совпадать с кассой.

Списание в Presto — retail bonus-write-off после order/create (фискальный контур).
Скидка самовывоза 5%: в приложении; в Presto уходит в cost позиций
(акция Saby на API-заказы ненадёжна — иначе разрыв суммы и нет чека АТОЛ).

Округление самовывоза — построчно (как на кассе):
  discounted_unit = price * (100 - percent) // 100
  discount = sum((price - discounted_unit) * qty)
Нельзя считать percent% от суммы корзины целиком — иначе ±1 ₽ к чеку Saby.
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import Sequence

# Бонусы включены: списание в приложении + write-off в Saby.
APP_BONUSES_ENABLED = True

# Скидка 20% на первый заказ отключена и нигде не применяется.
APP_FIRST_ORDER_DISCOUNT_ENABLED = False

# Процент начисления в приложении (и ожидание в Presto при сверке).
BONUS_EARN_PERCENT = 3

# Максимум списания бонусами от суммы товаров после скидок.
MAX_BONUS_SPEND_PERCENT = 25

# Постоянная скидка при самовывозе.
PICKUP_DISCOUNT_PERCENT = 5


def discounted_unit_price(
    unit_price: int,
    percent: int = PICKUP_DISCOUNT_PERCENT,
) -> int:
    """Цена единицы после скидки самовывоза (округление вниз, как cost в Saby)."""
    if unit_price <= 0 or percent <= 0:
        return max(0, unit_price)
    return max(0, unit_price * (100 - percent) // 100)


def pickup_discount_amount(
    lines: Iterable[Sequence[int]],
    percent: int = PICKUP_DISCOUNT_PERCENT,
) -> int:
    """Сумма скидки самовывоза по строкам [(unit_price, quantity), ...].

    Совпадает с тем, что уходит в Saby как (price - cost) * count.
    """
    if percent <= 0:
        return 0

    total = 0
    for line in lines:
        unit_price = int(line[0])
        quantity = int(line[1])
        if unit_price <= 0 or quantity <= 0:
            continue
        discounted = discounted_unit_price(unit_price, percent)
        total += (unit_price - discounted) * quantity
    return total
