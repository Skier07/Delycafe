from __future__ import annotations

from copy import deepcopy
from typing import Any

DEFAULT_LINE: dict[str, Any] = {
    'text': '',
    'marker': 'bullet',
    'font_size': 'normal',
    'bold': False,
    'italic': False,
    'underline': False,
}

MARKERS = frozenset({'bullet', 'dash', 'number', 'none'})
FONT_SIZES = frozenset({'small', 'normal', 'large'})


def normalize_line(raw: dict[str, Any] | None) -> dict[str, Any]:
    line = deepcopy(DEFAULT_LINE)

    if not isinstance(raw, dict):
        return line

    text = str(raw.get('text') or '').strip()
    marker = str(raw.get('marker') or 'bullet').strip().lower()
    font_size = str(raw.get('font_size') or 'normal').strip().lower()

    line['text'] = text
    line['marker'] = marker if marker in MARKERS else 'bullet'
    line['font_size'] = font_size if font_size in FONT_SIZES else 'normal'
    line['bold'] = bool(raw.get('bold'))
    line['italic'] = bool(raw.get('italic'))
    line['underline'] = bool(raw.get('underline'))

    return line


def empty_content() -> dict[str, list]:
    return {'lines': []}


def parse_content(
    raw: Any,
    fallback_text: str = '',
) -> dict[str, list]:
    if isinstance(raw, dict) and isinstance(raw.get('lines'), list):
        lines = [
            normalize_line(item)
            for item in raw['lines']
            if isinstance(item, dict)
        ]
        lines = [line for line in lines if line['text']]

        return {'lines': lines}

    text = (fallback_text or '').strip()

    if not text:
        return empty_content()

    return {'lines': [normalize_line({'text': text})]}


def content_to_plain_text(content: Any, fallback_text: str = '') -> str:
    parsed = parse_content(content, fallback_text)
    parts = [
        line['text'].strip()
        for line in parsed['lines']
        if line['text'].strip()
    ]

    return '\n'.join(parts)


def resolved_lines(
    content: Any,
    fallback_text: str = '',
) -> list[dict[str, Any]]:
    return parse_content(content, fallback_text)['lines']
