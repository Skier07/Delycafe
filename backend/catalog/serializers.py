from rest_framework import serializers

from .models import Category, Product, ProductVariant
from .preorder import (
    cannot_order_message,
    format_cutoff_time,
    product_can_order_now,
)
from .snippets import resolve_info_blocks


class ProductVariantSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductVariant
        fields = (
            'id',
            'saby_id',
            'title',
            'price',
            'weight',
            'sort_order',
        )


class ProductSerializer(serializers.ModelSerializer):
    category = serializers.CharField(source='category.title')
    category_sort_order = serializers.IntegerField(
        source='category.sort_order',
        read_only=True,
    )
    category_preorder_cutoff_enabled = serializers.BooleanField(
        source='category.preorder_cutoff_enabled',
        read_only=True,
    )
    category_preorder_lead_days = serializers.IntegerField(
        source='category.preorder_lead_days',
        read_only=True,
    )
    category_preorder_cutoff_time = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    variants = serializers.SerializerMethodField()
    info_blocks = serializers.SerializerMethodField()
    can_order = serializers.SerializerMethodField()
    cannot_order_reason = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = (
            'id',
            'saby_id',
            'title',
            'category',
            'category_sort_order',
            'category_preorder_cutoff_enabled',
            'category_preorder_lead_days',
            'category_preorder_cutoff_time',
            'description',
            'image',
            'price',
            'weight',
            'is_new',
            'is_hit',
            'has_variants',
            'sort_order',
            'variants',
            'info_blocks',
            'can_order',
            'cannot_order_reason',
        )

    def get_category_preorder_cutoff_time(self, product):
        return format_cutoff_time(product.category.preorder_cutoff_time)

    def get_image(self, product):
        if not product.image:
            return ''

        request = self.context.get('request')

        if request is None:
            return product.image.url

        return request.build_absolute_uri(product.image.url)

    def get_variants(self, product):
        active_variants = getattr(product, 'active_variants', None)

        if active_variants is None:
            active_variants = product.variants.filter(
                is_active=True,
            ).order_by(
                'sort_order',
                'title',
            )

        return ProductVariantSerializer(
            active_variants,
            many=True,
        ).data

    def get_info_blocks(self, product):
        return resolve_info_blocks(product)

    def get_can_order(self, product):
        return product_can_order_now(product)

    def get_cannot_order_reason(self, product):
        if product_can_order_now(product):
            return ''

        return cannot_order_message(product.category)


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = (
            'id',
            'title',
            'slug',
            'sort_order',
            'preorder_cutoff_enabled',
            'preorder_lead_days',
            'preorder_cutoff_time',
        )

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['preorder_cutoff_time'] = format_cutoff_time(
            instance.preorder_cutoff_time,
        )
        return data