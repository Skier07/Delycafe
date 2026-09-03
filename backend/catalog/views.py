from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ReadOnlyModelViewSet

from .content_serializers import AppPageContentSerializer, ContentPostSerializer
from .models import (
    AppPageContent,
    Category,
    ContentPost,
    Product,
    ProductGalleryImage,
    ProductInfoNote,
    ProductSnippet,
    ProductVariant,
)
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
        gallery_images = ProductGalleryImage.objects.order_by(
            'sort_order',
            'id',
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
                    'gallery_images',
                    queryset=gallery_images,
                    to_attr='prefetched_gallery_images',
                ),
                Prefetch(
                    'product_snippets',
                    queryset=ProductSnippet.objects.select_related(
                        'snippet',
                        'snippet__info_section',
                    ),
                    to_attr='prefetched_snippets',
                ),
                Prefetch(
                    'info_notes',
                    queryset=ProductInfoNote.objects.select_related(
                        'info_section',
                    ),
                    to_attr='prefetched_notes',
                ),
            )
            .select_related('category')
        )


class ContentPostViewSet(ReadOnlyModelViewSet):
    serializer_class = ContentPostSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        queryset = ContentPost.objects.filter(is_published=True)

        post_type = self.request.query_params.get('type')
        if post_type in {
            ContentPost.PostType.NEWS,
            ContentPost.PostType.PROMO,
        }:
            queryset = queryset.filter(post_type=post_type)

        return queryset


class AppPageContentAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, key):
        page = get_object_or_404(AppPageContent, key=key)
        return Response(
            AppPageContentSerializer(page, context={'request': request}).data,
        )
