from catalog.models import CatalogSnippet, InfoSection, Product, ProductInfoNote, ProductSnippet


SECTION_TITLES = dict(InfoSection.choices)


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


def resolve_info_blocks(product: Product) -> list[dict]:
    blocks: list[dict] = []

    snippet_links = getattr(product, 'prefetched_snippets', None)

    if snippet_links is None:
        snippet_links = product.product_snippets.select_related('snippet').all()

    for link in snippet_links:
        if not link.is_enabled:
            continue

        text = link.resolved_text()

        if not text:
            continue

        blocks.append(
            {
                'section': link.snippet.section,
                'title': link.snippet.get_section_display(),
                'text': text,
                'style': link.snippet.style,
                'sort_order': link.snippet.sort_order,
            }
        )

    notes = getattr(product, 'prefetched_notes', None)

    if notes is None:
        notes = product.info_notes.all()

    for note in notes:
        text = (note.text or '').strip()

        if not text:
            continue

        blocks.append(
            {
                'section': note.section,
                'title': note.get_section_display(),
                'text': text,
                'style': note.style,
                'sort_order': note.sort_order,
            }
        )

    section_rank = {
        InfoSection.WHY_TRY: 0,
        InfoSection.IMPORTANT: 1,
    }
    blocks.sort(key=lambda item: (section_rank.get(item['section'], 9), item['sort_order']))

    for item in blocks:
        item.pop('sort_order', None)

    return blocks
