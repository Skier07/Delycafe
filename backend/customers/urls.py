from django.urls import path

from .views import (
    CustomerAddressDetailAPIView,
    CustomerAddressesAPIView,
    CustomerBonusesAPIView,
    CustomerProfileAPIView,
    SetDefaultAddressAPIView,
)


urlpatterns = [
    path(
        'profile/',
        CustomerProfileAPIView.as_view(),
        name='customer-profile',
    ),
    path(
        'bonuses/',
        CustomerBonusesAPIView.as_view(),
        name='customer-bonuses',
    ),
    path(
        'addresses/',
        CustomerAddressesAPIView.as_view(),
        name='customer-addresses',
    ),
    path(
        'addresses/<int:address_id>/',
        CustomerAddressDetailAPIView.as_view(),
        name='customer-address-detail',
    ),
    path(
        'addresses/<int:address_id>/set-default/',
        SetDefaultAddressAPIView.as_view(),
        name='customer-address-set-default',
    ),
]
