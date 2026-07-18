from django.urls import path

from .views import (
    LegalConsentSaveAPIView,
    LegalConsentStatusAPIView,
    LegalDocumentHTMLAPIView,
    LegalDocumentsListAPIView,
)


urlpatterns = [
    path(
        'documents/',
        LegalDocumentsListAPIView.as_view(),
        name='legal-documents-list',
    ),
    path(
        'documents/<slug:slug>/',
        LegalDocumentHTMLAPIView.as_view(),
        name='legal-document-html',
    ),
    path(
        'consent/status/',
        LegalConsentStatusAPIView.as_view(),
        name='legal-consent-status',
    ),
    path(
        'consent/',
        LegalConsentSaveAPIView.as_view(),
        name='legal-consent-save',
    ),
]
