from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from orders.models import Order
from .services import AlfaPaymentError, AlfaPaymentService


class CreateAlfaPaymentAPIView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        order_id = request.data.get('order_id')

        if not order_id:
            return Response(
                {
                    'detail': 'Не передан order_id.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response(
                {
                    'detail': 'Заказ не найден.',
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if order.payment_status == Order.PaymentStatus.PAID:
            return Response(
                {
                    'detail': 'Заказ уже оплачен.',
                    'order_id': order.id,
                    'payment_status': order.payment_status,
                    'payment_amount': order.payment_amount,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        service = AlfaPaymentService()

        try:
            result = service.create_payment_for_order(order)
        except AlfaPaymentError as error:
            return Response(
                {
                    'detail': str(error),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                'order_id': order.id,
                'payment_status': order.payment_status,
                'payment_amount': order.payment_amount,
                'payment_provider': order.payment_provider,
                'payment_external_id': result.payment_external_id,
                'payment_url': result.payment_url,
            },
            status=status.HTTP_201_CREATED,
        )


class AlfaPaymentStatusAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        order_id = request.query_params.get('order_id')

        if not order_id:
            return Response(
                {
                    'detail': 'Не передан order_id.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response(
                {
                    'detail': 'Заказ не найден.',
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        service = AlfaPaymentService()

        try:
            result = service.sync_order_payment_status(order)
        except AlfaPaymentError as error:
            return Response(
                {
                    'detail': str(error),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                'order_id': order.id,
                'payment_status': order.payment_status,
                'payment_amount': order.payment_amount,
                'payment_url': order.payment_url,
                'paid_at': order.paid_at,
                'bank_order_status': result.get('order_status'),
            }
        )


@method_decorator(csrf_exempt, name='dispatch')
class AlfaCallbackAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        return self._handle_callback(request)

    def post(self, request):
        return self._handle_callback(request)

    def _handle_callback(self, request):
        callback_data = {}

        callback_data.update(request.query_params.dict())

        if hasattr(request.data, 'dict'):
            callback_data.update(request.data.dict())
        elif isinstance(request.data, dict):
            callback_data.update(request.data)

        service = AlfaPaymentService()
        order = service.find_order_by_callback_data(callback_data)

        if order is None:
            return Response(
                {
                    'detail': 'Заказ по callback не найден.',
                    'received': callback_data,
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            result = service.sync_order_payment_status(order)
        except AlfaPaymentError as error:
            return Response(
                {
                    'detail': str(error),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                'ok': True,
                'order_id': order.id,
                'payment_status': order.payment_status,
                'bank_order_status': result.get('order_status'),
            }
        )


def payment_success_view(request):
    return HttpResponse(
        '''
        <!doctype html>
        <html lang="ru">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Оплата успешна</title>
        </head>
        <body style="font-family: Arial, sans-serif; padding: 32px;">
          <h2>Оплата прошла успешно</h2>
          <p>Можно вернуться в приложение DelyCafe.</p>
        </body>
        </html>
        '''
    )


def payment_fail_view(request):
    return HttpResponse(
        '''
        <!doctype html>
        <html lang="ru">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Оплата не прошла</title>
        </head>
        <body style="font-family: Arial, sans-serif; padding: 32px;">
          <h2>Оплата не прошла</h2>
          <p>Попробуйте снова или выберите другой способ оплаты.</p>
        </body>
        </html>
        '''
    )