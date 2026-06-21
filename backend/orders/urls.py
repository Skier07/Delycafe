from django.urls import path

from .history_views import OrderHistoryAPIView
from .views import OrderCreateAPIView


urlpatterns = [
    path('', OrderCreateAPIView.as_view(), name='order-create'),
    path('history/', OrderHistoryAPIView.as_view(), name='order-history'),
]
