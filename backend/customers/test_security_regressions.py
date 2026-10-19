import hashlib
from datetime import timedelta
from unittest.mock import patch

from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from customers.models import Customer, CustomerRefreshToken, PhoneAuthSession
from customers.services.auth_token_service import create_customer_access_token, create_customer_refresh_token
from customers.services.otp_auth_service import OtpAuthService, OtpAuthError


class OtpSecurityTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.customer = Customer.objects.create(phone='79000000999')
        self.secret = 'test-secret-that-is-not-a-real-session'
        self.session = PhoneAuthSession.objects.create(
            phone=self.customer.phone, mode='mobile_id', status='verified',
            session_secret_hash=hashlib.sha256(self.secret.encode()).hexdigest(),
            expires_at=timezone.now() + timedelta(minutes=5),
        )

    def complete(self, **changes):
        payload = {'session_id': self.session.pk, 'session_secret': self.secret, 'token_mode': 'refresh'}
        with patch('customers.views.sync_customer_from_saby', return_value=None):
            return self.client.post('/api/customers/auth/otp/complete/', {**payload, **changes}, format='json')

    def test_secret_is_required_even_for_verified_session(self):
        for secret in ('', 'wrong'):
            response = self.complete(session_secret=secret)
            self.assertEqual(response.status_code, 400)
            self.assertNotIn('access_token', response.data)

    def test_expiry_applies_to_verified_sessions(self):
        self.session.expires_at = timezone.now() - timedelta(seconds=1)
        self.session.save()
        self.assertEqual(self.complete().status_code, 400)
        with self.assertRaises(OtpAuthError):
            OtpAuthService().complete_verified_session(session_id=self.session.pk)

    def test_completion_is_once_only_and_retains_rate_limit_history(self):
        first = self.complete()
        self.assertEqual(first.status_code, 200, first.data)
        self.assertTrue(first.data['access_token'])
        self.assertEqual(self.complete().status_code, 400)
        self.assertEqual(CustomerRefreshToken.objects.count(), 1)
        self.session.refresh_from_db()
        self.assertIsNotNone(self.session.consumed_at)

    def test_status_and_verify_require_session_secret(self):
        response = self.client.get('/api/customers/auth/otp/status/', {'session_id': self.session.pk})
        self.assertEqual(response.status_code, 400)

        response = self.client.post('/api/customers/auth/otp/verify/',
                                    {'session_id': self.session.pk, 'code': '1234'})
        self.assertEqual(response.status_code, 400)

    def test_sms_verification_consumes_session_only_after_correct_code(self):
        self.session.mode = 'sms'
        self.session.status = 'awaiting_otp'
        self.session.code_hash = OtpAuthService()._hash_code(self.customer.phone, '5678')
        self.session.save()
        payload = {'session_id': self.session.pk, 'session_secret': self.secret,
                   'code': 'wrong', 'token_mode': 'refresh'}
        invalid = self.client.post('/api/customers/auth/otp/verify/', payload, format='json')
        self.assertEqual(invalid.status_code, 400)
        self.assertFalse(CustomerRefreshToken.objects.exists())
        with patch('customers.views.sync_customer_from_saby', return_value=None):
            valid = self.client.post('/api/customers/auth/otp/verify/',
                                     {**payload, 'code': '5678'}, format='json')
        self.assertEqual(valid.status_code, 200, valid.data)
        self.session.refresh_from_db()
        self.assertEqual(self.session.verify_attempts, 2)
        self.assertIsNotNone(self.session.consumed_at)
        again = self.client.post('/api/customers/auth/otp/verify/',
                                 {**payload, 'code': '5678'}, format='json')
        self.assertEqual(again.status_code, 400)
        self.assertEqual(CustomerRefreshToken.objects.count(), 1)

    def test_pending_session_cannot_complete(self):
        self.session.status = 'pending'
        self.session.save()
        self.assertEqual(self.complete().status_code, 400)

    def test_disabled_customer_cannot_issue_or_use_tokens(self):
        token = create_customer_access_token(customer_id=self.customer.pk, phone=self.customer.phone)
        create_customer_refresh_token(customer=self.customer)
        self.customer.is_active = False
        self.customer.save(update_fields=['is_active'])
        self.assertEqual(self.complete().status_code, 403)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + token)
        self.assertEqual(self.client.get('/api/customers/profile/').status_code, 403)
        self.assertFalse(CustomerRefreshToken.objects.filter(revoked_at__isnull=True).exists())
        self.customer.is_active = True
        self.customer.save(update_fields=['is_active'])
        self.assertEqual(self.client.get('/api/customers/profile/').status_code, 403)

    @override_settings(DEBUG=False, SMSAERO_ENABLED=False, APP_STORE_REVIEW_PHONES='')
    def test_production_cannot_use_dev_code(self):
        with self.assertRaises(OtpAuthError):
            OtpAuthService().send_code(self.customer.phone)

    @override_settings(DEBUG=True, SMSAERO_ENABLED=False, APP_STORE_REVIEW_PHONES='', SMSAERO_AUTH_MODE='sms')
    def test_send_returns_secret_but_status_does_not(self):
        response = self.client.post('/api/customers/auth/otp/send/', {'phone': '79000000888'})
        self.assertEqual(response.status_code, 201, response.data)
        secret = response.data['session_secret']
        session = PhoneAuthSession.objects.get(pk=response.data['session_id'])
        self.assertNotEqual(session.session_secret_hash, secret)
        result = self.client.get('/api/customers/auth/otp/status/', {'session_id': session.pk},
                                 HTTP_X_OTP_SESSION=secret)
        self.assertEqual(result.status_code, 200)
        self.assertNotIn('session_secret', result.data)

    def test_webhook_cannot_verify_mismatched_phone(self):
        self.session.status = 'pending'
        self.session.smsaero_id = 123
        self.session.save()
        OtpAuthService().apply_mobile_id_webhook(smsaero_id=123, status=1, number='79000000001')
        self.session.refresh_from_db()
        self.assertEqual(self.session.status, 'pending')
