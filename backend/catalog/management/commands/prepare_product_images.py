from django.core.management.base import BaseCommand, CommandError

from catalog.image_variants import refresh_image_variants
from catalog.models import Product, ProductGalleryImage


class Command(BaseCommand):
    help = 'Build 1254/3840 WebP renditions for existing product photos (no upscaling).'

    def add_arguments(self, parser):
        parser.add_argument('--product-id', type=int)

    def handle(self, *args, **options):
        failures = 0
        for model in (Product, ProductGalleryImage):
            rows = model.objects.exclude(image='').exclude(image__isnull=True)
            if options['product_id']:
                key = 'pk' if model is Product else 'product_id'
                rows = rows.filter(**{key: options['product_id']})
            for item in rows.iterator():
                try:
                    variants = refresh_image_variants(item)
                    self.stdout.write(f'{model.__name__} #{item.pk}: {len(variants)} versions')
                except Exception as exc:
                    failures += 1
                    self.stderr.write(f'{model.__name__} #{item.pk}: {exc}')
        if failures:
            raise CommandError(f'Failed to prepare {failures} photos; see errors above.')
