import logging

from django.conf import settings
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from payments.services import AlfaPaymentError, create_alfa_payment

from .models import Order
from .serializers import OrderCreateSerializer, OrderSerializer

logger = logging.getLogger(__name__)


class OrderCreateAPIView(APIView):
    def post(self, request):
        serializer = OrderCreateSerializer(data=request.data)

        serializer.is_valid(raise_exception=True)

        order = serializer.save()

        if (
            getattr(settings, 'ALFA_PAYMENT_ENABLED', False)
            and order.payment_type != Order.PaymentType.CASH
        ):
            try:
                create_alfa_payment(order)
                order.refresh_from_db()
            except AlfaPaymentError:
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

        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED,
        )