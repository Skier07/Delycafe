from dataclasses import dataclass
from pathlib import Path

from django.conf import settings

LEGAL_DOCS_VERSION = '2026-07-18'


@dataclass(frozen=True)
class LegalDocument:
    slug: str
    title: str
    filename: str
    required_for_order: bool = False


LEGAL_DOCUMENTS: tuple[LegalDocument, ...] = (
    LegalDocument(
        slug='user-agreement',
        title='Пользовательское соглашение',
        filename='user-agreement.html',
        required_for_order=True,
    ),
    LegalDocument(
        slug='privacy-policy',
        title='Политика конфиденциальности',
        filename='privacy-policy.html',
        required_for_order=True,
    ),
    LegalDocument(
        slug='personal-data-consent',
        title='Согласие на обработку персональных данных',
        filename='personal-data-consent.html',
        required_for_order=True,
    ),
    LegalDocument(
        slug='marketing-consent',
        title='Согласие на рекламные и информационные сообщения',
        filename='marketing-consent.html',
        required_for_order=False,
    ),
    LegalDocument(
        slug='cookie-policy',
        title='Политика Cookie',
        filename='cookie-policy.html',
        required_for_order=False,
    ),
    LegalDocument(
        slug='account-deletion',
        title='Порядок удаления аккаунта',
        filename='account-deletion.html',
        required_for_order=False,
    ),
)

REQUIRED_CONSENT_SLUGS = tuple(
    document.slug
    for document in LEGAL_DOCUMENTS
    if document.required_for_order
)


def documents_directory() -> Path:
    return Path(settings.BASE_DIR) / 'legal' / 'static_documents'


def get_document(slug: str) -> LegalDocument | None:
    for document in LEGAL_DOCUMENTS:
        if document.slug == slug:
            return document

    return None


def document_html_path(document: LegalDocument) -> Path:
    return documents_directory() / document.filename
