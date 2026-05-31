from rest_framework.viewsets import ReadOnlyModelViewSet

from .models import Category, Product
from .serializers import CategorySerializer, ProductSerializer


class CategoryViewSet(ReadOnlyModelViewSet):
    serializer_class = CategorySerializer

    def get_queryset(self):
        return Category.objects.filter(is_active=True)


class ProductViewSet(ReadOnlyModelViewSet):
    serializer_class = ProductSerializer

    def get_queryset(self):
        return (
            Product.objects
            .filter(is_active=True, category__is_active=True)
            .prefetch_related('variants')
            .select_related('category')
        )