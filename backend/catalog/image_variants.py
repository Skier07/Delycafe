"""Prepare public catalog renditions at upload time, never in catalog GETs."""
import hashlib
import logging
from io import BytesIO

from django.core.files.base import ContentFile
from PIL import Image, ImageOps

logger = logging.getLogger(__name__)
IMAGE_SIZES = (1254, 3840)


def build_image_variants(field):
    if not field:
        return []
    storage = field.storage
    with storage.open(field.name, 'rb') as source:
        data = source.read()
    # Content keys also invalidate device caches when a file is replaced in place.
    digest = hashlib.sha256(data).hexdigest()
    variants = []
    seen_sizes = set()
    with Image.open(BytesIO(data)) as source:
        original = ImageOps.exif_transpose(source).convert('RGBA')
        for edge in IMAGE_SIZES:
            scale = min(1, edge / max(original.size))
            size = tuple(max(1, round(value * scale)) for value in original.size)
            if size in seen_sizes:
                continue
            seen_sizes.add(size)
            name = f'products/renditions/v1/{digest}/{edge}.webp'
            if not storage.exists(name):
                # Pillow RGBA resizing uses premultiplied alpha: no white fringe.
                resized = original.resize(size, Image.Resampling.LANCZOS)
                output = BytesIO()
                resized.save(output, format='WEBP', quality=90, method=6)
                name = storage.save(name, ContentFile(output.getvalue()))
            variants.append({'name': name, 'width': size[0], 'height': size[1]})
    return variants


def refresh_image_variants(instance):
    variants = build_image_variants(instance.image)
    # Do not attach stale results if another upload won a concurrent update.
    updated = type(instance).objects.filter(
        pk=instance.pk, image=instance.image.name or '',
    ).update(image_variants=variants)
    if updated:
        instance.image_variants = variants
    return variants


def prepare_image_change(sender, instance, raw=False, update_fields=None, **kwargs):
    if raw or (update_fields is not None and 'image' not in update_fields):
        instance._prepare_image_variants = False
        return
    previous = sender.objects.filter(pk=instance.pk).values_list('image', flat=True).first()
    instance._prepare_image_variants = (
        not instance.image._committed or (previous or '') != (instance.image.name or '')
    )
    if instance._prepare_image_variants:
        instance.image_variants = []


def finish_image_change(sender, instance, raw=False, **kwargs):
    if raw or not getattr(instance, '_prepare_image_variants', False):
        return
    instance._prepare_image_variants = False
    try:
        refresh_image_variants(instance)
    except Exception:
        # A damaged/missing photo must not prevent saving a product or sync.
        sender.objects.filter(
            pk=instance.pk, image=instance.image.name or '',
        ).update(image_variants=[])
        instance.image_variants = []
        logger.exception('Could not prepare catalog photo %s', instance.image.name)
