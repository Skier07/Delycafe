from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings
from PIL import Image

from catalog.models import Category, Product, ProductGalleryImage


class NormalizeGalleryPathsTests(TestCase):
    def setUp(self):
        self.tmp = TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        setting = override_settings(MEDIA_ROOT=self.root / 'media', BASE_DIR=self.root)
        setting.enable()
        self.addCleanup(setting.disable)
        category = Category.objects.create(title='Pizza', slug='pizza')
        self.product = Product.objects.create(category=category, title='Pizza')
        self.old = 'products/pizza/test.png'
        self.new = 'products/gallery/test.png'
        Product.objects.filter(pk=self.product.pk).update(image=self.old)

    def photo(self, name, color='red'):
        path = self.root / 'media' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new('RGBA', (8, 8), color).save(path)

    def run_command(self, apply=False):
        call_command('normalize_gallery_paths', apply=apply,
                     stdout=StringIO(), stderr=StringIO())

    def test_updates_both_models_and_preserves_original_files(self):
        self.photo(self.old)
        self.photo(self.new)
        ProductGalleryImage.objects.bulk_create([
            ProductGalleryImage(product=self.product, image=self.old, sort_order=20)])
        self.run_command(apply=True)
        self.product.refresh_from_db()
        self.assertEqual(self.product.image.name, self.new)
        self.assertEqual(self.product.gallery_images.get().image.name, self.new)
        self.assertEqual(self.product.gallery_images.get().sort_order, 20)
        self.assertTrue(self.product.image_variants)
        self.assertTrue((self.root / 'media' / self.old).exists())
        self.assertEqual(len(list((self.root / 'backups').glob('*.json'))), 1)
        self.run_command(apply=True)
        self.product.refresh_from_db()
        self.assertEqual(self.product.image.name, self.new)

    def test_dry_run_does_not_change_paths(self):
        self.photo(self.new)
        self.run_command()
        self.product.refresh_from_db()
        self.assertEqual(self.product.image.name, self.old)

    def test_different_content_is_not_substituted(self):
        self.photo(self.old)
        self.photo(self.new, 'blue')
        with self.assertRaises(CommandError):
            self.run_command(apply=True)
        self.product.refresh_from_db()
        self.assertEqual(self.product.image.name, self.old)

    def test_missing_target_is_not_substituted(self):
        self.photo(self.old)
        with self.assertRaises(CommandError):
            self.run_command(apply=True)
        self.product.refresh_from_db()
        self.assertEqual(self.product.image.name, self.old)
