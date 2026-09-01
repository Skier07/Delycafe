from django.db.models.signals import post_save
from django.dispatch import receiver

from catalog.models import Product
from catalog.snippets import attach_default_snippets


@receiver(post_save, sender=Product)
def attach_snippets_to_new_product(sender, instance, created, **kwargs):
    if created:
        attach_default_snippets(instance)
