from datetime import timedelta

from django.test import override_settings
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from customers.models import Customer, CustomerRefreshToken
from customers.services.auth_token_service import (
    RefreshTokenError,
    create_customer_refresh_token,
    create_legacy_customer_access_token,
    decode_customer_access_token,
    rotate_customer_refresh_token,
)


@override_settings(
    CUSTOMER_ACCESS_TOKEN_MINUTES=30,
    CUSTOMER_REFRESH_TOKEN_DAYS=365,
)
class CustomerRefreshTokenTests(TestCase):
    def setUp(self):
        self.customer = Customer.objects.create(phone='79000000002')

    def test_refresh_token_rotates_and_keeps_absolute_365_day_expiry(self):
        refresh_token = create_customer_refresh_token(customer=self.customer)
        original = CustomerRefreshToken.objects.get(customer=self.customer)

        access_token, next_refresh_token = rotate_customer_refresh_token(
            refresh_token
        )

        original.refresh_from_db()
        replacement = CustomerRefreshToken.objects.get(
            customer=self.customer,
            revoked_at__isnull=True,
        )
        payload = decode_customer_access_token(access_token)

        self.assertIsNotNone(original.revoked_at)
        self.assertEqual(replacement.family_id, original.family_id)
        self.assertEqual(replacement.expires_at, original.expires_at)
        self.assertEqual(payload['customer_id'], self.customer.id)
        self.assertNotEqual(next_refresh_token, refresh_token)
        self.assertGreater(
            replacement.expires_at,
            timezone.now() + timedelta(days=364),
        )

    def test_reusing_rotated_token_revokes_whole_token_family(self):
        refresh_token = create_customer_refresh_token(customer=self.customer)
        rotate_customer_refresh_token(refresh_token)

        with self.assertRaises(RefreshTokenError):
            rotate_customer_refresh_token(refresh_token)

        self.assertFalse(
            CustomerRefreshToken.objects.filter(
                customer=self.customer,
                revoked_at__isnull=True,
            ).exists()
        )

    def test_expired_refresh_token_is_rejected(self):
        refresh_token = create_customer_refresh_token(customer=self.customer)
        CustomerRefreshToken.objects.filter(customer=self.customer).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )

        with self.assertRaises(RefreshTokenError):
            rotate_customer_refresh_token(refresh_token)

    def test_legacy_access_token_can_bootstrap_refresh_session(self):
        legacy_token = create_legacy_customer_access_token(
            customer_id=self.customer.id,
            phone=self.customer.phone,
        )
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {legacy_token}')

        response = client.post(reverse('customer-token-bootstrap'))

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['refresh_token'])
        self.assertTrue(
            decode_customer_access_token(response.data['access_token'])['jti']
        )
        self.assertEqual(
            CustomerRefreshToken.objects.filter(
                customer=self.customer,
                revoked_at__isnull=True,
            ).count(),
            1,
        )
