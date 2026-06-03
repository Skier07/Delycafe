from rest_framework import serializers

from .models import Category, Product, ProductVariant


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
    image = serializers.SerializerMethodField()
    variants = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = (
            'id',
            'saby_id',
            'title',
            'category',
            'category_sort_order',
            'description',
            'image',
            'price',
            'weight',
            'is_new',
            'is_hit',
            'has_variants',
            'sort_order',
            'variants',
        )

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


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = (
            'id',
            'title',
            'slug',
            'sort_order',
        )