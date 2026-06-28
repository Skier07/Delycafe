import logging

from django.conf import settings
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from payments.services import AlfaPaymentError, create_alfa_payment

from .serializers import OrderCreateSerializer, OrderSerializer
logger = logging.getLogger(__name__)


class OrderCreateAPIView(APIView):
    def post(self, request):
        serializer = OrderCreateSerializer(data=request.data)

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
                    payment_error = str(error)
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
        if payment_error:
            response_data['payment_error'] = payment_error

        return Response(
            response_data,
            status=status.HTTP_201_CREATED,
        )