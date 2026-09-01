from django.contrib import admin
from django.db import transaction
from django.utils import timezone
from orders.services import OrderReturnError, rollback_order, settle_order_return

from .models import Order, OrderItem, OrderReturn, OrderReturnItem, DeliveryZone, DeliveryInfoSection, DeliveryPriceTier


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


class OrderReturnInline(admin.TabularInline):
    model = OrderReturn
    extra = 0
    can_delete = False
    show_change_link = True

    fields = (
        'id',
        'products_total',
        'bonus_earned_reversed',
        'bonus_spent_restored',
        'bonuses_applied',
        'created_at',
    )

    readonly_fields = fields


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
        'saby_order_number',
        'saby_sale_id',
        'saby_payment_registered',
        'bonus_compensated',
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
        'bonus_compensated',
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
        'saby_order_number',
        'saby_sale_id',
        'saby_external_id',
        'saby_payment_registered',
        'saby_bonus_applied',
        'saby_dispatch_error',
        'saby_payment_error',
        'admin_email_sent_at',
        'paid_at',
        'comment',
        'products_total',
        'delivery_price',
        'discount_amount',
        'bonus_spent',
        'bonus_earned',
        'bonus_compensated',
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
                    'bonus_compensated',
                    'first_order_discount_applied',
                    'total_price',
                ),
            },
        ),
        (
            'Интеграция Saby',
            {
                'fields': (
                    'saby_order_number',
                    'saby_sale_id',
                    'saby_external_id',
                    'saby_payment_registered',
                    'saby_bonus_applied',
                    'saby_dispatch_error',
                    'saby_payment_error',
                    'admin_email_sent_at',
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
        OrderReturnInline,
    ]

    list_select_related = (
        'customer',
    )

    date_hierarchy = 'created_at'

    @admin.action(description='Пометить выбранные заказы как оплаченные')
    def mark_as_paid(self, request, queryset):
        from orders.services import confirm_order_paid

        updated_count = 0

        for order in queryset:
            confirm_order_paid(order)
            updated_count += 1

        self.message_user(
            request,
            f'Оплачено и отправлено в Saby (где возможно): {updated_count}',
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

    @admin.action(
        description='Полный возврат: refunded + отмена + откат бонусов',
    )
    def mark_as_refunded(self, request, queryset):
        updated_count = 0

        for order in queryset:
            with transaction.atomic():
                locked = Order.objects.select_for_update().get(pk=order.pk)
                locked.payment_status = Order.PaymentStatus.REFUNDED
                if locked.status != Order.Status.CANCELED:
                    locked.status = Order.Status.CANCELED
                locked.save(
                    update_fields=[
                        'payment_status',
                        'status',
                        'updated_at',
                    ],
                )
                rollback_order(locked)
                updated_count += 1

        self.message_user(
            request,
            f'Полный возврат с откатом бонусов: {updated_count}',
        )

    def save_model(self, request, obj, form, change):
        previous_status = None
        previous_payment = None

        if change:
            previous = (
                Order.objects.filter(pk=obj.pk)
                .values('status', 'payment_status')
                .first()
            )
            if previous:
                previous_status = previous['status']
                previous_payment = previous['payment_status']

        if (
            obj.payment_status == Order.PaymentStatus.PAID
            and obj.paid_at is None
        ):
            obj.paid_at = timezone.now()

        if obj.payment_status in (
            Order.PaymentStatus.UNPAID,
            Order.PaymentStatus.FAILED,
        ):
            obj.paid_at = None

        if (
            previous_payment != Order.PaymentStatus.REFUNDED
            and obj.payment_status == Order.PaymentStatus.REFUNDED
            and obj.status != Order.Status.CANCELED
        ):
            obj.status = Order.Status.CANCELED

        super().save_model(
            request,
            obj,
            form,
            change,
        )

        if (
            previous_status != Order.Status.CANCELED
            and obj.status == Order.Status.CANCELED
        ):
            rollback_order(obj)
        elif (
            previous_payment != Order.PaymentStatus.REFUNDED
            and obj.payment_status == Order.PaymentStatus.REFUNDED
        ):
            rollback_order(obj)


class OrderReturnItemInline(admin.TabularInline):
    model = OrderReturnItem
    extra = 1

    fields = (
        'order_item',
        'quantity',
        'product_title',
        'price',
        'total_price',
    )

    readonly_fields = (
        'product_title',
        'price',
        'total_price',
    )

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        field = super().formfield_for_foreignkey(db_field, request, **kwargs)
        if db_field.name == 'order_item' and field is not None:
            order_id = request.resolver_match.kwargs.get('object_id')
            parent_order = request.GET.get('order')
            if parent_order:
                field.queryset = OrderItem.objects.filter(order_id=parent_order)
            elif order_id:
                try:
                    ret = OrderReturn.objects.get(pk=order_id)
                    field.queryset = OrderItem.objects.filter(
                        order_id=ret.order_id,
                    )
                except OrderReturn.DoesNotExist:
                    pass
        return field


@admin.register(OrderReturn)
class OrderReturnAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'order',
        'products_total',
        'bonus_earned_reversed',
        'bonus_spent_restored',
        'bonuses_applied',
        'created_at',
    )
    list_filter = ('bonuses_applied', 'created_at')
    search_fields = ('order__id', 'order__phone', 'comment')
    readonly_fields = (
        'products_total',
        'bonus_earned_reversed',
        'bonus_spent_restored',
        'bonuses_applied',
        'created_at',
    )
    autocomplete_fields = ('order',)
    inlines = [OrderReturnItemInline]

    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        order_return = form.instance
        if order_return.bonuses_applied:
            return

        for row in order_return.items.select_related('order_item'):
            if row.order_item_id and (
                not row.product_title or row.price == 0
            ):
                item = row.order_item
                row.product_title = item.product_title
                row.price = item.price
                row.total_price = item.price * row.quantity
                row.save(
                    update_fields=[
                        'product_title',
                        'price',
                        'total_price',
                    ],
                )

        try:
            settle_order_return(order_return)
        except OrderReturnError as exc:
            self.message_user(request, str(exc), level='ERROR')
        except Exception as exc:
            self.message_user(
                request,
                f'Не удалось применить бонусы возврата: {exc}',
                level='ERROR',
            )


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


class DeliveryPriceTierInline(admin.TabularInline):
    model = DeliveryPriceTier
    extra = 1
    ordering = ('sort_order', 'min_cart_total')
    fields = (
        'min_cart_total',
        'price',
        'sort_order',
    )


@admin.register(DeliveryZone)
class DeliveryZoneAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'code',
        'pricing_mode',
        'fixed_price',
        'requires_address',
        'is_active',
        'sort_order',
    )
    list_editable = (
        'is_active',
        'sort_order',
    )
    list_filter = (
        'is_active',
        'pricing_mode',
        'requires_address',
    )
    search_fields = (
        'title',
        'code',
    )
    ordering = (
        'sort_order',
        'id',
    )
    inlines = [DeliveryPriceTierInline]
    fieldsets = (
        (
            'Основные',
            {
                'fields': (
                    'title',
                    'code',
                    'is_active',
                    'sort_order',
                ),
            },
        ),
        (
            'Тариф',
            {
                'fields': (
                    'pricing_mode',
                    'fixed_price',
                ),
            },
        ),
        (
            'Оформление заказа',
            {
                'fields': (
                    'requires_address',
                    'default_locality',
                    'lead_minutes',
                    'checkout_description',
                ),
            },
        ),
    )


@admin.register(DeliveryInfoSection)
class DeliveryInfoSectionAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'section_type',
        'is_active',
        'sort_order',
    )
    list_editable = (
        'is_active',
        'sort_order',
    )
    list_filter = (
        'section_type',
        'is_active',
    )
    search_fields = (
        'title',
        'content',
    )
    ordering = (
        'sort_order',
        'id',
    )
