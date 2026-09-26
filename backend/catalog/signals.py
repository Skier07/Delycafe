from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver

from catalog.gallery import sync_product_cover_image
from catalog.models import NewSabyProduct, Product, ProductGalleryImage
from catalog.image_variants import finish_image_change, prepare_image_change
from catalog.snippets import attach_default_snippets


for image_model in (Product, NewSabyProduct, ProductGalleryImage):
    pre_save.connect(prepare_image_change, sender=image_model)
    post_save.connect(finish_image_change, sender=image_model)


@receiver(post_save, sender=Product)
def attach_snippets_to_new_product(sender, instance, created, **kwargs):
    if created:
        attach_default_snippets(instance)


@receiver(post_save, sender=ProductGalleryImage)
@receiver(post_delete, sender=ProductGalleryImage)
def sync_cover_after_gallery_change(sender, instance, **kwargs):
    sync_product_cover_image(instance.product)
