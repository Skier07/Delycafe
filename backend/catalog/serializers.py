from rest_framework import serializers

from .models import Category, Product, ProductGalleryImage, ProductVariant
from .preorder import (
    cannot_order_message,
    format_cutoff_time,
    product_can_order_now,
)
from .snippets import resolve_info_blocks


def build_absolute_media_url(request, file_field):
    if not file_field:
        return ''

    if request is None:
        return file_field.url

    return request.build_absolute_uri(file_field.url)


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
    images = serializers.SerializerMethodField()
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
            'images',
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

    def _gallery_image_urls(self, product):
        gallery_images = getattr(product, 'prefetched_gallery_images', None)

        if gallery_images is None:
            gallery_images = product.gallery_images.all()

        request = self.context.get('request')

        return [
            build_absolute_media_url(request, gallery_image.image)
            for gallery_image in gallery_images
            if gallery_image.image
        ]

    def get_image(self, product):
        urls = self._gallery_image_urls(product)

        if urls:
            return urls[0]

        return build_absolute_media_url(self.context.get('request'), product.image)

    def get_images(self, product):
        urls = self._gallery_image_urls(product)

        if urls:
            return urls

        cover = build_absolute_media_url(self.context.get('request'), product.image)

        if cover:
            return [cover]

        return []

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