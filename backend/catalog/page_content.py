from __future__ import annotations

from copy import deepcopy
from typing import Any

DEFAULT_LINE: dict[str, Any] = {
    'type': 'text',
    'text': '',
    'marker': 'none',
    'font_size': 'normal',
    'font_family': 'default',
    'align': 'left',
    'color': '',
    'bold': False,
    'italic': False,
    'underline': False,
    'image_url': '',
    'full_bleed': False,
}

MARKERS = frozenset({'bullet', 'dash', 'number', 'none'})
FONT_SIZES = frozenset({'small', 'normal', 'large', 'xlarge'})
FONT_FAMILIES = frozenset({'default', 'serif', 'mono'})
ALIGNS = frozenset({'left', 'center', 'right'})
LINE_TYPES = frozenset({'text', 'image', 'spacer'})


def normalize_line(raw: dict[str, Any] | None) -> dict[str, Any]:
    line = deepcopy(DEFAULT_LINE)

    if not isinstance(raw, dict):
        return line

    line_type = str(raw.get('type') or 'text').strip().lower()
    if line_type not in LINE_TYPES:
        line_type = 'text'

    marker = str(raw.get('marker') or 'none').strip().lower()
    font_size = str(raw.get('font_size') or 'normal').strip().lower()
    font_family = str(raw.get('font_family') or 'default').strip().lower()
    align = str(raw.get('align') or 'left').strip().lower()
    color = str(raw.get('color') or '').strip()

    line['type'] = line_type
    line['text'] = str(raw.get('text') or '').strip()
    line['marker'] = marker if marker in MARKERS else 'none'
    line['font_size'] = font_size if font_size in FONT_SIZES else 'normal'
    line['font_family'] = (
        font_family if font_family in FONT_FAMILIES else 'default'
    )
    line['align'] = align if align in ALIGNS else 'left'
    line['color'] = color if color.startswith('#') and len(color) in (4, 7) else ''
    line['bold'] = bool(raw.get('bold'))
    line['italic'] = bool(raw.get('italic'))
    line['underline'] = bool(raw.get('underline'))
    line['image_url'] = str(raw.get('image_url') or '').strip()
    line['full_bleed'] = bool(raw.get('full_bleed'))

    return line


def empty_content() -> dict[str, list]:
    return {'lines': []}


def _line_is_meaningful(line: dict[str, Any]) -> bool:
    if line['type'] == 'spacer':
        return True

    if line['type'] == 'image':
        return bool(line['image_url'])

    return bool(line['text'])


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
        lines = [line for line in lines if _line_is_meaningful(line)]
        return {'lines': lines}

    text = (fallback_text or '').strip()

    if not text:
        return empty_content()

    return {
        'lines': [
            normalize_line({'type': 'text', 'text': paragraph, 'marker': 'none'})
            for paragraph in text.split('\n')
            if paragraph.strip()
        ],
    }


def content_to_plain_text(content: Any, fallback_text: str = '') -> str:
    parsed = parse_content(content, fallback_text)
    parts = [
        line['text'].strip()
        for line in parsed['lines']
        if line['type'] == 'text' and line['text'].strip()
    ]
    return '\n'.join(parts)


def resolved_lines(
    content: Any,
    fallback_text: str = '',
) -> list[dict[str, Any]]:
    return parse_content(content, fallback_text)['lines']
