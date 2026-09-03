from django.test import SimpleTestCase

from catalog.placeholders import (
    promotion_placeholder_values,
    substitute_placeholders,
)


class PlaceholderTests(SimpleTestCase):
    def test_substitutes_promotion_percents(self):
        values = promotion_placeholder_values()
        text = (
            'Начисление {{earn_percent}}%, списание до '
            '{{max_spend_percent}}%, самовывоз {{pickup_discount_percent}}%.'
        )
        result = substitute_placeholders(text, values)

        self.assertIn(f"{values['earn_percent']}%", result)
        self.assertIn(f"{values['max_spend_percent']}%", result)
        self.assertIn(f"{values['pickup_discount_percent']}%", result)
        self.assertNotIn('{{', result)
