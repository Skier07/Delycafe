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
    image = serializers.SerializerMethodField()
    variants = ProductVariantSerializer(many=True, read_only=True)

    class Meta:
        model = Product
        fields = (
            'id',
            'saby_id',
            'title',
            'category',
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


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = (
            'id',
            'title',
            'slug',
            'sort_order',
        )