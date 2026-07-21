import logging

from django.conf import settings
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from customers.authentication import (
    CustomerTokenAuthentication,
    OrderAccessTokenAuthentication,
    get_request_customer,
)
from customers.services.auth_token_service import create_order_access_token
from customers.views import normalize_phone
from payments.services import AlfaPaymentError, create_alfa_payment

from .serializers import OrderCreateSerializer, OrderSerializer

logger = logging.getLogger(__name__)


class OrderCreateAPIView(APIView):
    authentication_classes = [
        CustomerTokenAuthentication,
        OrderAccessTokenAuthentication,
    ]

    def post(self, request):
        payload = dict(request.data)
        customer = get_request_customer(request)

        if customer is not None:
            payload['phone'] = customer.phone

        serializer = OrderCreateSerializer(data=payload)

        serializer.is_valid(raise_exception=True)

        order = serializer.save()

        payment_error = None

        if getattr(settings, 'ALFA_PAYMENT_ENABLED', False):
            try:
                create_alfa_payment(order)
                order.refresh_from_db()
            except AlfaPaymentError as error:
                order.refresh_from_db()
                if not (order.payment_url or '').strip():
                    payment_error = 'Не удалось создать оплату. Попробуйте позже.'
                logger.exception(
                    'Failed to register Alfa payment for order #%s',
                    order.id,
                )

        response_serializer = OrderSerializer(
            order,
            context={
                'request': request,
            },
        )

        response_data = response_serializer.data
        response_data['order_access_token'] = create_order_access_token(
            order_id=order.id,
            phone=normalize_phone(order.phone),
        )

        if payment_error:
            response_data['payment_error'] = payment_error

        return Response(
            response_data,
            status=status.HTTP_201_CREATED,
        )
