import json
import logging
import re
from decimal import Decimal
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

from django.conf import settings

from orders.models import Order
from orders.services import confirm_order_paid, rollback_order

logger = logging.getLogger(__name__)

# 0 — создан, 1/5 — в процессе оплаты, 2 — оплачен,
# 3/4/6 — отменён, отклонён, истёк.
_ALFA_PAYABLE_ORDER_STATUSES = {'0', '1', '5'}
_ALFA_PAID_ORDER_STATUS = '2'
_ALFA_EXPIRED_ORDER_STATUSES = {'3', '4', '6'}
_ALFA_EXPIRED_ACTION_CODES = {'-2007', '-2014'}


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


def _is_duplicate_alfa_order_number_error(message):
    if not message:
        return False

    lowered = message.lower()
    return (
        'уже обработан' in lowered
        or 'already been processed' in lowered
        or 'already processed' in lowered
    )


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


def _parse_alfa_order_status(response):
    if not isinstance(response, dict):
        return '', ''

    order_status = str(response.get('orderStatus', '')).strip()
    action_code = str(
        response.get('actionCode')
        or response.get('action_code')
        or ''
    ).strip()

    return order_status, action_code


def _classify_alfa_order_state(order_status, action_code):
    if order_status == _ALFA_PAID_ORDER_STATUS:
        return 'paid'

    if order_status in _ALFA_EXPIRED_ORDER_STATUSES:
        return 'expired'

    if action_code in _ALFA_EXPIRED_ACTION_CODES:
        return 'expired'

    if order_status in _ALFA_PAYABLE_ORDER_STATUSES:
        return 'payable'

    if order_status:
        return 'expired'

    return 'unknown'


def _fetch_alfa_status_response(order):
    login = getattr(settings, 'ALFA_API_LOGIN', '')
    password = getattr(settings, 'ALFA_API_PASSWORD', '')

    if not login or not password:
        return None

    external_id = (order.payment_external_id or '').strip()
    if external_id:
        response = _alfa_post(
            _get_status_url(),
            {
                'userName': login,
                'password': password,
                'orderId': external_id,
            },
        )
        if not _alfa_response_error_message(response):
            return response

    response = _alfa_post(
        _get_status_url(),
        {
            'userName': login,
            'password': password,
            'orderNumber': f'delycafe-{order.id}',
        },
    )
    if _alfa_response_error_message(response):
        return None

    return response


def _apply_alfa_status_response(order, response):
    order_status, action_code = _parse_alfa_order_status(response)
    state = _classify_alfa_order_state(order_status, action_code)

    external_id = response.get('orderId') or response.get('order_id')
    if external_id and not (order.payment_external_id or '').strip():
        order.payment_external_id = str(external_id)

    if state == 'paid':
        confirm_order_paid(order)
    elif state == 'expired':
        close_unpaid_alfa_order(order)

    return state


def close_unpaid_alfa_order(order):
    """Закрывает неоплаченный заказ с мёртвой сессией Альфы."""
    update_fields = ['updated_at']

    if order.payment_provider:
        order.payment_provider = ''
        update_fields.append('payment_provider')

    if order.payment_external_id:
        order.payment_external_id = ''
        update_fields.append('payment_external_id')

    if order.payment_url:
        order.payment_url = ''
        update_fields.append('payment_url')

    if order.payment_status != Order.PaymentStatus.FAILED:
        order.payment_status = Order.PaymentStatus.FAILED
        update_fields.append('payment_status')

    if order.status == Order.Status.NEW:
        order.status = Order.Status.CANCELED
        update_fields.append('status')

    order.save(update_fields=list(set(update_fields)))
    rollback_order(order)

    logger.info(
        'Closed unpaid Alfa order #%s after expired or rejected payment session',
        order.id,
    )


def evaluate_alfa_session_for_reuse(order):
    """
    Проверяет, можно ли переиспользовать заказ при оформлении.
    Просроченные в Альфе заказы закрывает в БД.
    """
    if order.payment_status == Order.PaymentStatus.PAID:
        return False

    if not getattr(settings, 'ALFA_PAYMENT_ENABLED', False):
        return True

    if not (order.payment_external_id or '').strip():
        return True

    response = _fetch_alfa_status_response(order)
    if response is None:
        return True

    state = _apply_alfa_status_response(order, response)
    order.refresh_from_db()

    if state == 'paid':
        return False

    if state == 'expired':
        return False

    return state == 'payable'


