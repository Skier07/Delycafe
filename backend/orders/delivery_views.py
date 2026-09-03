from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from orders.promotions import (
    BONUS_EARN_PERCENT,
    MAX_BONUS_SPEND_PERCENT,
    PICKUP_DISCOUNT_PERCENT,
)

from .delivery_serializers import (
    DeliveryInfoSectionSerializer,
    DeliveryZoneSerializer,
)
from .models import DeliveryInfoSection, DeliveryZone


class DeliveryConfigAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        zones = (
            DeliveryZone.objects.filter(is_active=True)
            .prefetch_related('price_tiers')
            .order_by('sort_order', 'id')
        )
        sections = (
            DeliveryInfoSection.objects.filter(is_active=True)
            .order_by('sort_order', 'id')
        )

        return Response(
            {
                'zones': DeliveryZoneSerializer(zones, many=True).data,
                'info_sections': DeliveryInfoSectionSerializer(
                    sections,
                    many=True,
                ).data,
                'promotions': {
                    'earn_percent': BONUS_EARN_PERCENT,
                    'max_spend_percent': MAX_BONUS_SPEND_PERCENT,
                    'pickup_discount_percent': PICKUP_DISCOUNT_PERCENT,
                },
            }
        )
