from django.contrib import admin

from .models import Category, NewSabyProduct, Product, ProductVariant


class ProductVariantInline(admin.TabularInline):
    model = ProductVariant
    extra = 0
    fields = (
        'title',
        'saby_id',
        'saby_name',
        'price',
        'weight',
        'sort_order',
        'is_active',
    )


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'slug',
        'sort_order',
        'is_active',
    )
    list_editable = (
        'sort_order',
        'is_active',
    )
    search_fields = (
        'title',
        'slug',
    )


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'category',
        'saby_id',
        'price',
        'weight',
        'source',
        'needs_review',
        'is_hit',
        'is_new',
        'is_active',
        'has_variants',
        'sort_order',
    )

    list_editable = (
        'price',
        'weight',
        'needs_review',
        'is_hit',
        'is_new',
        'is_active',
        'sort_order',
    )

    list_filter = (
        'category',
        'source',
        'needs_review',
        'is_active',
        'is_hit',
        'is_new',
        'has_variants',
    )

    search_fields = (
        'title',
        'saby_name',
        'description',
        'saby_id',
    )

    fieldsets = (
        (
            'Основное',
            {
                'fields': (
                    'category',
                    'title',
                    'description',
                    'image',
                ),
            },
        ),
        (
            'Saby',
            {
                'fields': (
                    'saby_id',
                    'saby_name',
                    'source',
                    'needs_review',
                ),
            },
        ),
        (
            'Цена и вес',
            {
                'fields': (
                    'price',
                    'weight',
                    'has_variants',
                ),
            },
        ),
        (
            'Витрина приложения',
            {
                'fields': (
                    'is_active',
                    'is_hit',
                    'is_new',
                    'sort_order',
                ),
            },
        ),
    )

    inlines = [
        ProductVariantInline,
    ]


@admin.register(NewSabyProduct)
class NewSabyProductAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'category',
        'saby_id',
        'price',
        'weight',
        'is_active',
        'needs_review',
        'created_at',
    )

    list_filter = (
        'category',
        'is_active',
        'needs_review',
        'created_at',
    )

    search_fields = (
        'title',
        'saby_name',
        'saby_id',
    )

    fields = (
        'category',
        'title',
        'description',
        'image',
        'saby_id',
        'saby_name',
        'source',
        'needs_review',
        'price',
        'weight',
        'has_variants',
        'is_active',
        'is_hit',
        'is_new',
        'sort_order',
    )

    readonly_fields = (
        'saby_id',
        'saby_name',
        'source',
    )

    actions = (
        'publish_products',
    )

    inlines = [
        ProductVariantInline,
    ]

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(needs_review=True)
        )

    @admin.action(description='Опубликовать выбранные товары')
    def publish_products(self, request, queryset):
        updated_count = queryset.update(
            is_active=True,
            needs_review=False,
        )

        self.message_user(
            request,
            f'Опубликовано товаров: {updated_count}',
        )

    def save_model(self, request, obj, form, change):
        if obj.is_active:
            obj.needs_review = False

        super().save_model(request, obj, form, change)