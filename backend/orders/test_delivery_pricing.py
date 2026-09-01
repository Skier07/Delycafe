from django.test import TestCase

from orders.delivery_pricing import calculate_delivery_price
from orders.models import DeliveryZone


class DeliveryPricingTests(TestCase):
    def test_ozersk_tiered_prices(self):
        zone = DeliveryZone.objects.get(code='ozersk')

        self.assertEqual(
            calculate_delivery_price(zone.code, 500),
            300,
        )
        self.assertEqual(
            calculate_delivery_price(zone.code, 1500),
            250,
        )
        self.assertEqual(
            calculate_delivery_price(zone.code, 2500),
            0,
        )

    def test_fixed_zone_prices(self):
        prom = DeliveryZone.objects.get(code='promploshadka')
        tatysh = DeliveryZone.objects.get(code='tatysh')

        self.assertEqual(calculate_delivery_price(prom.code, 100), 400)
        self.assertEqual(calculate_delivery_price(tatysh.code, 5000), 550)

    def test_pickup_is_free(self):
        pickup = DeliveryZone.objects.get(code='pickup')

        self.assertEqual(calculate_delivery_price(pickup.code, 1000), 0)
