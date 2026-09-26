from io import BytesIO, StringIO
from tempfile import TemporaryDirectory
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import TestCase, override_settings
from PIL import Image
from rest_framework.test import APIRequestFactory

from catalog.image_variants import build_image_variants
from catalog.models import Category, Product, ProductGalleryImage
from catalog.serializers import ProductSerializer


def photo(size=(1600, 1600), color=(200, 100, 40, 128)):
    out = BytesIO()
    im = Image.new('RGBA', size, color)
    im.putpixel((0, 0), (0, 0, 0, 0))
    im.save(out, 'PNG')
    return SimpleUploadedFile('pizza.png', out.getvalue(), content_type='image/png')


class ProductImageVariantsTests(TestCase):
    def setUp(self):
        tmp = TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        settings = override_settings(MEDIA_ROOT=tmp.name)
        settings.enable()
        self.addCleanup(settings.disable)
        category = Category.objects.create(title='Pizza', slug='pizza')
        self.product = Product.objects.create(category=category, title='Pizza')

    def test_upload_prepares_both_sizes_and_retains_alpha(self):
        self.product.image = photo((3840, 3840))
        self.product.save()
        self.product.refresh_from_db()
        self.assertEqual([v['width'] for v in self.product.image_variants], [1254, 3840])
        for variant in self.product.image_variants:
            with self.product.image.storage.open(variant['name']) as file:
                with Image.open(file) as im:
                    self.assertEqual(im.size, (variant['width'], variant['height']))
                    self.assertEqual(im.mode, 'RGBA')
                    self.assertEqual(im.getpixel((im.width // 2, im.height // 2))[3], 128)
        with self.product.image.storage.open(self.product.image.name) as file:
            with Image.open(file) as original:
                self.assertEqual(original.size, (3840, 3840))

    def test_small_source_is_not_upscaled_and_generation_is_reused(self):
        self.product.image = photo((600, 400))
        self.product.save()
        variants = self.product.image_variants
        self.assertEqual([(v['width'], v['height']) for v in variants], [(600, 400)])
        self.assertEqual(build_image_variants(self.product.image), variants)
        with patch('catalog.image_variants.build_image_variants') as build:
            self.product.title = 'Updated title'
            self.product.save()
        build.assert_not_called()

    def test_gallery_replacement_changes_cache_url_and_serializes_cover(self):
        entry = ProductGalleryImage.objects.create(product=self.product, image=photo((100, 100)))
        old = entry.image_variants[0]['name']
        entry.image = photo((100, 100), (30, 40, 50, 255))
        entry.save(update_fields=['image'])
        entry.refresh_from_db()
        self.assertNotEqual(entry.image_variants[0]['name'], old)
        self.product.refresh_from_db()
        request = APIRequestFactory().get('/')
        serializer = ProductSerializer(context={'request': request})
        cover = serializer.get_image(self.product)
        variants = serializer.get_image_variants(self.product)
        self.assertIn(cover, variants)
        self.assertTrue(variants[cover][0]['url'].startswith('http://testserver/media/'))

    def test_backfill_and_clear(self):
        self.product.image = photo((100, 100))
        self.product.save()
        Product.objects.filter(pk=self.product.pk).update(image_variants=[])
        call_command('prepare_product_images', product_id=self.product.pk, stdout=StringIO())
        self.product.refresh_from_db()
        self.assertTrue(self.product.image_variants)
        self.product.image = ''
        self.product.save(update_fields=['image'])
        self.product.refresh_from_db()
        self.assertEqual(self.product.image_variants, [])

    def test_missing_old_image_keeps_legacy_url_without_io_in_serializer(self):
        Product.objects.filter(pk=self.product.pk).update(image='products/missing.png')
        self.product.refresh_from_db()
        serializer = ProductSerializer()
        self.assertEqual(serializer.get_image_variants(self.product), {})
        self.assertTrue(serializer.get_image(self.product).endswith('products/missing.png'))
