from django.test import SimpleTestCase

from orders.promotions import (
    PICKUP_DISCOUNT_PERCENT,
    discounted_unit_price,
    pickup_discount_amount,
)


class PickupDiscountRoundingTests(SimpleTestCase):
    def test_per_item_differs_from_total_percent_when_fractional(self):
        # 509 * 5% = 25.45 → floor от суммы = 25
        # построчно: одна позиция 509 → 509*95//100 = 483, скидка = 26
        lines = [(509, 1)]
        per_item = pickup_discount_amount(lines)
        total_floor = 509 * PICKUP_DISCOUNT_PERCENT // 100

        self.assertEqual(discounted_unit_price(509), 483)
        self.assertEqual(per_item, 26)
        self.assertEqual(total_floor, 25)
        self.assertNotEqual(per_item, total_floor)

    def test_matches_saby_sum_of_line_discounts(self):
        lines = [(100, 1), (109, 2), (521, 1)]
        expected = 0
        for price, qty in lines:
            expected += (price - discounted_unit_price(price)) * qty

        self.assertEqual(pickup_discount_amount(lines), expected)

    def test_zero_percent_or_empty(self):
        self.assertEqual(pickup_discount_amount([(1000, 1)], percent=0), 0)
        self.assertEqual(pickup_discount_amount([]), 0)
