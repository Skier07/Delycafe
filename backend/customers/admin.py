from django.contrib import admin

from .models import BonusTransaction, Customer


class BonusTransactionInline(admin.TabularInline):
    model = BonusTransaction
    extra = 0
    can_delete = False

    fields = (
        'transaction_type',
        'amount',
        'order_id',
        'comment',
        'created_at',
    )

    readonly_fields = (
        'transaction_type',
        'amount',
        'order_id',
        'comment',
        'created_at',
    )


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = (
        'phone',
        'name',
        'bonus_balance',
        'first_order_discount_available',
        'first_order_discount_used',
        'is_active',
        'created_at',
    )

    list_editable = (
        'bonus_balance',
        'first_order_discount_available',
        'first_order_discount_used',
        'is_active',
    )

    list_filter = (
        'first_order_discount_available',
        'first_order_discount_used',
        'is_active',
        'created_at',
    )

    search_fields = (
        'phone',
        'name',
    )

    readonly_fields = (
        'created_at',
        'updated_at',
    )

    fieldsets = (
        (
            'Клиент',
            {
                'fields': (
                    'phone',
                    'name',
                    'is_active',
                ),
            },
        ),
        (
            'Бонусы',
            {
                'fields': (
                    'bonus_balance',
                ),
            },
        ),
        (
            'Скидка первого заказа',
            {
                'fields': (
                    'first_order_discount_available',
                    'first_order_discount_used',
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
        BonusTransactionInline,
    ]


@admin.register(BonusTransaction)
class BonusTransactionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'customer',
        'transaction_type',
        'amount',
        'order_id',
        'created_at',
    )

    list_filter = (
        'transaction_type',
        'created_at',
    )

    search_fields = (
        'customer__phone',
        'customer__name',
        'comment',
        'order_id',
    )

    readonly_fields = (
        'created_at',
    )