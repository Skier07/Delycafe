import json
import logging
from dataclasses import dataclass
from typing import Any

import requests
from django.conf import settings
from django.utils import timezone

from orders.models import Order


logger = logging.getLogger(__name__)


class AlfaPaymentError(Exception):
    pass


@dataclass
class AlfaPaymentResult:
    payment_external_id: str
    payment_url: str
    raw_response: dict[str, Any]


class AlfaPaymentService:
    DEFAULT_BASE_URL = 'https://payment.alfabank.ru/payment/rest'

    PAID_STATUS = 2
    REFUNDED_STATUS = 4
    DECLINED_STATUS = 6
    REVERSED_STATUS = 3

    def __init__(self):
        self.enabled = getattr(settings, 'ALFA_PAYMENT_ENABLED', False)
        self.base_url = getattr(
            settings,
            'ALFA_API_BASE_URL',
            self.DEFAULT_BASE_URL,
        ).rstrip('/')

        self.login = getattr(settings, 'ALFA_API_LOGIN', '')
        self.password = getattr(settings, 'ALFA_API_PASSWORD', '')

        self.return_url = getattr(settings, 'ALFA_RETURN_URL', '')
        self.fail_url = getattr(settings, 'ALFA_FAIL_URL', '')
        self.callback_url = getattr(settings, 'ALFA_CALLBACK_URL', '')

    def create_payment_for_order(self, order: Order) -> AlfaPaymentResult:
        self._ensure_ready()

        if order.payment_amount <= 0:
            order.payment_amount = order.total_price
            order.save(update_fields=['payment_amount'])

        if order.payment_amount <= 0:
            raise AlfaPaymentError('Сумма оплаты должна быть больше 0.')

        if order.payment_url and order.payment_external_id:
            return AlfaPaymentResult(
                payment_external_id=order.payment_external_id,
                payment_url=order.payment_url,
                raw_response={
                    'cached': True,
                    'orderId': order.payment_external_id,
                    'formUrl': order.payment_url,
                },
            )

        amount_in_kopecks = order.payment_amount * 100
        order_number = self._make_order_number(order)

        payload = {
            'userName': self.login,
            'password': self.password,
            'orderNumber': order_number,
            'amount': amount_in_kopecks,
            'returnUrl': self.return_url,
            'failUrl': self.fail_url,
            'description': f'DelyCafe заказ #{order.id}',
            'clientId': order.phone,
            'jsonParams': json.dumps(
                {
                    'django_order_id': order.id,
                    'phone': order.phone,
                },
                ensure_ascii=False,
            ),
        }

        if self.callback_url:
            payload['dynamicCallbackUrl'] = self.callback_url

        data = self._post(
            method_name='register.do',
            payload=payload,
        )

        payment_external_id = data.get('orderId', '')
        payment_url = data.get('formUrl', '')

        if not payment_external_id or not payment_url:
            raise AlfaPaymentError(
                f'Банк не вернул orderId/formUrl: {data}'
            )

        order.payment_provider = 'alfa'
        order.payment_external_id = payment_external_id
        order.payment_url = payment_url
        order.payment_status = Order.PaymentStatus.UNPAID
        order.payment_amount = order.total_price

        order.save(
            update_fields=[
                'payment_provider',
                'payment_external_id',
                'payment_url',
                'payment_status',
                'payment_amount',
                'updated_at',
            ]
        )

        return AlfaPaymentResult(
            payment_external_id=payment_external_id,
            payment_url=payment_url,
            raw_response=data,
        )

    def sync_order_payment_status(self, order: Order) -> dict[str, Any]:
        self._ensure_ready()

        payload = {
            'userName': self.login,
            'password': self.password,
        }

        if order.payment_external_id:
            payload['orderId'] = order.payment_external_id
        else:
            payload['orderNumber'] = self._make_order_number(order)

        data = self._post(
            method_name='getOrderStatusExtended.do',
            payload=payload,
        )

        order_status = self._extract_order_status(data)

        if order_status == self.PAID_STATUS:
            order.payment_status = Order.PaymentStatus.PAID

            if order.paid_at is None:
                order.paid_at = timezone.now()

        elif order_status == self.REFUNDED_STATUS:
            order.payment_status = Order.PaymentStatus.REFUNDED

        elif order_status in (
            self.DECLINED_STATUS,
            self.REVERSED_STATUS,
        ):
            order.payment_status = Order.PaymentStatus.FAILED
            order.paid_at = None

        else:
            order.payment_status = Order.PaymentStatus.UNPAID

        order.save(
            update_fields=[
                'payment_status',
                'paid_at',
                'updated_at',
            ]
        )

        return {
            'order_status': order_status,
            'payment_status': order.payment_status,
            'raw_response': data,
        }

    def find_order_by_callback_data(
        self,
        callback_data: dict[str, Any],
    ) -> Order | None:
        external_id = (
            callback_data.get('mdOrder')
            or callback_data.get('orderId')
            or callback_data.get('order_id')
        )

        if external_id:
            order = Order.objects.filter(
                payment_external_id=str(external_id),
            ).first()

            if order:
                return order

        order_number = (
            callback_data.get('orderNumber')
            or callback_data.get('order_number')
        )

        if order_number:
            order_id = self._extract_order_id_from_order_number(
                str(order_number),
            )

            if order_id is not None:
                return Order.objects.filter(id=order_id).first()

        return None

    def _post(
        self,
        method_name: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        url = f'{self.base_url}/{method_name}'

        try:
            response = requests.post(
                url,
                data=payload,
                timeout=25,
            )
            response.raise_for_status()
        except requests.RequestException as error:
            logger.exception('Ошибка запроса к Альфа-Банку')
            raise AlfaPaymentError(
                f'Не удалось обратиться к Альфа-Банку: {error}'
            ) from error

        try:
            data = response.json()
        except ValueError as error:
            raise AlfaPaymentError(
                f'Банк вернул не JSON: {response.text}'
            ) from error

        error_code = data.get('errorCode')

        if error_code not in (None, 0, '0'):
            error_message = (
                data.get('errorMessage')
                or data.get('error')
                or 'Неизвестная ошибка Альфа-Банка'
            )

            raise AlfaPaymentError(
                f'Ошибка Альфа-Банка {error_code}: {error_message}'
            )

        return data

    def _ensure_ready(self):
        if not self.enabled:
            raise AlfaPaymentError(
                'Оплата через Альфа-Банк отключена. '
                'Установи ALFA_PAYMENT_ENABLED=True.'
            )

        if not self.login:
            raise AlfaPaymentError('Не задан ALFA_API_LOGIN.')

        if not self.password:
            raise AlfaPaymentError('Не задан ALFA_API_PASSWORD.')

        if not self.return_url:
            raise AlfaPaymentError('Не задан ALFA_RETURN_URL.')

        if not self.fail_url:
            raise AlfaPaymentError('Не задан ALFA_FAIL_URL.')

    def _make_order_number(self, order: Order) -> str:
        return f'delycafe-{order.id}'

    def _extract_order_id_from_order_number(
        self,
        order_number: str,
    ) -> int | None:
        prefix = 'delycafe-'

        if not order_number.startswith(prefix):
            return None

        raw_id = order_number.replace(prefix, '', 1)

        try:
            return int(raw_id)
        except ValueError:
            return None

    def _extract_order_status(self, data: dict[str, Any]) -> int | None:
        raw_status = (
            data.get('orderStatus')
            or data.get('OrderStatus')
            or data.get('order_status')
        )

        if raw_status is None:
            return None

        try:
            return int(raw_status)
        except (TypeError, ValueError):
            return None