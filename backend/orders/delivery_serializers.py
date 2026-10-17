from rest_framework import serializers

from .models import DeliveryInfoSection, DeliveryPriceTier, DeliveryZone
from .delivery_text import render_delivery_text


class DeliveryPriceTierSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryPriceTier
        fields = (
            'min_cart_total',
            'price',
        )


class DeliveryZoneSerializer(serializers.ModelSerializer):
    price_tiers = DeliveryPriceTierSerializer(many=True, read_only=True)
    checkout_description = serializers.SerializerMethodField()

    def get_checkout_description(self, obj):
        return render_delivery_text(obj.checkout_description, self.context.get('zones', {obj.code: obj}))

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
    content = serializers.SerializerMethodField()

    def get_content(self, obj):
        return render_delivery_text(obj.content, self.context.get('zones', {}))

    class Meta:
        model = DeliveryInfoSection
        fields = (
            'title',
            'content',
            'section_type',
        )
