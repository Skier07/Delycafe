from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

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
            }
        )
