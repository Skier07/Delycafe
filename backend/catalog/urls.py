from .food_phrase_views import FoodPhraseView
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
    path('food-phrases/', FoodPhraseView.as_view(), name='food-phrases'),
    path(
        'pages/<slug:key>/',
        AppPageContentAPIView.as_view(),
        name='app-page-content',
    ),
    path('', include(router.urls)),
]
