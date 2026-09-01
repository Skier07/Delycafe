import json

from django import forms
from django.contrib import admin
from django.db import models as django_models
from django.utils.html import format_html, format_html_join

from .gallery import append_gallery_images
from .models import (
    CatalogSnippet,
    Category,
    InfoSectionDefinition,
    NewSabyProduct,
    Product,
    ProductGalleryImage,
    ProductInfoNote,
    ProductSnippet,
    ProductVariant,
)
from .widgets import InfoContentField, MultipleFileField, MultipleFileInput
from .snippets import attach_default_snippets


class ProductGalleryImageInline(admin.TabularInline):
    model = ProductGalleryImage
    extra = 0
    add_link_text = 'Добавить ещё одно фото товара'
    fields = (
        'preview',
        'image',
        'sort_order',
    )
    readonly_fields = ('preview',)
    ordering = ('sort_order', 'id')

    @admin.display(description='Превью')
    def preview(self, gallery_image):
        if not gallery_image.image:
            return '—'

        return format_html(
            '<img src="{}" alt="" class="product-gallery-inline-thumb" />',
            gallery_image.image.url,
        )


class ProductAdminForm(forms.ModelForm):
    extra_gallery_images = MultipleFileField(
        required=False,
        label='Загрузить несколько фото',
        widget=MultipleFileInput(
            attrs={
                'accept': 'image/*',
            },
        ),
        help_text='Выберите одно или несколько файлов. Они добавятся в галерею после сохранения.',
    )

    class Meta:
        model = Product
        fields = '__all__'


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


class ProductSnippetInline(admin.StackedInline):
    model = ProductSnippet
    extra = 0
    autocomplete_fields = ('snippet',)
    fields = (
        'snippet',
        'is_enabled',
        'override_content',
    )
    formfield_overrides = {
        django_models.JSONField: {'form_class': InfoContentField},
    }


class ProductInfoNoteInline(admin.StackedInline):
    model = ProductInfoNote
    extra = 0
    fields = (
        'info_section',
        'content',
        'style',
        'sort_order',
    )
    formfield_overrides = {
        django_models.JSONField: {'form_class': InfoContentField},
    }


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
    form = ProductAdminForm
    inlines = [
        ProductGalleryImageInline,
        ProductVariantInline,
        ProductSnippetInline,
        ProductInfoNoteInline,
    ]

    class Media:
        css = {
            'all': (
                'catalog/admin/product_gallery_admin.css',
                'catalog/admin/info_content_editor.css',
            ),
        }
        js = ('catalog/admin/info_content_editor.js',)

    actions = (
        'attach_standard_snippets',
    )

    def get_inline_formsets(self, request, formsets, inline_instances, obj=None):
        inline_admin_formsets = super().get_inline_formsets(
            request,
            formsets,
            inline_instances,
            obj,
        )

        for inline_formset in inline_admin_formsets:
            custom_add_text = getattr(inline_formset.opts, 'add_link_text', None)

            if not custom_add_text:
                continue

            original_inline_formset_data = inline_formset.inline_formset_data

            def patched_inline_formset_data(
                original=original_inline_formset_data,
                add_text=custom_add_text,
            ):
                payload = json.loads(original())
                payload['options']['addText'] = add_text
                return json.dumps(payload)

            inline_formset.inline_formset_data = patched_inline_formset_data

        return inline_admin_formsets

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

        uploaded_files = request.FILES.getlist('extra_gallery_images')
        created = append_gallery_images(obj, uploaded_files)

        if created:
            self.message_user(
                request,
                f'Добавлено фотографий: {created}',
            )

        if not change:
            attach_default_snippets(obj)

    @admin.display(description='Текущие фото')
    def gallery_preview(self, product):
        if not product.pk:
            return 'Сохраните товар, затем добавьте фото.'

        gallery_images = product.gallery_images.all()

        if not gallery_images:
            return 'Фотографии ещё не добавлены.'

        return format_html_join(
            '',
            '<img src="{}" alt="" class="product-gallery-preview-thumb" />',
            (
                (gallery_image.image.url,)
                for gallery_image in gallery_images
                if gallery_image.image
            ),
        )


@admin.register(Product)
class ProductAdmin(ProductAdminBase):
    readonly_fields = ('gallery_preview', 'image')
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
            'Фотографии',
            {
                'fields': (
                    'gallery_preview',
                    'extra_gallery_images',
                    'image',
                ),
                'description': (
                    'Первое фото в списке ниже — обложка в каталоге. '
                    'Можно загрузить несколько файлов одним выбором '
                    'или добавить по одному в таблице «Фото товара».'
                ),
            },
        ),
        (
            'Основное',
            {
                'fields': (
                    'category',
                    'manual_category',
                    'title',
                    'description',
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
        'gallery_preview',
        'extra_gallery_images',
        'image',
        'category',
        'manual_category',
        'title',
        'description',
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
        'gallery_preview',
        'image',
        'saby_id',
        'saby_name',
        'source',
        'created_at',
        'updated_at',
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


@admin.register(InfoSectionDefinition)
class InfoSectionDefinitionAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'code',
        'sort_order',
        'is_active',
    )
    list_editable = (
        'sort_order',
        'is_active',
    )
    search_fields = (
        'title',
        'code',
    )
    ordering = (
        'sort_order',
        'id',
    )


@admin.register(CatalogSnippet)
class CatalogSnippetAdmin(admin.ModelAdmin):
    class Media:
        css = {
            'all': ('catalog/admin/info_content_editor.css',),
        }
        js = ('catalog/admin/info_content_editor.js',)

    list_display = (
        'name',
        'info_section',
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
        'info_section',
        'style',
        'is_default',
        'default_for_category',
    )
    search_fields = (
        'name',
        'text',
    )
    autocomplete_fields = ('default_for_category',)
    formfield_overrides = {
        django_models.JSONField: {'form_class': InfoContentField},
    }
    fieldsets = (
        (
            'Основные',
            {
                'fields': (
                    'name',
                    'info_section',
                    'style',
                    'sort_order',
                ),
            },
        ),
        (
            'Текст для приложения',
            {
                'fields': (
                    'content',
                ),
            },
        ),
        (
            'Автоподключение',
            {
                'fields': (
                    'is_default',
                    'default_for_category',
                ),
            },
        ),
        (
            'Служебное',
            {
                'fields': (
                    'text',
                ),
                'classes': ('collapse',),
            },
        ),
    )
    readonly_fields = ('text',)
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
