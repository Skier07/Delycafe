from django.http import Http404, HttpResponse
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from customers.models import Customer
from customers.views import get_or_create_customer_by_phone, normalize_phone
from legal.documents import LEGAL_DOCS_VERSION, get_document, document_html_path
from legal.documents import LEGAL_DOCUMENTS
from legal.services import LegalConsentError, consent_status_payload, save_customer_consents


class LegalDocumentsListAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        documents = [
            {
                'slug': document.slug,
                'title': document.title,
                'required_for_order': document.required_for_order,
                'url': request.build_absolute_uri(
                    f'/api/legal/documents/{document.slug}/'
                ),
            }
            for document in LEGAL_DOCUMENTS
        ]

        return Response(
            {
                'legal_docs_version': LEGAL_DOCS_VERSION,
                'documents': documents,
            }
        )


class LegalDocumentHTMLAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, slug: str):
        document = get_document(slug)
        if document is None:
            raise Http404('Документ не найден.')

        path = document_html_path(document)
        if not path.exists():
            raise Http404('Файл документа не найден на сервере.')

        content = path.read_text(encoding='utf-8')
        return HttpResponse(content, content_type='text/html; charset=utf-8')


class LegalConsentStatusAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phone = request.query_params.get('phone')
        customer = None

        if phone:
            normalized_phone = normalize_phone(phone)
            if normalized_phone:
                customer = Customer.objects.filter(phone=normalized_phone).first()

        return Response(consent_status_payload(customer))


class LegalConsentSaveAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        phone = request.data.get('phone')
        customer, error_response = get_or_create_customer_by_phone(phone)

        if error_response is not None:
            return error_response

        terms = bool(request.data.get('terms_accepted'))
        privacy = bool(request.data.get('privacy_accepted'))
        pd_consent = bool(request.data.get('pd_consent_accepted'))
        marketing = bool(request.data.get('marketing_consent_accepted'))

        try:
            save_customer_consents(
                customer=customer,
                terms=terms,
                privacy=privacy,
                pd_consent=pd_consent,
                marketing=marketing,
            )
        except LegalConsentError as error:
            return Response(
                {'detail': str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(consent_status_payload(customer))
