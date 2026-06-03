from rest_framework import serializers

from .models import Customer


class CustomerProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = (
            'id',
            'phone',
            'name',
            'default_address',
            'bonus_balance',
            'first_order_discount_available',
            'first_order_discount_used',
            'is_active',
            'created_at',
            'updated_at',
        )