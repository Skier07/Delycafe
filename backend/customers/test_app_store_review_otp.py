from unittest.mock import MagicMock

from django.test import TestCase, override_settings

from customers.models import PhoneAuthSession
from customers.services.otp_auth_service import OtpAuthError, OtpAuthService


@override_settings(
    SMSAERO_ENABLED=True,
    SMSAERO_AUTH_MODE='mobile_id',
    SMSAERO_CALLBACK_URL='https://example.com/webhook/',
    APP_STORE_REVIEW_PHONES='79000000000,+7 (900) 000-00-00',
    APP_STORE_REVIEW_CODE='1234',
    APP_STORE_REVIEW_OTP_TTL_SECONDS=7 * 24 * 60 * 60,
)
class AppStoreReviewOtpTests(TestCase):
    def setUp(self):
        self.sms_client = MagicMock()
        self.service = OtpAuthService(sms_client=self.sms_client)
        self.phone = '79000000000'

    def test_review_phone_skips_sms_and_accepts_fixed_code(self):
        session = self.service.send_code('+79000000000')

        self.assertEqual(session.phone, self.phone)
        self.assertEqual(session.mode, PhoneAuthSession.Mode.SMS)
        self.assertEqual(session.status, PhoneAuthSession.Status.AWAITING_OTP)
        self.sms_client.send_sms.assert_not_called()
        self.sms_client.send_mobile_id.assert_not_called()

        verified = self.service.verify_code(
            session_id=session.id,
            code='1234',
            phone=self.phone,
        )

        self.assertEqual(verified.status, PhoneAuthSession.Status.VERIFIED)

    def test_review_phone_rejects_wrong_code(self):
        session = self.service.send_code(self.phone)

        with self.assertRaises(OtpAuthError):
            self.service.verify_code(
                session_id=session.id,
                code='0000',
                phone=self.phone,
            )

    def test_review_phone_skips_send_rate_limit(self):
        first = self.service.send_code(self.phone)
        second = self.service.send_code(self.phone)

        self.assertNotEqual(first.id, second.id)
        self.assertEqual(PhoneAuthSession.objects.filter(phone=self.phone).count(), 2)
