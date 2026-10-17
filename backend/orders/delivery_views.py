from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db import transaction

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
from .delivery_pricing import native_delivery_pricing


class DeliveryConfigAPIView(APIView):
    permission_classes = [AllowAny]

    @transaction.atomic
    def get(self, request):
        zones = list(
            DeliveryZone.objects.select_for_update().filter(is_active=True)
            .prefetch_related('price_tiers')
            .order_by('id')
        )
        zones.sort(key=lambda zone: (zone.sort_order, zone.pk))
        sections = (
            DeliveryInfoSection.objects.filter(is_active=True)
            .order_by('sort_order', 'id')
        )

        context = {'zones': {zone.code: zone for zone in zones}}
        response = Response(
            {
                'zones': DeliveryZoneSerializer(zones, many=True, context=context).data,
                'info_sections': DeliveryInfoSectionSerializer(
                    sections,
                    many=True,
                    context=context,
                ).data,
                'price_basis': 'after_discounts' if native_delivery_pricing() else 'products_total',
                'promotions': {
                    'earn_percent': BONUS_EARN_PERCENT,
                    'max_spend_percent': MAX_BONUS_SPEND_PERCENT,
                    'pickup_discount_percent': PICKUP_DISCOUNT_PERCENT,
                },
            }
        )
        response['Cache-Control'] = 'no-store'
        return response