def _ensure_payable_before_reuse(order):
    if not evaluate_alfa_session_for_reuse(order):
        order.refresh_from_db()
        return False

    return order.payment_status == Order.PaymentStatus.UNPAID


def _is_alfa_template_payment_url(payment_url):
    payment_url = (payment_url or '').strip()
    if not payment_url:
        return False

    template = (getattr(settings, 'ALFA_PAYMENT_FORM_URL', '') or '').strip()
    if not template:
        return False

    template_prefix = re.sub(r'\{[^}]+\}', '', template)
    template_prefix = re.sub(r'[?&=]+$', '', template_prefix)
    return payment_url.startswith(template_prefix)


def _usable_stored_alfa_payment_url(order):
    stored = (order.payment_url or '').strip()
    if not stored or _is_alfa_template_payment_url(stored):
        return ''
    return stored


def _build_alfa_payment_url(external_id, order=None):
    external_id = (external_id or '').strip()
    if not external_id:
        return ''

    template = (getattr(settings, 'ALFA_PAYMENT_FORM_URL', '') or '').strip()
    if template:
        return (
            template
            .replace('{mdOrder}', external_id)
            .replace('{orderId}', external_id)
        )

    if order is not None:
        stored_url = (order.payment_url or '').strip()
        if stored_url and 'mdorder=' in stored_url.lower():
            return re.sub(
                r'mdOrder=[^&]+',
                f'mdOrder={external_id}',
                stored_url,
                count=1,
                flags=re.IGNORECASE,
            )

    return ''


def _resolve_alfa_payment_url(external_id, order=None, form_url=''):
    """Ссылка из ответа Альфы (formUrl) — основной источник; шаблон — запасной."""
    normalized_form_url = _normalize_alfa_payment_url(form_url)
    if normalized_form_url:
        return normalized_form_url

    return _build_alfa_payment_url(external_id, order)


def _normalize_alfa_payment_url(payment_url):
    payment_url = (payment_url or '').strip()

    if not payment_url:
        return ''

    if payment_url.startswith('//'):
        return f'https:{payment_url}'

    if not re.match(r'^[a-zA-Z][a-zA-Z\d+\-.]*://', payment_url):
        return f'https://{payment_url}'

    return payment_url


def _maybe_append_sbp_payment_way(order, payment_url):
    if order.payment_type != Order.PaymentType.SBP:
        return payment_url

    lowered = payment_url.lower()
    if 'paymentway=sbp' in lowered:
        return payment_url

    separator = '&' if '?' in payment_url else '?'
    return f'{payment_url}{separator}paymentWay=SBP_C2B'


def _alfa_session_matches_payment_type(order, payment_url):
    payment_url = (payment_url or '').lower()

    if order.payment_type == Order.PaymentType.SBP:
        return (
            'sbp' in payment_url
            or 'paymentway=sbp_c2b' in payment_url
        )

    return True


def _persist_alfa_payment_session(order, external_id, payment_url):
    payment_url = _resolve_alfa_payment_url(external_id, order, payment_url)
    payment_url = _maybe_append_sbp_payment_way(order, payment_url)

    order.payment_provider = 'alfa'
    order.payment_external_id = external_id
    order.payment_url = payment_url
    order.payment_status = Order.PaymentStatus.UNPAID
    order.save(
        update_fields=[
            'payment_provider',
            'payment_external_id',
            'payment_url',
            'payment_status',
            'updated_at',
        ]
    )

    return payment_url


def _build_payment_result(order, *, reused=False):
    amount_value = getattr(order, 'payment_amount', None) or getattr(order, 'total_price', 0)

    return {
        'order_id': order.id,
        'payment_url': order.payment_url,
        'external_id': order.payment_external_id,
        'amount': amount_value,
        'reused': reused,
    }


