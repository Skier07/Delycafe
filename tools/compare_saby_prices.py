#!/usr/bin/env python3
"""Compare app catalog prices (generated_catalog.dart) with Saby nomenclature dump."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_saby_nomenclature() -> dict[int, dict]:
    data = json.loads(
        (ROOT / 'tools/saby_nomenclature_response.json').read_text(encoding='utf-8')
    )

    items = data.get('nomenclatures') or data.get('items') or data
    if isinstance(data, dict) and not isinstance(items, list):
        for value in data.values():
            if (
                isinstance(value, list)
                and value
                and isinstance(value[0], dict)
                and 'id' in value[0]
            ):
                items = value
                break

    by_id: dict[int, dict] = {}
    for item in items:
        saby_id = item.get('id')
        if saby_id is None:
            continue

        by_id[int(saby_id)] = {
            'name': item.get('name', ''),
            'cost': item.get('cost'),
            'unit': item.get('unit', ''),
            'published': item.get('published'),
        }

    return by_id


def load_app_catalog() -> list[dict]:
    text = (ROOT / 'lib/data/generated_catalog.dart').read_text(encoding='utf-8')
    pattern = re.compile(
        r"CatalogItem\(\s*"
        r"id: 'saby_(\d+)',\s*"
        r"title: '([^']*)',"
        r"(.*?)"
        r"\s*price: (\d+),",
        re.S,
    )

    items = []
    for match in pattern.finditer(text):
        body = match.group(3)
        weight_match = re.search(r"weight: '([^']*)'", body)

        items.append(
            {
                'saby_id': int(match.group(1)),
                'title': match.group(2),
                'price': int(match.group(4)),
                'weight': weight_match.group(1) if weight_match else '',
            }
        )

    return items


def main() -> None:
    saby_by_id = load_saby_nomenclature()
    app_items = load_app_catalog()

    mismatches = []
    missing = []

    for item in app_items:
        saby_id = item['saby_id']
        saby_item = saby_by_id.get(saby_id)

        if saby_item is None:
            missing.append(item)
            continue

        saby_cost = saby_item['cost']
        if saby_cost is None:
            continue

        saby_price = int(round(float(saby_cost)))
        app_price = item['price']

        if saby_price != app_price:
            mismatches.append(
                {
                    **item,
                    'saby_name': saby_item['name'],
                    'saby_price': saby_price,
                    'saby_unit': saby_item['unit'],
                    'diff': saby_price - app_price,
                }
            )

    mismatches.sort(key=lambda row: abs(row['diff']), reverse=True)

    out_path = ROOT / 'tools/saby_price_mismatches.json'
    out_path.write_text(
        json.dumps(mismatches, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )

    md_path = ROOT / 'tools/saby_price_mismatches.md'
    lines = [
        '# Расхождения цен: приложение vs Saby',
        '',
        f'- Позиций в приложении: **{len(app_items)}**',
        f'- Позиций в Saby: **{len(saby_by_id)}**',
        f'- Расхождений по цене: **{len(mismatches)}**',
        f'- Нет в дампе Saby: **{len(missing)}**',
        '',
        'На фискальном чеке ATOL Saby использует **цену из номенклатуры**, '
        'разницу с оплатой показывает как «Скидку».',
        '',
        '| saby_id | Приложение | Saby | Δ | Ед. | Название в app | Название в Saby |',
        '|--------:|-----------:|-----:|--:|:----|:---------------|:----------------|',
    ]

    for row in mismatches:
        lines.append(
            f"| {row['saby_id']} | {row['price']} ₽ | {row['saby_price']} ₽ | "
            f"{row['diff']:+d} ₽ | {row['saby_unit']} | "
            f"{row['title']} | {row['saby_name']} |"
        )

    if missing:
        lines.extend(['', '## Нет в дампе Saby', ''])
        for row in missing:
            lines.append(f"- `{row['saby_id']}` — {row['title']} ({row['price']} ₽)")

    md_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')

    print(f'App items: {len(app_items)}')
    print(f'Saby items: {len(saby_by_id)}')
    print(f'Mismatches: {len(mismatches)}')
    print(f'Missing: {len(missing)}')
    print(f'Written: {out_path.relative_to(ROOT)}')
    print(f'Written: {md_path.relative_to(ROOT)}')
    print()
    print('Top 20 mismatches:')
    for row in mismatches[:20]:
        print(
            f"  {row['saby_id']:4}  app={row['price']:4}  saby={row['saby_price']:4}  "
            f"diff={row['diff']:+4}  {row['saby_unit']!s:4}  "
            f"{row['title']!r} / {row['saby_name']!r}"
        )


if __name__ == '__main__':
    main()
