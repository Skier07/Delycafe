from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.utils import timezone

from customers.models import PhoneAuthSession
from customers.services.smsaero_service import SmsAeroClient, SmsAeroError

logger = logging.getLogger(__name__)


class OtpAuthError(Exception):
    def __init__(self, message: str, *, code: str = 'otp_error', retry_after: int | None = None):
        super().__init__(message)
        self.code = code
        self.retry_after = retry_after


# Статусы mobile-id из документации SMS Aero.
MOBILE_ID_STATUS_PENDING = 0
MOBILE_ID_STATUS_SUCCESS = 1
MOBILE_ID_STATUS_FAILED = 2
MOBILE_ID_STATUS_AWAITING_OTP = 3
MOBILE_ID_STATUS_IN_PROGRESS = 8
MOBILE_ID_STATUS_ERROR = 16


class OtpAuthService:
    def __init__(self, sms_client: SmsAeroClient | None = None):
        self.sms_client = sms_client or SmsAeroClient()

    @property
    def mode(self) -> str:
        return settings.SMSAERO_AUTH_MODE

    def send_code(self, phone: str) -> PhoneAuthSession:
        normalized_phone = self._normalize_phone(phone)

        if not normalized_phone:
            raise OtpAuthError('Некорректный номер телефона.', code='invalid_phone')

        self._ensure_can_send(normalized_phone)

        if self.mode == 'mobile_id':
            return self._send_mobile_id(normalized_phone)

        return self._send_sms_otp(normalized_phone)

    def verify_code(
        self,
        *,
        session_id: int,
        code: str,
        phone: str | None = None,
    ) -> PhoneAuthSession:
        session = self._get_active_session(session_id, phone=phone)

        if session.is_expired:
            session.mark_failed()
            raise OtpAuthError('Код истёк. Запросите новый.', code='expired')

        if session.status == PhoneAuthSession.Status.VERIFIED:
            return session

        if session.verify_attempts >= settings.SMSAERO_MAX_VERIFY_ATTEMPTS:
            session.mark_failed()
            raise OtpAuthError(
                'Превышено число попыток. Запросите новый код.',
                code='too_many_attempts',
            )

        session.verify_attempts += 1
        session.save(update_fields=['verify_attempts', 'updated_at'])

        if self.mode == 'mobile_id':
            self._verify_mobile_id(session, code)
        else:
            self._verify_sms_code(session, code)

        session.mark_verified()
        return session

    def verify_code_for_deletion(
        self,
        *,
        session_id: int,
        code: str,
        phone: str | None = None,
    ) -> PhoneAuthSession:
        """Подтверждение удаления аккаунта — всегда проверяет код заново."""
        session = self._get_active_session(session_id, phone=phone)

        if session.is_expired:
            session.mark_failed()
            raise OtpAuthError('Код истёк. Запросите новый.', code='expired')

        if session.status == PhoneAuthSession.Status.VERIFIED:
            raise OtpAuthError(
                'Запросите новый код для удаления аккаунта.',
                code='expired',
            )

        if session.verify_attempts >= settings.SMSAERO_MAX_VERIFY_ATTEMPTS:
            session.mark_failed()
            raise OtpAuthError(
                'Превышено число попыток. Запросите новый код.',
                code='too_many_attempts',
            )

        session.verify_attempts += 1
        session.save(update_fields=['verify_attempts', 'updated_at'])

        if self.mode == 'mobile_id':
            self._verify_mobile_id(session, code)
        else:
            self._verify_sms_code(session, code)

        session.mark_verified()
        return session

    def apply_mobile_id_webhook(
        self,
        *,
        smsaero_id: int,
        status: int,
        number: str | None = None,
    ) -> PhoneAuthSession | None:
        session = (
            PhoneAuthSession.objects.filter(
                smsaero_id=smsaero_id,
                mode=PhoneAuthSession.Mode.MOBILE_ID,
            )
            .order_by('-created_at')
            .first()
        )

        if session is None:
            logger.warning('Webhook mobile-id: сессия %s не найдена', smsaero_id)
            return None

        if number:
            normalized_number = self._normalize_phone(number)
            if normalized_number and normalized_number != session.phone:
                logger.warning(
                    'Webhook mobile-id: номер %s не совпадает с сессией %s',
                    normalized_number,
                    session.phone,
                )

        if status == MOBILE_ID_STATUS_SUCCESS:
            session.mark_verified()
        elif status == MOBILE_ID_STATUS_FAILED:
            session.mark_failed()
        elif status == MOBILE_ID_STATUS_AWAITING_OTP:
            session.status = PhoneAuthSession.Status.AWAITING_OTP
            session.save(update_fields=['status', 'updated_at'])
        elif status in {MOBILE_ID_STATUS_PENDING, MOBILE_ID_STATUS_IN_PROGRESS}:
            session.status = PhoneAuthSession.Status.PENDING
            session.save(update_fields=['status', 'updated_at'])

        return session

    def get_session_status(self, session_id: int, phone: str | None = None) -> PhoneAuthSession:
        session = self._get_active_session(session_id, phone=phone, allow_verified=True)

        if (
            session.mode == PhoneAuthSession.Mode.MOBILE_ID
            and session.smsaero_id
            and session.status not in {
                PhoneAuthSession.Status.VERIFIED,
                PhoneAuthSession.Status.FAILED,
            }
            and settings.SMSAERO_ENABLED
        ):
            self._refresh_mobile_id_status(session)

        return session

    def _send_sms_otp(self, phone: str) -> PhoneAuthSession:
        if settings.SMSAERO_ENABLED:
            code = self._generate_code()
        else:
            code = settings.SMSAERO_DEV_CODE

        expires_at = timezone.now() + timedelta(seconds=settings.SMSAERO_OTP_TTL_SECONDS)

        session = PhoneAuthSession.objects.create(
            phone=phone,
            mode=PhoneAuthSession.Mode.SMS,
            status=PhoneAuthSession.Status.AWAITING_OTP,
            code_hash=self._hash_code(phone, code),
            expires_at=expires_at,
        )

        if not settings.SMSAERO_ENABLED:
            logger.info('SMS Aero отключён: OTP для %s = %s', phone, code)
            return session

        text = settings.SMSAERO_OTP_MESSAGE.format(code=code)

        try:
            response = self.sms_client.send_sms(phone, text)
        except SmsAeroError as error:
            session.mark_failed()
            raise OtpAuthError(str(error), code='sms_send_failed') from error

        data = response.get('data') or []
        if isinstance(data, list) and data:
            session.smsaero_id = data[0].get('id')
            session.save(update_fields=['smsaero_id', 'updated_at'])

        return session

    def _send_mobile_id(self, phone: str) -> PhoneAuthSession:
        callback_url = settings.SMSAERO_CALLBACK_URL.strip()

        if settings.SMSAERO_ENABLED and not callback_url:
            raise OtpAuthError(
                'Не задан SMSAERO_CALLBACK_URL для mobile-id.',
                code='misconfigured',
            )

        expires_at = timezone.now() + timedelta(seconds=settings.SMSAERO_OTP_TTL_SECONDS)

        session = PhoneAuthSession.objects.create(
            phone=phone,
            mode=PhoneAuthSession.Mode.MOBILE_ID,
            status=PhoneAuthSession.Status.PENDING,
            expires_at=expires_at,
        )

        if not settings.SMSAERO_ENABLED:
            session.status = PhoneAuthSession.Status.AWAITING_OTP
            session.code_hash = self._hash_code(phone, settings.SMSAERO_DEV_CODE)
            session.save(update_fields=['status', 'code_hash', 'updated_at'])
            logger.info('SMS Aero отключён: mobile-id для %s, dev-код %s', phone, settings.SMSAERO_DEV_CODE)
            return session

        try:
            response = self.sms_client.send_mobile_id(phone, callback_url)
        except SmsAeroError as error:
            session.mark_failed()
            raise OtpAuthError(str(error), code='mobile_id_send_failed') from error

        data = response.get('data') or {}
        smsaero_id = data.get('id')
        if smsaero_id is None:
            session.mark_failed()
            raise OtpAuthError('SMS Aero не вернула id сессии.', code='mobile_id_send_failed')

        session.smsaero_id = smsaero_id
        session.status = self._map_mobile_id_status(data.get('status'))
        session.save(update_fields=['smsaero_id', 'status', 'updated_at'])
        return session

    def _verify_sms_code(self, session: PhoneAuthSession, code: str) -> None:
        if not session.code_hash:
            raise OtpAuthError('Сессия не содержит код.', code='invalid_session')

        expected_hash = self._hash_code(session.phone, code.strip())

        if not hmac.compare_digest(session.code_hash, expected_hash):
            raise OtpAuthError('Неверный код.', code='invalid_code')

    def _verify_mobile_id(self, session: PhoneAuthSession, code: str) -> None:
        if not settings.SMSAERO_ENABLED:
            self._verify_sms_code(session, code)
            return

        if session.smsaero_id is None:
            raise OtpAuthError('Сессия mobile-id не найдена.', code='invalid_session')

        try:
            response = self.sms_client.verify_mobile_id(session.smsaero_id, code.strip())
        except SmsAeroError as error:
            if error.status_code == 400:
                raise OtpAuthError('Неверный код.', code='invalid_code') from error
            if error.status_code == 404:
                raise OtpAuthError('Сессия истекла. Запросите новый код.', code='expired') from error
            raise OtpAuthError(str(error), code='mobile_id_verify_failed') from error

        data = response.get('data') or {}
        mapped_status = self._map_mobile_id_status(data.get('status'))

        if mapped_status == PhoneAuthSession.Status.FAILED:
            session.mark_failed()
            raise OtpAuthError('Верификация не пройдена.', code='verification_failed')

        if mapped_status != PhoneAuthSession.Status.VERIFIED:
            session.status = mapped_status
            session.save(update_fields=['status', 'updated_at'])
            raise OtpAuthError('Код принят, ожидается подтверждение.', code='pending')

    def _refresh_mobile_id_status(self, session: PhoneAuthSession) -> None:
        try:
            response = self.sms_client.mobile_id_status(session.smsaero_id)
        except SmsAeroError:
            return

        data = response.get('data') or {}
        mapped_status = self._map_mobile_id_status(data.get('status'))

        if mapped_status == PhoneAuthSession.Status.VERIFIED:
            session.mark_verified()
        elif mapped_status == PhoneAuthSession.Status.FAILED:
            session.mark_failed()
        elif mapped_status != session.status:
            session.status = mapped_status
            session.save(update_fields=['status', 'updated_at'])

    def _ensure_can_send(self, phone: str) -> None:
        now = timezone.now()
        cooldown_from = now - timedelta(seconds=settings.SMSAERO_SEND_COOLDOWN_SECONDS)
        hour_ago = now - timedelta(hours=1)

        last_session = (
            PhoneAuthSession.objects.filter(phone=phone)
            .order_by('-created_at')
            .first()
        )

        if last_session and last_session.created_at > cooldown_from:
            retry_after = int(
                (
                    last_session.created_at
                    + timedelta(seconds=settings.SMSAERO_SEND_COOLDOWN_SECONDS)
                    - now
                ).total_seconds(),
            )
            raise OtpAuthError(
                'Подождите перед повторной отправкой.',
                code='rate_limited',
                retry_after=max(retry_after, 1),
            )

        sends_last_hour = PhoneAuthSession.objects.filter(
            phone=phone,
            created_at__gte=hour_ago,
        ).count()

        if sends_last_hour >= settings.SMSAERO_MAX_SENDS_PER_HOUR:
            raise OtpAuthError(
                'Слишком много запросов кода. Попробуйте позже.',
                code='rate_limited',
            )

    def _get_active_session(
        self,
        session_id: int,
        *,
        phone: str | None = None,
        allow_verified: bool = False,
    ) -> PhoneAuthSession:
        try:
            session = PhoneAuthSession.objects.get(pk=session_id)
        except PhoneAuthSession.DoesNotExist as error:
            raise OtpAuthError('Сессия не найдена.', code='invalid_session') from error

        if phone:
            normalized_phone = self._normalize_phone(phone)
            if normalized_phone and normalized_phone != session.phone:
                raise OtpAuthError('Сессия не найдена.', code='invalid_session')

        if session.status == PhoneAuthSession.Status.FAILED:
            raise OtpAuthError('Сессия недействительна. Запросите новый код.', code='expired')

        if session.is_expired and session.status != PhoneAuthSession.Status.VERIFIED:
            session.mark_failed()
            raise OtpAuthError('Код истёк. Запросите новый.', code='expired')

        if session.status == PhoneAuthSession.Status.VERIFIED and not allow_verified:
            return session

        return session

    def _generate_code(self) -> str:
        length = settings.SMSAERO_OTP_LENGTH
        upper = 10 ** length
        return str(secrets.randbelow(upper)).zfill(length)

    def _hash_code(self, phone: str, code: str) -> str:
        payload = f'{phone}:{code}'.encode()
        secret = settings.SECRET_KEY.encode()
        return hmac.new(secret, payload, hashlib.sha256).hexdigest()

    @staticmethod
    def _normalize_phone(value: str) -> str:
        raw_phone = str(value or '').strip()
        digits = ''.join(char for char in raw_phone if char.isdigit())

        if len(digits) == 11 and digits.startswith('8'):
            digits = '7' + digits[1:]

        if len(digits) == 10:
            digits = '7' + digits

        if len(digits) == 11 and digits.startswith('7'):
            return digits

        return ''

    @staticmethod
    def _map_mobile_id_status(raw_status: int | str | None) -> str:
        try:
            status = int(raw_status)
        except (TypeError, ValueError):
            return PhoneAuthSession.Status.PENDING

        if status == MOBILE_ID_STATUS_SUCCESS:
            return PhoneAuthSession.Status.VERIFIED
        if status == MOBILE_ID_STATUS_FAILED:
            return PhoneAuthSession.Status.FAILED
        if status == MOBILE_ID_STATUS_AWAITING_OTP:
            return PhoneAuthSession.Status.AWAITING_OTP
        return PhoneAuthSession.Status.PENDING
