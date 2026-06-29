from __future__ import annotations

import logging
from typing import Any

import requests
from django.conf import settings

logger = logging.getLogger(__name__)


class SmsAeroError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


class SmsAeroClient:
    """HTTP-клиент SMS Aero API v2.

    Документация: https://smsaero.ru/integration/documentation/api/
    """

    BASE_URL = 'https://gate.smsaero.ru/v2'

    def __init__(
        self,
        email: str | None = None,
        api_key: str | None = None,
        sign: str | None = None,
        timeout: int = 20,
    ):
        self.email = email or settings.SMSAERO_EMAIL
        self.api_key = api_key or settings.SMSAERO_API_KEY
        self.sign = sign or settings.SMSAERO_SIGN
        self.timeout = timeout

    @property
    def is_configured(self) -> bool:
        return bool(self.email and self.api_key and self.sign)

    def check_auth(self) -> dict[str, Any]:
        return self._request('GET', '/auth')

    def send_sms(self, number: str, text: str, *, sign: str | None = None) -> dict[str, Any]:
        return self._request(
            'POST',
            '/sms/send',
            json_body={
                'number': number,
                'text': text,
                'sign': sign or self.sign,
            },
        )

    def send_mobile_id(
        self,
        number: str,
        callback_url: str,
        *,
        sign: str | None = None,
    ) -> dict[str, Any]:
        return self._request(
            'POST',
            '/mobile-id/send',
            json_body={
                'number': number,
                'sign': sign or self.sign,
                'callbackUrl': callback_url,
            },
        )

    def verify_mobile_id(
        self,
        session_id: int,
        code: str,
        *,
        sign: str | None = None,
    ) -> dict[str, Any]:
        return self._request(
            'POST',
            '/mobile-id/verify',
            json_body={
                'id': session_id,
                'sign': sign or self.sign,
                'code': code,
            },
        )

    def mobile_id_status(self, session_id: int) -> dict[str, Any]:
        return self._request(
            'POST',
            '/mobile-id/status',
            json_body={'id': session_id},
        )

    def _request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        if not self.is_configured:
            raise SmsAeroError('SMS Aero не настроен: задайте SMSAERO_EMAIL, SMSAERO_API_KEY, SMSAERO_SIGN')

        url = f'{self.BASE_URL}{path}'

        try:
            response = requests.request(
                method,
                url,
                params=params,
                json=json_body,
                auth=(self.email, self.api_key),
                headers={'Accept': 'application/json'},
                timeout=self.timeout,
            )
        except requests.RequestException as error:
            raise SmsAeroError(f'Не удалось подключиться к SMS Aero: {error}') from error

        try:
            payload = response.json()
        except ValueError as error:
            raise SmsAeroError(
                f'SMS Aero вернула не JSON (HTTP {response.status_code}): {response.text[:300]}',
                status_code=response.status_code,
            ) from error

        if response.status_code >= 400:
            message = self._extract_error_message(payload) or response.text[:300]
            raise SmsAeroError(
                f'SMS Aero HTTP {response.status_code}: {message}',
                status_code=response.status_code,
            )

        if not payload.get('success'):
            message = self._extract_error_message(payload) or str(payload)
            raise SmsAeroError(message, status_code=response.status_code)

        return payload

    @staticmethod
    def _extract_error_message(payload: dict[str, Any]) -> str | None:
        message = payload.get('message')
        if message:
            return str(message)
        return None
