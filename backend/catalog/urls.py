from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    AppPageContentAPIView,
    CategoryViewSet,
    ContentPostViewSet,
    ProductViewSet,
)

router = DefaultRouter()
router.register('categories', CategoryViewSet, basename='categories')
router.register('products', ProductViewSet, basename='products')
router.register('content', ContentPostViewSet, basename='content')

urlpatterns = [
    path(
        'pages/<slug:key>/',
        AppPageContentAPIView.as_view(),
        name='app-page-content',
    ),
    path('', include(router.urls)),
]
