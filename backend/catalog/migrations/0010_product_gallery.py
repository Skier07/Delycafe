# Generated manually for product gallery images.

from django.db import migrations, models
import django.db.models.deletion


def migrate_product_images_to_gallery(apps, schema_editor):
    Product = apps.get_model('catalog', 'Product')
    ProductGalleryImage = apps.get_model('catalog', 'ProductGalleryImage')

    for product in Product.objects.exclude(image='').exclude(image=None):
        if product.image:
            ProductGalleryImage.objects.create(
                product_id=product.id,
                image=product.image,
                sort_order=100,
            )


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0009_info_section_definitions'),
    ]

    operations = [
        migrations.CreateModel(
            name='ProductGalleryImage',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                (
                    'image',
                    models.ImageField(
                        upload_to='products/gallery/',
                        verbose_name='Фото',
                    ),
                ),
                (
                    'sort_order',
                    models.PositiveIntegerField(
                        default=500,
                        verbose_name='Порядок',
                    ),
                ),
                (
                    'product',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='gallery_images',
                        to='catalog.product',
                        verbose_name='Товар',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Фото товара',
                'verbose_name_plural': 'Фото товара',
                'ordering': ['sort_order', 'id'],
            },
        ),
        migrations.RunPython(
            migrate_product_images_to_gallery,
            migrations.RunPython.noop,
        ),
    ]
