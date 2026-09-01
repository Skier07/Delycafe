from catalog.info_content import content_to_plain_text, resolved_lines
from catalog.models import CatalogSnippet, Product, ProductInfoNote, ProductSnippet


def _section_payload(info_section) -> tuple[str, str]:
    return info_section.code, info_section.title


def attach_default_snippets(product: Product) -> int:
    snippets = list(CatalogSnippet.objects.filter(is_default=True))

    if product.category_id:
        snippets.extend(
            CatalogSnippet.objects.filter(default_for_category=product.category)
        )

    created = 0
    seen = set()

    for snippet in snippets:
        if snippet.id in seen:
            continue

        seen.add(snippet.id)
        _, was_created = ProductSnippet.objects.get_or_create(
            product=product,
            snippet=snippet,
            defaults={'is_enabled': True},
        )

        if was_created:
            created += 1

    return created


def _lines_payload(lines: list[dict]) -> list[dict]:
    numbered = 0

    payload = []

    for line in lines:
        marker = line.get('marker', 'bullet')

        if marker == 'number':
            numbered += 1
            number = numbered
        else:
            number = 0

        payload.append(
            {
                'text': line.get('text', ''),
                'marker': marker,
                'font_size': line.get('font_size', 'normal'),
                'bold': bool(line.get('bold')),
                'italic': bool(line.get('italic')),
                'underline': bool(line.get('underline')),
                'number': number,
            }
        )

    return payload


def resolve_info_blocks(product: Product) -> list[dict]:
    blocks: list[dict] = []

    snippet_links = getattr(product, 'prefetched_snippets', None)

    if snippet_links is None:
        snippet_links = product.product_snippets.select_related(
            'snippet',
            'snippet__info_section',
        ).all()

    for link in snippet_links:
        if not link.is_enabled:
            continue

        info_section = link.snippet.info_section

        if not info_section.is_active:
            continue

        lines = link.resolved_lines()

        if not lines:
            continue

        section_code, section_title = _section_payload(info_section)
        formatted_lines = _lines_payload(lines)

        blocks.append(
            {
                'section': section_code,
                'title': section_title,
                'text': content_to_plain_text({'lines': lines}),
                'style': link.snippet.style,
                'lines': formatted_lines,
                'sort_order': link.snippet.sort_order,
                'section_sort_order': info_section.sort_order,
            }
        )

    notes = getattr(product, 'prefetched_notes', None)

    if notes is None:
        notes = product.info_notes.select_related('info_section').all()

    for note in notes:
        lines = resolved_lines(note.content, note.text)

        if not lines:
            continue

        info_section = note.info_section

        if not info_section.is_active:
            continue

        section_code, section_title = _section_payload(info_section)
        formatted_lines = _lines_payload(lines)

        blocks.append(
            {
                'section': section_code,
                'title': section_title,
                'text': content_to_plain_text({'lines': lines}),
                'style': note.style,
                'lines': formatted_lines,
                'sort_order': note.sort_order,
                'section_sort_order': info_section.sort_order,
            }
        )

    blocks.sort(
        key=lambda item: (
            item.get('section_sort_order', 999),
            item['sort_order'],
        ),
    )

    for item in blocks:
        item.pop('sort_order', None)
        item.pop('section_sort_order', None)

    return blocks
