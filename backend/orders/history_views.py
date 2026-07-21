from django.db.models import Q
from rest_framework.response import Response
from rest_framework.views import APIView

from customers.authenticated_views import AuthenticatedCustomerAPIView
from customers.authentication import get_request_customer
from .history_serializers import OrderHistorySerializer
from .models import Order


class OrderHistoryAPIView(AuthenticatedCustomerAPIView):
    def get(self, request):
        customer = get_request_customer(request)
        normalized_phone = customer.phone

        query = Q(phone=normalized_phone) | Q(customer=customer)

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
