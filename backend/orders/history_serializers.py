from rest_framework import serializers

from .models import Order, OrderItem


class OrderHistoryItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = (
            'id',
            'product_title',
            'variant_title',
            'quantity',
            'price',
            'total_price',
        )


class OrderHistorySerializer(serializers.ModelSerializer):
    items = OrderHistoryItemSerializer(many=True, read_only=True)

    status_label = serializers.CharField(
        source='get_status_display',
        read_only=True,
    )
    delivery_type_label = serializers.SerializerMethodField()

    def get_delivery_type_label(self, order):
        from orders.delivery_pricing import get_delivery_zone_title

        return get_delivery_zone_title(order.delivery_type)
    payment_type_label = serializers.CharField(
        source='get_payment_type_display',
        read_only=True,
    )
    payment_status_label = serializers.CharField(
        source='get_payment_status_display',
        read_only=True,
    )

    class Meta:
        model = Order
        fields = (
            'id',
            'phone',
            'customer_name',
            'delivery_type',
            'delivery_type_label',
            'address',
            'payment_type',
            'payment_type_label',
            'payment_status',
            'payment_status_label',
            'products_total',
            'delivery_price',
            'discount_amount',
            'bonus_spent',
            'bonus_earned',
            'total_price',
            'status',
            'status_label',
            'comment',
            'created_at',
            'items',
        )
