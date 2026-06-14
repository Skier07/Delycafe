from django.urls import path

from .views import (
    AlfaCallbackAPIView,
    AlfaPaymentStatusAPIView,
    CreateAlfaPaymentAPIView,
    payment_fail_view,
    payment_success_view,
)


urlpatterns = [
    path(
        'alfa/create/',
        CreateAlfaPaymentAPIView.as_view(),
        name='alfa-payment-create',
    ),
    path(
        'alfa/status/',
        AlfaPaymentStatusAPIView.as_view(),
        name='alfa-payment-status',
    ),
    path(
        'alfa/callback/',
        AlfaCallbackAPIView.as_view(),
        name='alfa-payment-callback',
    ),
    path(
        'success/',
        payment_success_view,
        name='payment-success',
    ),
    path(
        'fail/',
        payment_fail_view,
        name='payment-fail',
    ),
]