from rest_framework import serializers

from .models import BonusTransaction, Customer


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


class BonusTransactionSerializer(serializers.ModelSerializer):
    transaction_type_label = serializers.CharField(
        source='get_transaction_type_display',
        read_only=True,
    )

    class Meta:
        model = BonusTransaction
        fields = (
            'id',
            'transaction_type',
            'transaction_type_label',
            'amount',
            'comment',
            'order_id',
            'created_at',
        )