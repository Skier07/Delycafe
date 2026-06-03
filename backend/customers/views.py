from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Customer
from .serializers import CustomerProfileSerializer


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

        normalized_phone = normalize_phone(phone)

        customer, created = Customer.objects.get_or_create(
            phone=normalized_phone,
            defaults={
                'first_order_discount_available': True,
                'first_order_discount_used': False,
            },
        )

        serializer = CustomerProfileSerializer(customer)

        return Response(serializer.data)