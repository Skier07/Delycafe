from django.http import HttpResponse
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from customers.authentication import (
    CustomerTokenAuthentication,
    OrderAccessTokenAuthentication,
)
from customers.permissions import IsCustomerOrOrderAccess
from orders.models import Order

from .access import authorize_order_access
from .callback_handlers import (
    extract_alfa_callback_data,
    handle_alfa_callback,
    sync_order_from_return_url,
)
from .services import (
    AlfaPaymentError,
    create_alfa_payment,
    get_alfa_payment_status,
)


class AlfaCreatePaymentAPIView(APIView):
    authentication_classes = [
        CustomerTokenAuthentication,
        OrderAccessTokenAuthentication,
    ]
    permission_classes = [IsCustomerOrOrderAccess]

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
            authorize_order_access(request, order)
        except PermissionDenied as error:
            return Response(
                {'detail': str(error.detail if hasattr(error, 'detail') else error)},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            data = create_alfa_payment(order)
        except AlfaPaymentError:
            return Response(
                {'detail': 'Не удалось создать оплату. Попробуйте позже.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(data)


class AlfaPaymentStatusAPIView(APIView):
    authentication_classes = [
        CustomerTokenAuthentication,
        OrderAccessTokenAuthentication,
    ]
    permission_classes = [IsCustomerOrOrderAccess]

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
            authorize_order_access(request, order)
        except PermissionDenied as error:
            return Response(
                {'detail': str(error.detail if hasattr(error, 'detail') else error)},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            get_alfa_payment_status(order)
            order.refresh_from_db()
        except AlfaPaymentError:
            return Response(
                {'detail': 'Не удалось проверить оплату. Попробуйте позже.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                'order_id': order.id,
                'payment_status': order.payment_status,
                'status': order.status,
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
        data = extract_alfa_callback_data(request)
        result = handle_alfa_callback(data)

        if result.get('result') == 'not_found':
            return Response(
                {'detail': result.get('detail', 'Заказ не найден.')},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(result, status=status.HTTP_200_OK)


def payment_success(request):
    order = sync_order_from_return_url(request)

    if order is not None and order.payment_status == Order.PaymentStatus.PAID:
        message = (
            f'Оплата заказа №{order.id} прошла успешно. '
            'Можно вернуться в приложение.'
        )
    else:
        message = (
            'Оплата прошла успешно. Можно вернуться в приложение. '
            'Если статус в приложении не обновился, нажмите «Проверить оплату».'
        )

    return HttpResponse(message)


def payment_fail(request):
    return HttpResponse(
        'Оплата не была завершена. Можно вернуться в приложение.'
    )
