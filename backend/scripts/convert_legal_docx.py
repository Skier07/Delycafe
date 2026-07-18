"""Convert legal .docx files to HTML for server hosting."""

from __future__ import annotations

import html
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


def extract_paragraphs(docx_path: Path) -> list[str]:
    with zipfile.ZipFile(docx_path) as archive:
        xml = archive.read('word/document.xml')

    root = ET.fromstring(xml)
    paragraphs: list[str] = []

    for paragraph in root.iter(f'{DOCX_NS}p'):
        texts = [
            node.text
            for node in paragraph.iter(f'{DOCX_NS}t')
            if node.text
        ]
        line = ''.join(texts).strip()
        if line:
            paragraphs.append(line)

    return paragraphs


def build_html(title: str, paragraphs: list[str]) -> str:
    body_parts = [
        '<!DOCTYPE html>',
        '<html lang="ru">',
        '<head>',
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f'<title>{html.escape(title)}</title>',
        '<style>',
        'body{font-family:sans-serif;line-height:1.55;padding:16px;'
        'max-width:720px;margin:0 auto;color:#222;background:#fff}',
        'h1{font-size:1.25rem;margin:0 0 16px}',
        'p{margin:0 0 12px;white-space:pre-wrap}',
        '</style>',
        '</head>',
        '<body>',
        f'<h1>{html.escape(title)}</h1>',
    ]

    for paragraph in paragraphs[1:]:
        body_parts.append(f'<p>{html.escape(paragraph)}</p>')

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
        title = paragraphs[0] if paragraphs else slug
        html_content = build_html(title, paragraphs)
        target = output_dir / f'{slug}.html'
        target.write_text(html_content, encoding='utf-8')
        print(f'Wrote {target.name} ({len(paragraphs)} paragraphs)')


if __name__ == '__main__':
    main()
