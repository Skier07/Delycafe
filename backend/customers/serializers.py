from rest_framework import serializers

from .models import BonusTransaction, Customer, CustomerAddress


class CustomerAddressSerializer(serializers.ModelSerializer):
    full_address = serializers.CharField(read_only=True)

    class Meta:
        model = CustomerAddress
        fields = (
            'id',
            'title',
            'address',
            'entrance',
            'floor',
            'apartment',
            'comment',
            'is_default',
            'full_address',
            'created_at',
            'updated_at',
        )

    def validate_address(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError('Адрес не может быть пустым.')

        return value


class CustomerProfileSerializer(serializers.ModelSerializer):
    addresses = CustomerAddressSerializer(many=True, read_only=True)

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
            'saby_external_id',
            'saby_synced_at',
            'addresses',
            'created_at',
            'updated_at',
        )


class CustomerAuthAccountSerializer(serializers.ModelSerializer):
    phone = serializers.SerializerMethodField()

    class Meta:
        model = Customer
        fields = (
            'id',
            'phone',
            'name',
            'bonus_balance',
            'saby_synced_at',
        )

    def get_phone(self, customer: Customer) -> str:
        digits = customer.phone

        if len(digits) == 11 and digits.startswith('7'):
            return f'+{digits}'

        return digits


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
