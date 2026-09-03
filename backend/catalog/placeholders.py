"""Подстановка процентов промо в тексты CMS.

В админке пишите плейсхолдеры — цифры подставятся из orders.promotions
при отдаче API / на клиенте:

  {{earn_percent}}              — % начисления бонусов
  {{max_spend_percent}}         — макс. % оплаты бонусами
  {{pickup_discount_percent}}   — % скидки при самовывозе
"""

from __future__ import annotations

import re
from typing import Any

from orders.promotions import (
    BONUS_EARN_PERCENT,
    MAX_BONUS_SPEND_PERCENT,
    PICKUP_DISCOUNT_PERCENT,
)

PLACEHOLDER_PATTERN = re.compile(r'\{\{\s*([a-z0-9_]+)\s*\}\}')


def promotion_placeholder_values() -> dict[str, str]:
    return {
        'earn_percent': str(BONUS_EARN_PERCENT),
        'max_spend_percent': str(MAX_BONUS_SPEND_PERCENT),
        'pickup_discount_percent': str(PICKUP_DISCOUNT_PERCENT),
    }


def substitute_placeholders(
    text: str,
    values: dict[str, str] | None = None,
) -> str:
    if not text:
        return text

    mapping = values or promotion_placeholder_values()

    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        return mapping.get(key, match.group(0))

    return PLACEHOLDER_PATTERN.sub(replace, text)


def substitute_content_lines(
    lines: list[dict[str, Any]],
    values: dict[str, str] | None = None,
) -> list[dict[str, Any]]:
    mapping = values or promotion_placeholder_values()
    result: list[dict[str, Any]] = []

    for line in lines:
        item = dict(line)
        if item.get('text'):
            item['text'] = substitute_placeholders(str(item['text']), mapping)
        result.append(item)

    return result
