from django.urls import path

from .delivery_views import DeliveryConfigAPIView
from .history_views import OrderHistoryAPIView
from .views import OrderCreateAPIView


urlpatterns = [
    path('', OrderCreateAPIView.as_view(), name='order-create'),
    path('history/', OrderHistoryAPIView.as_view(), name='order-history'),
    path(
        'delivery-config/',
        DeliveryConfigAPIView.as_view(),
        name='delivery-config',
    ),
]
