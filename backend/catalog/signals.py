from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from catalog.gallery import sync_product_cover_image
from catalog.models import Product, ProductGalleryImage
from catalog.snippets import attach_default_snippets


@receiver(post_save, sender=Product)
def attach_snippets_to_new_product(sender, instance, created, **kwargs):
    if created:
        attach_default_snippets(instance)


@receiver(post_save, sender=ProductGalleryImage)
@receiver(post_delete, sender=ProductGalleryImage)
def sync_cover_after_gallery_change(sender, instance, **kwargs):
    sync_product_cover_image(instance.product)
