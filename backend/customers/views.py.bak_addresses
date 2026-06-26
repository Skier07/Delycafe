from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Customer
from .serializers import CustomerProfileSerializer, BonusTransactionSerializer


BONUS_EARN_PERCENT = 5
MAX_BONUS_SPEND_PERCENT = 30


def normalize_phone(phone):
    phone = phone.strip()
    digits = ''.join(char for char in phone if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return f'+{digits}'

    return phone


def get_or_create_customer_by_phone(phone):
    normalized_phone = normalize_phone(phone)

    customer, created = Customer.objects.get_or_create(
        phone=normalized_phone,
        defaults={
            'first_order_discount_available': True,
            'first_order_discount_used': False,
        },
    )

    return customer


class CustomerProfileAPIView(APIView):
    def get(self, request):
        phone = request.query_params.get('phone', '').strip()

        if not phone:
            return Response(
                {
                    'detail': 'Не передан номер телефона.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        customer = get_or_create_customer_by_phone(phone)

        serializer = CustomerProfileSerializer(customer)

        return Response(serializer.data)


class CustomerBonusesAPIView(APIView):
    def get(self, request):
        phone = request.query_params.get('phone', '').strip()

        if not phone:
            return Response(
                {
                    'detail': 'Не передан номер телефона.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        customer = get_or_create_customer_by_phone(phone)

        transactions = customer.bonus_transactions.all()[:50]

        transactions_serializer = BonusTransactionSerializer(
            transactions,
            many=True,
        )

        return Response(
            {
                'customer_id': customer.id,
                'phone': customer.phone,
                'bonus_balance': customer.bonus_balance,
                'earn_percent': BONUS_EARN_PERCENT,
                'max_spend_percent': MAX_BONUS_SPEND_PERCENT,
                'first_order_discount_available': (
                    customer.first_order_discount_available
                ),
                'first_order_discount_used': (
                    customer.first_order_discount_used
                ),
                'transactions': transactions_serializer.data,
            }
        )