from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase

from catalog.gallery import append_gallery_images, sync_product_cover_image
from catalog.models import Category, Product, ProductGalleryImage


class ProductGalleryTests(TestCase):
    def setUp(self):
        self.category = Category.objects.create(
            title='Бургеры',
            slug='burgers-gallery',
            show_in_app=True,
        )
        self.product = Product.objects.create(
            category=self.category,
            title='Бургер',
            price=300,
            is_active=True,
        )

    def _image_file(self, name: str) -> SimpleUploadedFile:
        return SimpleUploadedFile(
            name,
            b'fake-image-content',
            content_type='image/jpeg',
        )

    def test_append_gallery_images_updates_cover(self):
        created = append_gallery_images(
            self.product,
            [
                self._image_file('first.jpg'),
                self._image_file('second.jpg'),
            ],
        )

        self.assertEqual(created, 2)
        self.product.refresh_from_db()
        self.assertTrue(self.product.image)
        self.assertEqual(self.product.gallery_images.count(), 2)

    def test_sync_cover_uses_first_sorted_image(self):
        first = ProductGalleryImage.objects.create(
            product=self.product,
            image=self._image_file('cover.jpg'),
            sort_order=10,
        )
        ProductGalleryImage.objects.create(
            product=self.product,
            image=self._image_file('other.jpg'),
            sort_order=20,
        )

        sync_product_cover_image(self.product)
        self.product.refresh_from_db()

        self.assertEqual(self.product.image, first.image)
