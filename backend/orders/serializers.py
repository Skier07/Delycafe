from datetime import timedelta

from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from customers.models import BonusTransaction, Customer
from .delivery_schedule import validate_order_delivery_window
from .models import Order, OrderItem
from .promotions import APP_BONUSES_ENABLED, APP_FIRST_ORDER_DISCOUNT_ENABLED
from .services import rollback_order
from payments.services import evaluate_alfa_session_for_reuse

UNPAID_ORDER_REUSE_HOURS = 24

FIRST_ORDER_DISCOUNT_PERCENT = 20
BONUS_EARN_PERCENT = 5
MAX_BONUS_SPEND_PERCENT = 30


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


def normalize_phone(phone):
    raw_phone = str(phone or '').strip()
    digits = ''.join(char for char in raw_phone if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return digits

    return digits or raw_phone


def phone_order_filter(phone):
    normalized = normalize_phone(phone)
    variants = {normalized, str(phone or '').strip()}

    if len(normalized) == 11 and normalized.startswith('7'):
        variants.add(f'+{normalized}')
        variants.add(f'8{normalized[1:]}')

    return Q(phone__in=[value for value in variants if value])


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

    address_locality = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
    )

    address_entrance = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
    )

    address_floor = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
    )

    address_apartment = serializers.CharField(
        max_length=20,
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
        choices=[
            Order.PaymentType.CARD,
            Order.PaymentType.SBP,
        ],
    )

    comment = serializers.CharField(
        required=False,
        allow_blank=True,
    )

    bonus_spent = serializers.IntegerField(
        required=False,
        default=0,
        min_value=0,
    )

    items = OrderItemCreateSerializer(many=True)

    def validate_phone(self, value):
        phone = normalize_phone(value)
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

        validate_order_delivery_window(
            now=timezone.now(),
            delivery_type=delivery_type,
            delivery_time_type=delivery_time_type,
            delivery_time=delivery_time,
        )

        missing_saby = [
            item.get('product_title') or 'позиция'
            for item in items
            if not item.get('saby_id')
        ]

        if missing_saby:
            raise serializers.ValidationError(
                {
                    'items': (
                        'У каждой позиции нужен saby_id для отправки в Presto: '
                        + ', '.join(missing_saby)
                    ),
                }
            )

        return attrs

    def save(self, **kwargs):
        return self.create_or_reuse(self.validated_data)

    def _build_checkout_items_signature(self, items_data):
        signatures = []

        for item in items_data:
            signatures.append(
                (
                    str(item.get('product_api_id') or ''),
                    str(item.get('variant_title') or ''),
                    int(item.get('saby_id') or 0),
                    int(item['quantity']),
                    int(item['price']),
                )
            )

        return tuple(sorted(signatures))

    def _build_order_items_signature(self, order):
        signatures = []

        for item in order.items.all():
            signatures.append(
                (
                    str(item.product_api_id or ''),
                    str(item.variant_title or ''),
                    int(item.saby_id or 0),
                    int(item.quantity),
                    int(item.price),
                )
            )

        return tuple(sorted(signatures))

    def _find_reusable_unpaid_order(self, phone, items_data):
        signature = self._build_checkout_items_signature(items_data)
        cutoff = timezone.now() - timedelta(hours=UNPAID_ORDER_REUSE_HOURS)

        candidates = (
            Order.objects.filter(
                phone_order_filter(phone),
                payment_status__in=[
                    Order.PaymentStatus.UNPAID,
                    Order.PaymentStatus.FAILED,
                ],
                status=Order.Status.NEW,
                created_at__gte=cutoff,
            )
            .prefetch_related('items')
            .order_by('-created_at')
        )

        for order in candidates:
            if self._build_order_items_signature(order) != signature:
                continue

            if not evaluate_alfa_session_for_reuse(order):
                continue

            return order

        return None

    def _cancel_unpaid_orders(self, phone, *, exclude_order_id=None):
        queryset = Order.objects.filter(
            phone_order_filter(phone),
            payment_status__in=[
                Order.PaymentStatus.UNPAID,
                Order.PaymentStatus.FAILED,
            ],
            status=Order.Status.NEW,
        )

        if exclude_order_id is not None:
            queryset = queryset.exclude(id=exclude_order_id)

        for order in queryset:
            order.status = Order.Status.CANCELED
            order.save(update_fields=['status', 'updated_at'])
            rollback_order(order)

    def _calculate_order_pricing(
        self,
        *,
        customer,
        items_data,
        delivery_type,
        requested_bonus_spent,
    ):
        products_total = 0

        for item_data in items_data:
            quantity = item_data['quantity']
            price = item_data['price']
            products_total += quantity * price

        delivery_price = calculate_delivery_price(
            delivery_type,
            products_total,
        )

        discount_amount = 0
        first_order_discount_applied = False

        can_use_first_order_discount = (
            APP_FIRST_ORDER_DISCOUNT_ENABLED
            and customer.first_order_discount_available
            and not customer.first_order_discount_used
        )

        if can_use_first_order_discount:
            discount_amount = (
                products_total * FIRST_ORDER_DISCOUNT_PERCENT // 100
            )
            first_order_discount_applied = True

        bonus_spent = 0

        if (
            APP_BONUSES_ENABLED
            and not first_order_discount_applied
            and requested_bonus_spent > 0
        ):
            max_bonus_spend = (
                products_total * MAX_BONUS_SPEND_PERCENT // 100
            )

            bonus_spent = min(
                requested_bonus_spent,
                customer.bonus_balance,
                max_bonus_spend,
                products_total,
            )

        paid_products_total = max(
            products_total - discount_amount - bonus_spent,
            0,
        )

        bonus_earned = 0

        if APP_BONUSES_ENABLED:
            bonus_earned = paid_products_total * BONUS_EARN_PERCENT // 100

        total_price = paid_products_total + delivery_price

        return {
            'products_total': products_total,
            'delivery_price': delivery_price,
            'discount_amount': discount_amount,
            'bonus_spent': bonus_spent,
            'bonus_earned': bonus_earned,
            'first_order_discount_applied': first_order_discount_applied,
            'total_price': total_price,
        }

    def _sync_customer_for_checkout(
        self,
        *,
        customer,
        customer_name,
        order_address,
        delivery_type,
    ):
        customer_update_fields = []

        if customer_name and customer.name != customer_name:
            customer.name = customer_name
            customer_update_fields.append('name')

        if (
            delivery_type != Order.DeliveryType.PICKUP
            and order_address
            and customer.default_address != order_address
        ):
            customer.default_address = order_address
            customer_update_fields.append('default_address')

        if customer_update_fields:
            customer_update_fields.append('updated_at')
            customer.save(update_fields=customer_update_fields)

        return customer

    def _needs_new_order_for_payment_change(self, order, data, items_data):
        requested_bonus_spent = data.get('bonus_spent', 0)
        if not APP_BONUSES_ENABLED:
            requested_bonus_spent = 0

        delivery_type = data.get('delivery_type')
        customer = order.customer

        if customer is None:
            return data['payment_type'] != order.payment_type

        pricing = self._calculate_order_pricing(
            customer=customer,
            items_data=items_data,
            delivery_type=delivery_type,
            requested_bonus_spent=requested_bonus_spent,
        )

        return (
            data['payment_type'] != order.payment_type
            or pricing['total_price'] != order.payment_amount
        )

    @transaction.atomic
    def create_or_reuse(self, validated_data):
        data = dict(validated_data)
        items_data = data['items']
        reusable_order = self._find_reusable_unpaid_order(
            data['phone'],
            items_data,
        )

        if reusable_order is not None:
            if self._needs_new_order_for_payment_change(
                reusable_order,
                data,
                items_data,
            ):
                self._cancel_unpaid_orders(data['phone'])
                return self.create(data)

            self._cancel_unpaid_orders(
                data['phone'],
                exclude_order_id=reusable_order.id,
            )
            return self._update_existing_order(reusable_order, data)

        self._cancel_unpaid_orders(data['phone'])
        return self.create(data)

    @transaction.atomic
    def _update_existing_order(self, order, validated_data):
        data = dict(validated_data)
        items_data = data.pop('items')
        requested_bonus_spent = data.pop('bonus_spent', 0)

        if not APP_BONUSES_ENABLED:
            requested_bonus_spent = 0

        phone = data['phone']
        customer_name = data.get('customer_name', '').strip()
        order_address = (data.get('address') or '').strip()
        delivery_type = data.get('delivery_type')

        if delivery_type != Order.DeliveryType.PICKUP:
            if not data.get('address_locality'):
                from orders.services import LOCALITY_BY_DELIVERY_TYPE

                data['address_locality'] = (
                    LOCALITY_BY_DELIVERY_TYPE.get(delivery_type, '')
                )

        customer = order.customer
        if customer is None:
            customer, _ = Customer.objects.get_or_create(
                phone=phone,
                defaults={
                    'name': customer_name,
                    'default_address': order_address
                    if delivery_type != Order.DeliveryType.PICKUP
                    else '',
                    'first_order_discount_available': APP_FIRST_ORDER_DISCOUNT_ENABLED,
                    'first_order_discount_used': False,
                },
            )
            order.customer = customer

        self._sync_customer_for_checkout(
            customer=customer,
            customer_name=customer_name,
            order_address=order_address,
            delivery_type=delivery_type,
        )

        pricing = self._calculate_order_pricing(
            customer=customer,
            items_data=items_data,
            delivery_type=delivery_type,
            requested_bonus_spent=requested_bonus_spent,
        )

        order.phone = phone
        order.customer_name = customer_name
        order.delivery_type = delivery_type
        order.address = data.get('address', '')
        order.address_locality = data.get('address_locality', '')
        order.address_entrance = data.get('address_entrance', '')
        order.address_floor = data.get('address_floor', '')
        order.address_apartment = data.get('address_apartment', '')
        order.delivery_time_type = data['delivery_time_type']
        order.delivery_time = data.get('delivery_time', '')
        order.payment_type = data['payment_type']
        order.comment = data.get('comment', '')
        order.products_total = pricing['products_total']
        order.delivery_price = pricing['delivery_price']
        order.discount_amount = pricing['discount_amount']
        order.bonus_spent = pricing['bonus_spent']
        order.bonus_earned = pricing['bonus_earned']
        order.first_order_discount_applied = pricing['first_order_discount_applied']
        order.total_price = pricing['total_price']
        order.payment_amount = pricing['total_price']
        order.status = Order.Status.NEW

        if order.payment_status == Order.PaymentStatus.FAILED:
            order.payment_status = Order.PaymentStatus.UNPAID

        order.save()
        return order

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        requested_bonus_spent = validated_data.pop('bonus_spent', 0)

        if not APP_BONUSES_ENABLED:
            requested_bonus_spent = 0

        phone = validated_data['phone']
        customer_name = validated_data.get('customer_name', '').strip()
        order_address = (validated_data.get('address') or '').strip()
        delivery_type = validated_data.get('delivery_type')

        if delivery_type != Order.DeliveryType.PICKUP:
            if not validated_data.get('address_locality'):
                from orders.services import LOCALITY_BY_DELIVERY_TYPE

                validated_data['address_locality'] = (
                    LOCALITY_BY_DELIVERY_TYPE.get(delivery_type, '')
                )

        customer, created = Customer.objects.get_or_create(
            phone=phone,
            defaults={
                'name': customer_name,
                'default_address': order_address
                if delivery_type != Order.DeliveryType.PICKUP
                else '',
                'first_order_discount_available': APP_FIRST_ORDER_DISCOUNT_ENABLED,
                'first_order_discount_used': False,
            },
        )

        self._sync_customer_for_checkout(
            customer=customer,
            customer_name=customer_name,
            order_address=order_address,
            delivery_type=delivery_type,
        )

        pricing = self._calculate_order_pricing(
            customer=customer,
            items_data=items_data,
            delivery_type=delivery_type,
            requested_bonus_spent=requested_bonus_spent,
        )

        order = Order.objects.create(
            **validated_data,
            customer=customer,
            products_total=pricing['products_total'],
            delivery_price=pricing['delivery_price'],
            discount_amount=pricing['discount_amount'],
            bonus_spent=pricing['bonus_spent'],
            bonus_earned=pricing['bonus_earned'],
            first_order_discount_applied=pricing['first_order_discount_applied'],
            total_price=pricing['total_price'],
            payment_status=Order.PaymentStatus.UNPAID,
            payment_amount=pricing['total_price'],
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

        customer_bonus_update_fields = []

        if pricing['first_order_discount_applied']:
            customer.first_order_discount_available = False
            customer.first_order_discount_used = True
            customer_bonus_update_fields.extend([
                'first_order_discount_available',
                'first_order_discount_used',
            ])

        if pricing['bonus_spent'] > 0:
            customer.bonus_balance -= pricing['bonus_spent']

            BonusTransaction.objects.create(
                customer=customer,
                transaction_type=BonusTransaction.TransactionType.SPEND,
                amount=-pricing['bonus_spent'],
                order_id=order.id,
                comment=f'Списание бонусов по заказу #{order.id}',
            )

        if pricing['bonus_earned'] > 0:
            customer.bonus_balance += pricing['bonus_earned']

            BonusTransaction.objects.create(
                customer=customer,
                transaction_type=BonusTransaction.TransactionType.EARN,
                amount=pricing['bonus_earned'],
                order_id=order.id,
                comment=f'Начисление бонусов по заказу #{order.id}',
            )

        if pricing['bonus_spent'] > 0 or pricing['bonus_earned'] > 0:
            customer_bonus_update_fields.append('bonus_balance')

        if customer_bonus_update_fields:
            customer_bonus_update_fields.append('updated_at')
            customer.save(
                update_fields=list(set(customer_bonus_update_fields)),
            )

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
    customer_id = serializers.IntegerField(
        source='customer.id',
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Order
        fields = (
            'id',
            'customer_id',
            'phone',
            'customer_name',
            'delivery_type',
            'address',
            'delivery_time_type',
            'delivery_time',
            'payment_type',
            'payment_status',
            'payment_amount',
            'payment_provider',
            'payment_external_id',
            'payment_url',
            'paid_at',
            'comment',
            'products_total',
            'delivery_price',
            'discount_amount',
            'bonus_spent',
            'bonus_earned',
            'first_order_discount_applied',
            'total_price',
            'status',
            'saby_order_number',
            'saby_sale_id',
            'saby_external_id',
            'created_at',
            'updated_at',
            'items',
        )
