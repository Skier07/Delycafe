from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from orders.models import Order

from .services import (
    AlfaPaymentError,
    create_alfa_payment,
    get_alfa_payment_status,
)


class AlfaCreatePaymentAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        order_id = request.data.get('order_id')

        if not order_id:
            return Response(
                {'detail': 'Не передан order_id.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = Order.objects.filter(id=order_id).first()

        if order is None:
            return Response(
                {'detail': 'Заказ не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            data = create_alfa_payment(order)
        except AlfaPaymentError as error:
            return Response(
                {'detail': str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(data)


class AlfaPaymentStatusAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        order_id = request.query_params.get('order_id')

        if not order_id:
            return Response(
                {'detail': 'Не передан order_id.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = Order.objects.filter(id=order_id).first()

        if order is None:
            return Response(
                {'detail': 'Заказ не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            alfa_status = get_alfa_payment_status(order)
        except AlfaPaymentError as error:
            return Response(
                {'detail': str(error)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                'order_id': order.id,
                'payment_status': order.payment_status,
                'status': order.status,
                'alfa': alfa_status,
            }
        )


class AlfaCallbackAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        return self._handle_callback(request)

    def post(self, request):
        return self._handle_callback(request)

    def _handle_callback(self, request):
        data = request.data.copy()

        if not data:
            data = request.query_params.copy()

        external_id = (
            data.get('mdOrder')
            or data.get('orderId')
            or data.get('order_id')
        )

        order_number = data.get('orderNumber') or data.get('order_number')

        order = None

        if external_id:
            order = Order.objects.filter(
                payment_external_id=external_id,
            ).first()

        if order is None and order_number:
            clean_number = str(order_number).replace('delycafe-', '')

            if clean_number.isdigit():
                order = Order.objects.filter(
                    id=int(clean_number),
                ).first()

        if order is None:
            return Response(
                {'detail': 'Заказ не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        operation = str(data.get('operation') or '').lower()
        callback_status = str(data.get('status') or '')

        if operation in {'deposited', 'approved'} or callback_status == '1':
            order.payment_status = 'paid'
            order.status = 'accepted'
            order.paid_at = timezone.now()
            order.save(
                update_fields=[
                    'payment_status',
                    'status',
                    'paid_at',
                    'updated_at',
                ]
            )

        return Response({'result': 'ok'})


def payment_success(request):
    return HttpResponse(
        'Оплата прошла успешно. Можно вернуться в приложение.'
    )


def payment_fail(request):
    return HttpResponse(
        'Оплата не была завершена. Можно вернуться в приложение.'
    )
