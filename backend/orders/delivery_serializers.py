from rest_framework import serializers

from .models import DeliveryInfoSection, DeliveryPriceTier, DeliveryZone


class DeliveryPriceTierSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryPriceTier
        fields = (
            'min_cart_total',
            'price',
        )


class DeliveryZoneSerializer(serializers.ModelSerializer):
    price_tiers = DeliveryPriceTierSerializer(many=True, read_only=True)

    class Meta:
        model = DeliveryZone
        fields = (
            'code',
            'title',
            'pricing_mode',
            'fixed_price',
            'requires_address',
            'default_locality',
            'lead_minutes',
            'checkout_description',
            'price_tiers',
        )


class DeliveryInfoSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryInfoSection
        fields = (
            'title',
            'content',
            'section_type',
        )
