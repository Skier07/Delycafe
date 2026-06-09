from django.contrib import admin
from django.utils import timezone

from .models import Order, OrderItem


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    can_delete = False

    fields = (
        'product_title',
        'variant_title',
        'saby_id',
        'quantity',
        'price',
        'total_price',
    )

    readonly_fields = (
        'product_title',
        'variant_title',
        'saby_id',
        'quantity',
        'price',
        'total_price',
    )


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'phone',
        'customer_name',
        'customer',
        'delivery_type',
        'payment_type',
        'payment_status',
        'payment_amount',
        'products_total',
        'delivery_price',
        'discount_amount',
        'bonus_spent',
        'bonus_earned',
        'total_price',
        'status',
        'created_at',
    )

    list_display_links = (
        'id',
        'phone',
    )

    list_editable = (
        'payment_status',
        'status',
    )

    list_filter = (
        'status',
        'payment_status',
        'delivery_type',
        'payment_type',
        'first_order_discount_applied',
        'created_at',
    )

    search_fields = (
        'phone',
        'customer_name',
        'customer__phone',
        'customer__name',
        'address',
        'comment',
        'payment_external_id',
    )

    readonly_fields = (
        'customer',
        'phone',
        'customer_name',
        'delivery_type',
        'address',
        'delivery_time_type',
        'delivery_time',
        'payment_type',
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
        'created_at',
        'updated_at',
    )

    fieldsets = (
        (
            'Клиент',
            {
                'fields': (
                    'customer',
                    'phone',
                    'customer_name',
                ),
            },
        ),
        (
            'Доставка',
            {
                'fields': (
                    'delivery_type',
                    'address',
                    'delivery_time_type',
                    'delivery_time',
                ),
            },
        ),
        (
            'Оплата и сумма',
            {
                'fields': (
                    'payment_type',
                    'payment_status',
                    'payment_amount',
                    'payment_provider',
                    'payment_external_id',
                    'payment_url',
                    'paid_at',
                    'products_total',
                    'delivery_price',
                    'discount_amount',
                    'bonus_spent',
                    'bonus_earned',
                    'first_order_discount_applied',
                    'total_price',
                ),
            },
        ),
        (
            'Статус заказа',
            {
                'fields': (
                    'status',
                ),
            },
        ),
        (
            'Комментарий',
            {
                'fields': (
                    'comment',
                ),
            },
        ),
        (
            'Служебная информация',
            {
                'fields': (
                    'created_at',
                    'updated_at',
                ),
            },
        ),
    )

    actions = (
        'mark_as_paid',
        'mark_as_unpaid',
        'mark_as_failed',
        'mark_as_refunded',
    )

    inlines = [
        OrderItemInline,
    ]

    list_select_related = (
        'customer',
    )

    date_hierarchy = 'created_at'

    @admin.action(description='Пометить выбранные заказы как оплаченные')
    def mark_as_paid(self, request, queryset):
        updated_count = queryset.update(
            payment_status=Order.PaymentStatus.PAID,
            paid_at=timezone.now(),
        )

        self.message_user(
            request,
            f'Оплачено заказов: {updated_count}',
        )

    @admin.action(description='Пометить выбранные заказы как ожидающие оплаты')
    def mark_as_unpaid(self, request, queryset):
        updated_count = queryset.update(
            payment_status=Order.PaymentStatus.UNPAID,
            paid_at=None,
        )

        self.message_user(
            request,
            f'Заказов ожидают оплату: {updated_count}',
        )

    @admin.action(description='Пометить выбранные заказы как ошибка оплаты')
    def mark_as_failed(self, request, queryset):
        updated_count = queryset.update(
            payment_status=Order.PaymentStatus.FAILED,
            paid_at=None,
        )

        self.message_user(
            request,
            f'Заказов с ошибкой оплаты: {updated_count}',
        )

    @admin.action(description='Пометить выбранные заказы как возврат')
    def mark_as_refunded(self, request, queryset):
        updated_count = queryset.update(
            payment_status=Order.PaymentStatus.REFUNDED,
        )

        self.message_user(
            request,
            f'Заказов с возвратом: {updated_count}',
        )

    def save_model(self, request, obj, form, change):
        if obj.payment_status == Order.PaymentStatus.PAID and obj.paid_at is None:
            obj.paid_at = timezone.now()

        if obj.payment_status in (
            Order.PaymentStatus.UNPAID,
            Order.PaymentStatus.FAILED,
        ):
            obj.paid_at = None

        super().save_model(request, obj, form, change)


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'order',
        'product_title',
        'variant_title',
        'saby_id',
        'quantity',
        'price',
        'total_price',
    )

    search_fields = (
        'product_title',
        'variant_title',
        'saby_id',
        'order__phone',
    )

    list_filter = (
        'order__status',
        'order__payment_status',
    )

    list_select_related = (
        'order',
    )