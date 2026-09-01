from datetime import datetime, time
from zoneinfo import ZoneInfo

from django.test import TestCase
from django.utils import timezone

from catalog.models import (
    CatalogSnippet,
    Category,
    InfoSection,
    InfoStyle,
    Product,
    ProductInfoNote,
    ProductSnippet,
)
from catalog.preorder import cannot_order_message, product_can_order_now
from catalog.snippets import attach_default_snippets, resolve_info_blocks


class InfoBlocksTests(TestCase):
    def setUp(self):
        self.category = Category.objects.create(
            title='Бургеры',
            slug='burgers',
            show_in_app=True,
        )
        self.snippet = CatalogSnippet.objects.create(
            name='Почему стоит: Бургеры',
            section=InfoSection.WHY_TRY,
            text='Общий текст про булочку.',
            is_default=True,
            sort_order=10,
        )
        self.product = Product.objects.create(
            category=self.category,
            title='Бургер классический',
            price=320,
            is_active=True,
        )

    def test_new_product_gets_default_snippets(self):
        links = ProductSnippet.objects.filter(product=self.product)
        self.assertTrue(links.filter(snippet=self.snippet, is_enabled=True).exists())

    def test_override_text_replaces_snippet(self):
        link = ProductSnippet.objects.get(product=self.product, snippet=self.snippet)
        link.override_text = 'Только для этого бургера.'
        link.save(update_fields=['override_text'])

        blocks = resolve_info_blocks(self.product)
        self.assertEqual(blocks[0]['text'], 'Только для этого бургера.')

    def test_disabled_snippet_hidden(self):
        ProductSnippet.objects.filter(product=self.product).update(is_enabled=False)
        self.assertEqual(resolve_info_blocks(self.product), [])

    def test_custom_warning_note(self):
        ProductInfoNote.objects.create(
            product=self.product,
            section=InfoSection.IMPORTANT,
            text='Внимание! Только до 17:00.',
            style=InfoStyle.WARNING,
            sort_order=5,
        )

        blocks = resolve_info_blocks(self.product)
        warning = [block for block in blocks if block['style'] == 'warning']
        self.assertEqual(warning[0]['text'], 'Внимание! Только до 17:00.')


class PreorderCutoffTests(TestCase):
    def setUp(self):
        self.category = Category.objects.create(
            title='Пироги',
            slug='pirogi',
            show_in_app=True,
            preorder_cutoff_enabled=True,
            preorder_lead_days=1,
            preorder_cutoff_time=time(17, 0),
        )
        self.product = Product.objects.create(
            category=self.category,
            title='Пирог с капустой',
            price=450,
            is_active=True,
        )
        self.tz = ZoneInfo('Asia/Yekaterinburg')

    def test_can_order_before_cutoff(self):
        now = timezone.make_aware(datetime(2026, 9, 1, 16, 59), self.tz)
        self.assertTrue(product_can_order_now(self.product, now))

    def test_cannot_order_after_cutoff(self):
        now = timezone.make_aware(datetime(2026, 9, 1, 17, 0), self.tz)
        self.assertFalse(product_can_order_now(self.product, now))
        self.assertIn('17:00', cannot_order_message(self.category))

    def test_cannot_order_at_18_ural(self):
        now = timezone.make_aware(datetime(2026, 9, 1, 18, 0), self.tz)
        self.assertFalse(product_can_order_now(self.product, now))

    def test_disabled_cutoff_allows_order_after_time(self):
        self.category.preorder_cutoff_enabled = False
        self.category.save(update_fields=['preorder_cutoff_enabled'])
        now = timezone.make_aware(datetime(2026, 9, 1, 18, 0), self.tz)
        self.assertTrue(product_can_order_now(self.product, now))

    def test_attach_defaults_is_idempotent(self):
        created = attach_default_snippets(self.product)
        self.assertEqual(created, 0)
