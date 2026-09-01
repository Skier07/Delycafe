from django.db.models import Prefetch
from rest_framework.viewsets import ReadOnlyModelViewSet

from .models import Category, Product, ProductInfoNote, ProductSnippet, ProductVariant
from .serializers import CategorySerializer, ProductSerializer


class CategoryViewSet(ReadOnlyModelViewSet):
    serializer_class = CategorySerializer

    def get_queryset(self):
        return Category.objects.filter(
            is_active=True,
            show_in_app=True,
        )


class ProductViewSet(ReadOnlyModelViewSet):
    serializer_class = ProductSerializer

    def get_queryset(self):
        active_variants = ProductVariant.objects.filter(
            is_active=True,
        ).order_by(
            'sort_order',
            'title',
        )

        return (
            Product.objects.filter(
                is_active=True,
                category__is_active=True,
                category__show_in_app=True,
            )
            .prefetch_related(
                Prefetch(
                    'variants',
                    queryset=active_variants,
                    to_attr='active_variants',
                ),
                Prefetch(
                    'product_snippets',
                    queryset=ProductSnippet.objects.select_related('snippet'),
                    to_attr='prefetched_snippets',
                ),
                Prefetch(
                    'info_notes',
                    queryset=ProductInfoNote.objects.all(),
                    to_attr='prefetched_notes',
                ),
            )
            .select_related('category')
        )
