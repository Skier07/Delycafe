from django.urls import path

from .views import (
    AlfaCallbackAPIView,
    AlfaCreatePaymentAPIView,
    AlfaPaymentStatusAPIView,
    payment_fail,
    payment_success,
)

urlpatterns = [
    path('alfa/create/', AlfaCreatePaymentAPIView.as_view(), name='alfa-create-payment'),
    path('alfa/status/', AlfaPaymentStatusAPIView.as_view(), name='alfa-payment-status'),
    path('alfa/callback/', AlfaCallbackAPIView.as_view(), name='alfa-callback'),
    path('success/', payment_success, name='payment-success'),
    path('fail/', payment_fail, name='payment-fail'),
]
