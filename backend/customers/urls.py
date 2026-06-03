from django.urls import path

from .views import CustomerProfileAPIView


urlpatterns = [
    path('profile/', CustomerProfileAPIView.as_view(), name='customer-profile'),
]