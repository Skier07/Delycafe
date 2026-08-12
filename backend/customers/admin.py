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
        'saby_external_id',
        'saby_synced_at',
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
                    'saby_external_id',
                    'saby_customer_id',
                    'saby_synced_at',
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

    readonly_fields = (
        'saby_synced_at',
        'created_at',
        'updated_at',
    )

    actions = ('sync_bonus_balance_from_saby',)

    @admin.action(description='Подтянуть баланс бонусов из Saby')
    def sync_bonus_balance_from_saby(self, request, queryset):
        from customers.services.saby_customer_service import (
            sync_customer_from_saby,
        )

        ok = 0
        fail = 0

        for customer in queryset:
            try:
                synced = sync_customer_from_saby(
                    customer.phone,
                    existing_customer=customer,
                    update_bonus_balance=True,
                )
                if synced is None:
                    fail += 1
                else:
                    ok += 1
            except Exception:
                fail += 1

        self.message_user(
            request,
            f'Синхронизация баланса из Saby (нужен UUID): '
            f'успешно={ok}, без данных/ошибка={fail}. '
            f'По телефону API баланса у Saby нет — обычно правьте вручную.',
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