def _lookup_alfa_order_by_number(order):
    login = getattr(settings, 'ALFA_API_LOGIN', '')
    password = getattr(settings, 'ALFA_API_PASSWORD', '')

    if not login or not password:
        return None

    response = _alfa_post(
        _get_status_url(),
        {
            'userName': login,
            'password': password,
            'orderNumber': f'delycafe-{order.id}',
        },
    )

    if _alfa_response_error_message(response):
        return None

    external_id = response.get('orderId') or response.get('order_id')
    if not external_id:
        return None

    order_status, action_code = _parse_alfa_order_status(response)
    state = _classify_alfa_order_state(order_status, action_code)
    if state != 'payable':
        if state == 'paid':
            order.payment_external_id = str(external_id)
            order.save(update_fields=['payment_external_id', 'updated_at'])
            confirm_order_paid(order)
        elif state == 'expired':
            close_unpaid_alfa_order(order)
        return None

    payment_url = _resolve_alfa_payment_url(
        external_id,
        order,
        response.get('formUrl') or response.get('form_url') or '',
    )

    if not payment_url:
        return None

    if not _alfa_session_matches_payment_type(order, payment_url):
        return None

    _persist_alfa_payment_session(order, external_id, payment_url)
    return _build_payment_result(order, reused=True)


def _try_reuse_existing_alfa_session(order, *, amount_value=None):
    if not _ensure_payable_before_reuse(order):
        return None

    external_id = (order.payment_external_id or '').strip()
    if not external_id:
        return None

    form_url = ''
    response = _fetch_alfa_status_response(order)
    if response:
        form_url = response.get('formUrl') or response.get('form_url') or ''
        external_id = str(
            response.get('orderId') or response.get('order_id') or external_id,
        ).strip()

    payment_url = _resolve_alfa_payment_url(
        external_id,
        order,
        form_url or _usable_stored_alfa_payment_url(order),
    )

    if not payment_url:
        return None

    if not _alfa_session_matches_payment_type(order, payment_url):
        return None

    payment_url = _persist_alfa_payment_session(order, external_id, form_url or payment_url)
    result = _build_payment_result(order, reused=True)
    result['amount'] = amount_value or result['amount']
    return result


def create_alfa_payment(order, *, force=False):
    if not getattr(settings, 'ALFA_PAYMENT_ENABLED', False):
        raise AlfaPaymentError('Оплата через Альфа-Банк выключена в настройках.')

    amount_value = getattr(order, 'payment_amount', None) or getattr(order, 'total_price', 0)

    if not force:
        if (order.payment_external_id or '').strip():
            if not evaluate_alfa_session_for_reuse(order):
                order.refresh_from_db()
                if order.status == Order.Status.CANCELED:
                    raise AlfaPaymentError(
                        'Срок оплаты в Альфе истёк. Оформите заказ ещё раз — '
                        'будет создан новый заказ.'
                    )

        reused = _try_reuse_existing_alfa_session(order, amount_value=amount_value)
        if reused is not None:
            return reused

    login = getattr(settings, 'ALFA_API_LOGIN', '')
    password = getattr(settings, 'ALFA_API_PASSWORD', '')

    if not login or not password:
        raise AlfaPaymentError('Не указан ALFA_API_LOGIN или ALFA_API_PASSWORD.')
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

    message = _alfa_response_error_message(response)
    if message:
        if _is_duplicate_alfa_order_number_error(message):
            looked_up = _lookup_alfa_order_by_number(order)
            if looked_up is not None:
                return looked_up

            reused = _try_reuse_existing_alfa_session(order, amount_value=amount_value)
            if reused is not None:
                return reused

            close_unpaid_alfa_order(order)
            raise AlfaPaymentError(
                'Срок оплаты в Альфе истёк. Оформите заказ ещё раз — '
                'будет создан новый заказ.'
            )

        raise AlfaPaymentError(message)

    external_id = response.get('orderId')
    payment_url = response.get('formUrl')

    if not external_id or not payment_url:
        raise AlfaPaymentError(f'Альфа не вернула ссылку оплаты: {response}')

    _persist_alfa_payment_session(order, external_id, payment_url)

    result = _build_payment_result(order, reused=False)
    result['raw'] = response
    return result


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
    _apply_alfa_status_response(order, response)

    return response
