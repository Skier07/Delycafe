from django.db import transaction
from rest_framework import serializers

from .models import Order, OrderItem


def calculate_delivery_price(delivery_type, products_total):
    if delivery_type == Order.DeliveryType.OZERSK:
        if products_total >= 1700:
            return 0

        if products_total >= 1000:
            return 200

        return 250

    if delivery_type == Order.DeliveryType.PROMPLOSHADKA:
        return 350

    if delivery_type == Order.DeliveryType.TATYSH:
        return 450

    if delivery_type == Order.DeliveryType.PICKUP:
        return 0

    return 0


class OrderItemCreateSerializer(serializers.Serializer):
    product_title = serializers.CharField(max_length=180)

    variant_title = serializers.CharField(
        max_length=80,
        required=False,
        allow_blank=True,
    )

    product_api_id = serializers.CharField(
        max_length=80,
        required=False,
        allow_blank=True,
    )

    saby_id = serializers.IntegerField(
        required=False,
        allow_null=True,
    )

    quantity = serializers.IntegerField(min_value=1)
    price = serializers.IntegerField(min_value=0)

    def validate_product_title(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'Название товара не может быть пустым.'
            )

        return value


class OrderCreateSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=30)

    customer_name = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
    )

    delivery_type = serializers.ChoiceField(
        choices=Order.DeliveryType.choices,
    )

    address = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    delivery_time_type = serializers.ChoiceField(
        choices=Order.DeliveryTimeType.choices,
    )

    delivery_time = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
    )

    payment_type = serializers.ChoiceField(
        choices=Order.PaymentType.choices,
    )

    comment = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    items = OrderItemCreateSerializer(many=True)

    def validate_phone(self, value):
        phone = value.strip()
        digits = ''.join(char for char in phone if char.isdigit())

        if len(digits) < 10:
            raise serializers.ValidationError(
                'Введите корректный номер телефона.'
            )

        return phone

    def validate_customer_name(self, value):
        return value.strip()

    def validate_address(self, value):
        return value.strip()

    def validate_delivery_time(self, value):
        return value.strip()

    def validate_comment(self, value):
        return value.strip()

    def validate(self, attrs):
        items = attrs.get('items') or []

        if not items:
            raise serializers.ValidationError(
                'В заказе должна быть хотя бы одна позиция.'
            )

        delivery_type = attrs.get('delivery_type')
        address = (attrs.get('address') or '').strip()

        if delivery_type != Order.DeliveryType.PICKUP and not address:
            raise serializers.ValidationError(
                'Для доставки нужно указать адрес.'
            )

        delivery_time_type = attrs.get('delivery_time_type')
        delivery_time = (attrs.get('delivery_time') or '').strip()

        if (
            delivery_time_type == Order.DeliveryTimeType.BY_TIME
            and not delivery_time
        ):
            raise serializers.ValidationError(
                'Если выбрана доставка ко времени, нужно указать время.'
            )

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')

        products_total = 0

        for item_data in items_data:
            quantity = item_data['quantity']
            price = item_data['price']
            products_total += quantity * price

        delivery_type = validated_data['delivery_type']

        delivery_price = calculate_delivery_price(
            delivery_type,
            products_total,
        )

        total_price = products_total + delivery_price

        order = Order.objects.create(
            **validated_data,
            products_total=products_total,
            delivery_price=delivery_price,
            total_price=total_price,
        )

        order_items = []

        for item_data in items_data:
            quantity = item_data['quantity']
            price = item_data['price']

            order_items.append(
                OrderItem(
                    order=order,
                    product_title=item_data['product_title'],
                    variant_title=item_data.get('variant_title', ''),
                    product_api_id=item_data.get('product_api_id', ''),
                    saby_id=item_data.get('saby_id'),
                    quantity=quantity,
                    price=price,
                    total_price=quantity * price,
                )
            )

        OrderItem.objects.bulk_create(order_items)

        return order


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = (
            'id',
            'product_title',
            'variant_title',
            'product_api_id',
            'saby_id',
            'quantity',
            'price',
            'total_price',
        )


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order
        fields = (
            'id',
            'phone',
            'customer_name',
            'delivery_type',
            'address',
            'delivery_time_type',
            'delivery_time',
            'payment_type',
            'comment',
            'products_total',
            'delivery_price',
            'total_price',
            'status',
            'created_at',
            'updated_at',
            'items',
        )