from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from customers.models import Customer
from .history_serializers import OrderHistorySerializer
from .models import Order


def normalize_phone(value):
    raw_phone = str(value or '').strip()
    digits = ''.join(char for char in raw_phone if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return digits

    return digits or raw_phone


class OrderHistoryAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phone = request.query_params.get('phone')
        normalized_phone = normalize_phone(phone)

        if not normalized_phone:
            return Response(
                {
                    'detail': 'Не передан телефон.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        customer = Customer.objects.filter(
            phone=normalized_phone,
        ).first()

        query = Q(phone=normalized_phone)

        if customer is not None:
            query = query | Q(customer=customer)

        orders = (
            Order.objects
            .filter(
                query,
                payment_status=Order.PaymentStatus.PAID,
            )
            .prefetch_related('items')
            .order_by('-created_at')[:50]
        )

        return Response(
            OrderHistorySerializer(
                orders,
                many=True,
            ).data
        )
