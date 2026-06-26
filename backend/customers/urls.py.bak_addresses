from django.urls import path

from .views import CustomerBonusesAPIView, CustomerProfileAPIView


urlpatterns = [
    path('profile/', CustomerProfileAPIView.as_view(), name='customer-profile'),
    path('bonuses/', CustomerBonusesAPIView.as_view(), name='customer-bonuses'),
]