from datetime import timedelta
from unittest.mock import MagicMock

from django.test import TestCase, override_settings
from django.utils import timezone

from customers.models import PhoneAuthSession
from customers.services.otp_auth_service import OtpAuthService
from customers.services.smsaero_service import SmsAeroError


@override_settings(
    SMSAERO_ENABLED=True,
    SMSAERO_AUTH_MODE='mobile_id',
    SMSAERO_MOBILE_ID_SMS_FALLBACK_SECONDS=45,
    SMSAERO_OTP_MESSAGE='Код: {code}',
    SMSAERO_CALLBACK_URL='https://example.com/webhook/',
)
class MobileIdSmsFallbackTests(TestCase):
    def setUp(self):
        self.sms_client = MagicMock()
        self.service = OtpAuthService(sms_client=self.sms_client)
        self.phone = '79001234567'

    def _create_pending_session(self, *, age_seconds: int = 50) -> PhoneAuthSession:
        session = PhoneAuthSession.objects.create(
            phone=self.phone,
            mode=PhoneAuthSession.Mode.MOBILE_ID,
            status=PhoneAuthSession.Status.PENDING,
            smsaero_id=12345,
            expires_at=timezone.now() + timedelta(minutes=5),
        )
        PhoneAuthSession.objects.filter(pk=session.pk).update(
            created_at=timezone.now() - timedelta(seconds=age_seconds),
        )
        session.refresh_from_db()
        return session

    def test_fallback_sends_sms_after_timeout(self):
        session = self._create_pending_session(age_seconds=50)
        self.sms_client.send_sms.return_value = {'success': True, 'data': [{'id': 99}]}

        self.service.get_session_status(session.id)

        session.refresh_from_db()
        self.assertIsNotNone(session.sms_fallback_sent_at)
        self.assertEqual(session.status, PhoneAuthSession.Status.AWAITING_OTP)
        self.assertTrue(session.code_hash)
        self.sms_client.send_sms.assert_called_once()

    def test_no_fallback_before_timeout(self):
        session = self._create_pending_session(age_seconds=10)

        self.service.get_session_status(session.id)

        session.refresh_from_db()
        self.assertIsNone(session.sms_fallback_sent_at)
        self.sms_client.send_sms.assert_not_called()

    def test_fallback_on_failed_status(self):
        session = self._create_pending_session(age_seconds=5)
        session.status = PhoneAuthSession.Status.FAILED
        session.save(update_fields=['status', 'updated_at'])
        self.sms_client.send_sms.return_value = {'success': True, 'data': [{'id': 99}]}

        self.service.get_session_status(session.id)

        session.refresh_from_db()
        self.assertIsNotNone(session.sms_fallback_sent_at)
        self.assertEqual(session.status, PhoneAuthSession.Status.AWAITING_OTP)

    def test_verify_uses_local_hash_after_fallback(self):
        session = self._create_pending_session(age_seconds=50)
        code = '1234'
        session.code_hash = session.code_hash or self.service._hash_code(self.phone, code)
        session.sms_fallback_sent_at = timezone.now()
        session.status = PhoneAuthSession.Status.AWAITING_OTP
        session.code_hash = self.service._hash_code(self.phone, code)
        session.save()

        verified = self.service.verify_code(
            session_id=session.id,
            code=code,
            phone=self.phone,
        )

        self.assertEqual(verified.status, PhoneAuthSession.Status.VERIFIED)
        self.sms_client.verify_mobile_id.assert_not_called()

    def test_status_payload_hides_code_input_while_pending(self):
        session = self._create_pending_session(age_seconds=5)

        payload = self.service.build_session_status_payload(session)

        self.assertEqual(payload['phase'], 'pending')
        self.assertFalse(payload['show_code_input'])

    def test_sms_send_error_marks_session_failed(self):
        session = self._create_pending_session(age_seconds=50)
        self.sms_client.send_sms.side_effect = SmsAeroError('fail')

        self.service.get_session_status(session.id)

        session.refresh_from_db()
        self.assertEqual(session.status, PhoneAuthSession.Status.FAILED)
