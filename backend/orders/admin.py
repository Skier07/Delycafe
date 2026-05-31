from django.contrib import admin

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
        'delivery_type',
        'payment_type',
        'products_total',
        'delivery_price',
        'total_price',
        'status',
        'created_at',
    )

    list_display_links = (
        'id',
        'phone',
    )

    list_editable = (
        'status',
    )

    list_filter = (
        'status',
        'delivery_type',
        'payment_type',
        'created_at',
    )

    search_fields = (
        'phone',
        'customer_name',
        'address',
        'comment',
    )

    readonly_fields = (
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
        'created_at',
        'updated_at',
    )

    fieldsets = (
        (
            'Клиент',
            {
                'fields': (
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
                    'products_total',
                    'delivery_price',
                    'total_price',
                ),
            },
        ),
        (
            'Статус',
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

    inlines = [
        OrderItemInline,
    ]


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
    )