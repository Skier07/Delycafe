from django.contrib import admin

from .models import (
    CatalogSnippet,
    Category,
    NewSabyProduct,
    Product,
    ProductInfoNote,
    ProductSnippet,
    ProductVariant,
)
from .snippets import attach_default_snippets


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


class ProductSnippetInline(admin.TabularInline):
    model = ProductSnippet
    extra = 0
    autocomplete_fields = ('snippet',)
    fields = (
        'snippet',
        'is_enabled',
        'override_text',
    )


class ProductInfoNoteInline(admin.TabularInline):
    model = ProductInfoNote
    extra = 0
    fields = (
        'section',
        'text',
        'style',
        'sort_order',
    )


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'saby_category_id',
        'slug',
        'sort_order',
        'show_in_app',
        'is_active',
        'preorder_cutoff_enabled',
        'preorder_lead_days',
        'preorder_cutoff_time',
    )

    list_editable = (
        'sort_order',
        'show_in_app',
        'is_active',
        'preorder_cutoff_enabled',
        'preorder_lead_days',
        'preorder_cutoff_time',
    )

    list_filter = (
        'show_in_app',
        'is_active',
    )

    search_fields = (
        'title',
        'slug',
        'saby_category_id',
    )

    fieldsets = (
        (
            None,
            {
                'fields': (
                    'title',
                    'slug',
                    'saby_category_id',
                    'sort_order',
                    'show_in_app',
                    'is_active',
                ),
            },
        ),
        (
            'Предзаказ',
            {
                'fields': (
                    'preorder_cutoff_enabled',
                    'preorder_lead_days',
                    'preorder_cutoff_time',
                ),
                'description': (
                    'Снимите галочку «Ограничение по времени заказа», чтобы отключить правило '
                    'для категории. Для пирогов: включено, 1 сутки, до 17:00 (время Урала).'
                ),
            },
        ),
    )

    actions = (
        'enable_in_app',
        'disable_in_app',
    )

    @admin.action(description='Показывать в приложении')
    def enable_in_app(self, request, queryset):
        updated = queryset.update(show_in_app=True)

        self.message_user(
            request,
            f'Включено категорий: {updated}',
        )

    @admin.action(description='Скрыть из приложения')
    def disable_in_app(self, request, queryset):
        updated = queryset.update(show_in_app=False)

        self.message_user(
            request,
            f'Скрыто категорий: {updated}',
        )


class ProductAdminBase(admin.ModelAdmin):
    inlines = [
        ProductVariantInline,
        ProductSnippetInline,
        ProductInfoNoteInline,
    ]

    actions = (
        'attach_standard_snippets',
    )

    @admin.action(description='Подключить стандартные текстовые блоки')
    def attach_standard_snippets(self, request, queryset):
        attached = 0

        for product in queryset:
            attached += attach_default_snippets(product)

        self.message_user(
            request,
            f'Добавлено связей с блоками: {attached}',
        )

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)

        if not change:
            attach_default_snippets(obj)


@admin.register(Product)
class ProductAdmin(ProductAdminBase):
    list_display = (
        'title',
        'category',
        'manual_category',
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
        'manual_category',
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
                    'manual_category',
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


@admin.register(NewSabyProduct)
class NewSabyProductAdmin(ProductAdminBase):
    list_display = (
        'title',
        'category',
        'manual_category',
        'saby_id',
        'price',
        'weight',
        'is_active',
        'needs_review',
        'created_at',
    )

    list_filter = (
        'category',
        'manual_category',
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
        'manual_category',
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
        'attach_standard_snippets',
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .filter(needs_review=True)
            .exclude(
                category__title__in=[
                    'Вода',
                    'Сырье',
                    'Колбаса',
                    'Мясо',
                    'Овощи, Фрукты',
                    'Пластиковая посуда',
                    'Мойка',
                    'Химия',
                    'Экспресс',
                    'Грузовые',
                    'Европа',
                    'Столовая',
                    'Бар',
                    'Пиццерия',
                    'Приправы',
                    'Соус Япония',
                    'Япония',
                    'Темпура',
                    'Холодные роллы',
                    'Запеченые роллы',
                    'Сеты',
                    'Доп услуги',
                    'Без категории',
                ]
            )
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


@admin.register(CatalogSnippet)
class CatalogSnippetAdmin(admin.ModelAdmin):
    list_display = (
        'name',
        'section',
        'style',
        'is_default',
        'default_for_category',
        'sort_order',
    )
    list_editable = (
        'is_default',
        'sort_order',
    )
    list_filter = (
        'section',
        'style',
        'is_default',
        'default_for_category',
    )
    search_fields = (
        'name',
        'text',
    )
    autocomplete_fields = ('default_for_category',)
    actions = (
        'attach_to_all_products',
        'disable_on_all_products',
    )

    @admin.action(description='Добавить ко всем товарам')
    def attach_to_all_products(self, request, queryset):
        created = 0

        product_ids = Product.objects.values_list('id', flat=True)

        for snippet in queryset:
            for product_id in product_ids:
                _, was_created = ProductSnippet.objects.get_or_create(
                    product_id=product_id,
                    snippet=snippet,
                    defaults={'is_enabled': True},
                )

                if was_created:
                    created += 1

        self.message_user(request, f'Добавлено товарам: {created}')

    @admin.action(description='Выключить у всех товаров')
    def disable_on_all_products(self, request, queryset):
        updated = ProductSnippet.objects.filter(
            snippet__in=queryset,
        ).update(is_enabled=False)

        self.message_user(request, f'Выключено связей: {updated}')
