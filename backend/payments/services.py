import json
import re
from decimal import Decimal
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

from django.conf import settings

from orders.models import Order
from orders.services import confirm_order_paid


class AlfaPaymentError(Exception):
    pass


def _alfa_post(url, payload):
    data = urlencode(payload).encode('utf-8')

    request = Request(
        url,
        data=data,
        headers={
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
        },
        method='POST',
    )

    try:
        with urlopen(request, timeout=20) as response:
            body = response.read().decode('utf-8')
    except HTTPError as error:
        body = error.read().decode('utf-8')
        raise AlfaPaymentError(f'HTTP ошибка Альфы: {error.code}. {body}') from error
    except URLError as error:
        raise AlfaPaymentError(f'Не удалось подключиться к Альфе: {error}') from error

    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        raise AlfaPaymentError(f'Альфа вернула не JSON: {body}') from error


def _alfa_response_error_message(response):
    if not isinstance(response, dict):
        return 'Альфа вернула неожиданный ответ'

    error_code = response.get('errorCode')
    if error_code is None:
        return None

    code = str(error_code).strip()
    if code in ('', '0'):
        return None

    return (
        response.get('errorMessage')
        or response.get('error_message')
        or str(response)
    )


def _raise_for_alfa_error(response):
    message = _alfa_response_error_message(response)
    if message:
        raise AlfaPaymentError(message)


def _get_register_url():
    return getattr(
        settings,
        'ALFA_REGISTER_URL',
        'https://payment.alfabank.ru/payment/rest/register.do',
    )


def _get_status_url():
    return getattr(
        settings,
        'ALFA_STATUS_URL',
        'https://payment.alfabank.ru/payment/rest/getOrderStatusExtended.do',
    )


def _amount_to_kopecks(value):
    amount = Decimal(str(value or 0))
    return int(amount * 100)


def _normalize_phone_for_alfa(phone):
    digits = re.sub(r'\D', '', phone or '')

    if len(digits) == 11 and digits.startswith('8'):
        digits = f'7{digits[1:]}'

    if len(digits) == 11 and digits.startswith('7'):
        return f'+{digits}'

    if len(digits) == 10:
        return f'+7{digits}'

    return digits


def _alfa_allowed_payment_ways(order):
    if order.payment_type == Order.PaymentType.SBP:
        return ['SBP_C2B']

    return ['CARD']


def create_alfa_payment(order):
    if not getattr(settings, 'ALFA_PAYMENT_ENABLED', False):
        raise AlfaPaymentError('Оплата через Альфа-Банк выключена в настройках.')

    login = getattr(settings, 'ALFA_API_LOGIN', '')
    password = getattr(settings, 'ALFA_API_PASSWORD', '')

    if not login or not password:
        raise AlfaPaymentError('Не указан ALFA_API_LOGIN или ALFA_API_PASSWORD.')

    amount_value = getattr(order, 'payment_amount', None) or getattr(order, 'total_price', 0)
    amount = _amount_to_kopecks(amount_value)

    if amount <= 0:
        raise AlfaPaymentError('Сумма заказа должна быть больше 0.')

    order_number = f'delycafe-{order.id}'

    payload = {
        'userName': login,
        'password': password,
        'orderNumber': order_number,
        'amount': amount,
        'returnUrl': getattr(settings, 'ALFA_RETURN_URL', ''),
        'failUrl': getattr(settings, 'ALFA_FAIL_URL', ''),
        'description': f'DelyCafe заказ №{order.id}',
        'pageView': 'MOBILE',
        'allowedPaymentWays': _alfa_allowed_payment_ways(order)[0],
    }

    callback_url = (getattr(settings, 'ALFA_CALLBACK_URL', '') or '').strip()
    if callback_url:
        payload['dynamicCallbackUrl'] = callback_url

    phone = _normalize_phone_for_alfa(order.phone)
    if phone:
        payload['phone'] = phone

    if order.payment_type == Order.PaymentType.SBP:
        json_params = {}

        customer_name = (order.customer_name or '').strip()
        if customer_name:
            json_params['sbpSenderFIO'] = customer_name[:200]

        if json_params:
            payload['jsonParams'] = json.dumps(json_params, ensure_ascii=False)

    response = _alfa_post(
        _get_register_url(),
        payload,
    )

    _raise_for_alfa_error(response)

    external_id = response.get('orderId')
    payment_url = response.get('formUrl')

    if not external_id or not payment_url:
        raise AlfaPaymentError(f'Альфа не вернула ссылку оплаты: {response}')

    order.payment_provider = 'alfa'
    order.payment_external_id = external_id
    order.payment_url = payment_url
    order.payment_status = 'unpaid'
    order.save(
        update_fields=[
            'payment_provider',
            'payment_external_id',
            'payment_url',
            'payment_status',
            'updated_at',
        ]
    )

    return {
        'order_id': order.id,
        'payment_url': payment_url,
        'external_id': external_id,
        'amount': amount_value,
        'raw': response,
    }


def get_alfa_payment_status(order):
    login = getattr(settings, 'ALFA_API_LOGIN', '')
    password = getattr(settings, 'ALFA_API_PASSWORD', '')

    if not login or not password:
        raise AlfaPaymentError('Не указан ALFA_API_LOGIN или ALFA_API_PASSWORD.')

    if not order.payment_external_id:
        raise AlfaPaymentError('У заказа нет payment_external_id.')

    response = _alfa_post(
        _get_status_url(),
        {
            'userName': login,
            'password': password,
            'orderId': order.payment_external_id,
        },
    )

    _raise_for_alfa_error(response)

    order_status = str(response.get('orderStatus', ''))

    if order_status == '2':
        confirm_order_paid(order)
    elif order_status in {'3', '4', '6'}:
        order.payment_status = 'failed'
        order.save(
            update_fields=[
                'payment_status',
                'updated_at',
            ]
        )

    return response
