"""Convert legal .docx files to HTML for server hosting."""

from __future__ import annotations

import html
import re
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

DOCX_NS = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'

SLUG_BY_PREFIX = {
    '01': 'user-agreement',
    '02': 'privacy-policy',
    '03': 'personal-data-consent',
    '04': 'marketing-consent',
    '05': 'cookie-policy',
    '06': 'account-deletion',
}

DOCUMENT_TITLES = {
    'user-agreement': 'Пользовательское соглашение',
    'privacy-policy': 'Политика конфиденциальности',
    'personal-data-consent': 'Согласие на обработку персональных данных',
    'marketing-consent': 'Согласие на рекламные и информационные сообщения',
    'cookie-policy': 'Политика Cookie',
    'account-deletion': 'Порядок удаления аккаунта',
}

SECTION_HEADING_RE = re.compile(r'^\d+\.\s+\S')
META_LINE_RE = re.compile(r'^(Дата вступления в силу:.+)$', re.IGNORECASE)
URL_RE = re.compile(r'(https?://[^\s<>"\'\)\]]+)')


def extract_paragraph_text(paragraph) -> str:
    parts: list[str] = []

    for child in paragraph:
        if child.tag.endswith('}r'):
            for node in child.iter(f'{DOCX_NS}t'):
                if node.text:
                    parts.append(node.text)
            for node in child.iter(f'{DOCX_NS}tab'):
                parts.append(' ')
            for node in child.iter(f'{DOCX_NS}br'):
                parts.append('\n')
        elif child.tag.endswith('}hyperlink'):
            for node in child.iter(f'{DOCX_NS}t'):
                if node.text:
                    parts.append(node.text)

    return normalize_spacing(''.join(parts)).strip()


def normalize_spacing(text: str) -> str:
    text = re.sub(r'\.([А-ЯA-ZЁ])', r'. \1', text)
    text = re.sub(r'([а-яё])([А-ЯЁ])', r'\1 \2', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text


def extract_paragraphs(docx_path: Path) -> list[str]:
    with zipfile.ZipFile(docx_path) as archive:
        xml = archive.read('word/document.xml')

    root = ET.fromstring(xml)
    paragraphs: list[str] = []

    for paragraph in root.iter(f'{DOCX_NS}p'):
        line = extract_paragraph_text(paragraph)
        if line:
            paragraphs.append(line)

    return paragraphs


def split_document_title(first_paragraph: str) -> tuple[str, str | None]:
    match = META_LINE_RE.search(first_paragraph)
    if match:
        title = first_paragraph[: match.start()].strip()
        meta = match.group(1).strip()
        if title:
            return title, meta

    return first_paragraph, None


def linkify(text: str) -> str:
    escaped = html.escape(text)

    def replace(match: re.Match[str]) -> str:
        raw_url = match.group(1)
        url = raw_url.rstrip('.,;:)')
        trailing = raw_url[len(url):]
        return (
            f'<a href="{html.escape(url)}" target="_blank" '
            f'rel="noopener noreferrer">{html.escape(url)}</a>'
            f'{html.escape(trailing)}'
        )

    return URL_RE.sub(replace, escaped)


def render_paragraph(text: str) -> str:
    content = linkify(text)

    if SECTION_HEADING_RE.match(text):
        return f'<p class="section-title"><strong>{content}</strong></p>'

    return f'<p>{content}</p>'


def build_html(
    title: str,
    paragraphs: list[str],
    *,
    meta_line: str | None = None,
    body_start_index: int = 1,
) -> str:
    body_parts = [
        '<!DOCTYPE html>',
        '<html lang="ru">',
        '<head>',
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f'<title>{html.escape(title)}</title>',
        '<style>',
        'body{font-family:sans-serif;font-size:16px;line-height:1.55;padding:16px;'
        'max-width:720px;margin:0 auto;color:#222;background:#fff}',
        'h1{font-size:1.25rem;font-weight:700;margin:0 0 12px}',
        'p{margin:0 0 12px;white-space:pre-wrap}',
        'p.meta{font-size:1rem;font-weight:400;color:#555;margin:0 0 16px}',
        'p.section-title{font-size:1rem;font-weight:700;margin:16px 0 8px}',
        'a{color:#1a5fb4;word-break:break-word}',
        '</style>',
        '</head>',
        '<body>',
        f'<h1>{html.escape(title)}</h1>',
    ]

    if meta_line:
        body_parts.append(f'<p class="meta">{html.escape(meta_line)}</p>')

    for paragraph in paragraphs[body_start_index:]:
        body_parts.append(render_paragraph(paragraph))

    body_parts.extend(['</body>', '</html>'])
    return '\n'.join(body_parts)


def main() -> None:
    project_root = Path(__file__).resolve().parents[2]
    source_dir = project_root.parent / 'Юридические документы'
    output_dir = Path(__file__).resolve().parents[1] / 'legal' / 'static_documents'
    output_dir.mkdir(parents=True, exist_ok=True)

    if not source_dir.exists():
        raise SystemExit(f'Source directory not found: {source_dir}')

    for docx_path in sorted(source_dir.glob('*.docx')):
        prefix = docx_path.name[:2]
        slug = SLUG_BY_PREFIX.get(prefix, docx_path.stem)
        paragraphs = extract_paragraphs(docx_path)

        if not paragraphs:
            title = DOCUMENT_TITLES.get(slug, slug)
            html_content = build_html(title, paragraphs)
        elif SECTION_HEADING_RE.match(paragraphs[0]):
            title = DOCUMENT_TITLES.get(slug, paragraphs[0])
            html_content = build_html(
                title,
                paragraphs,
                body_start_index=0,
            )
        else:
            raw_title = paragraphs[0]
            title, meta_line = split_document_title(raw_title)
            body_start_index = 1

            if meta_line is None and len(paragraphs) > 1:
                second_meta = META_LINE_RE.match(paragraphs[1])
                if second_meta:
                    meta_line = second_meta.group(1)
                    body_start_index = 2

            html_content = build_html(
                title,
                paragraphs,
                meta_line=meta_line,
                body_start_index=body_start_index,
            )

        target = output_dir / f'{slug}.html'
        target.write_text(html_content, encoding='utf-8')
        print(f'Wrote {target.name} ({len(paragraphs)} paragraphs)')


if __name__ == '__main__':
    main()
