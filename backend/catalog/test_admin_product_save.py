from django.contrib.auth import get_user_model
from django.test import Client, TestCase

from catalog.models import Category, InfoSectionDefinition, Product


class ProductAdminSaveTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.admin = user_model.objects.create_superuser(
            username='admin',
            email='admin@test.com',
            password='password',
        )
        self.client = Client()
        self.client.force_login(self.admin)

        self.category = Category.objects.create(
            title='Пироги',
            slug='pies-admin',
            show_in_app=True,
        )
        self.product = Product.objects.create(
            category=self.category,
            title='Пирог тест',
            price=500,
            is_active=True,
        )
        self.important = InfoSectionDefinition.objects.get(code='important')

    def test_save_product_change_form(self):
        url = f'/admin/catalog/product/{self.product.pk}/change/'
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)

        post_data = {
            'category': str(self.category.pk),
            'manual_category': 'on',
            'title': 'Пирог тест',
            'description': '',
            'saby_id': '',
            'saby_name': '',
            'source': 'manual',
            'needs_review': '',
            'price': '500',
            'weight': '',
            'has_variants': '',
            'is_active': 'on',
            'is_hit': '',
            'is_new': '',
            'sort_order': '500',
            'gallery_images-TOTAL_FORMS': '1',
            'gallery_images-INITIAL_FORMS': '0',
            'gallery_images-MIN_NUM_FORMS': '0',
            'gallery_images-MAX_NUM_FORMS': '1000',
            'gallery_images-0-id': '',
            'gallery_images-0-product': str(self.product.pk),
            'gallery_images-0-sort_order': '500',
            'variants-TOTAL_FORMS': '0',
            'variants-INITIAL_FORMS': '0',
            'variants-MIN_NUM_FORMS': '0',
            'variants-MAX_NUM_FORMS': '1000',
            'product_snippets-TOTAL_FORMS': '0',
            'product_snippets-INITIAL_FORMS': '0',
            'product_snippets-MIN_NUM_FORMS': '0',
            'product_snippets-MAX_NUM_FORMS': '1000',
            'info_notes-TOTAL_FORMS': '1',
            'info_notes-INITIAL_FORMS': '0',
            'info_notes-MIN_NUM_FORMS': '0',
            'info_notes-MAX_NUM_FORMS': '1000',
            'info_notes-0-id': '',
            'info_notes-0-product': str(self.product.pk),
            'info_notes-0-info_section': '',
            'info_notes-0-content': '{"lines":[]}',
            'info_notes-0-style': 'warning',
            'info_notes-0-sort_order': '500',
        }

        response = self.client.post(url, post_data, follow=True)
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, 'Server Error')
