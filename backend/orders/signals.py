from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .delivery_pricing import clear_delivery_zone_cache
from .models import DeliveryPriceTier, DeliveryZone


@receiver(post_save, sender=DeliveryZone)
@receiver(post_delete, sender=DeliveryZone)
@receiver(post_save, sender=DeliveryPriceTier)
@receiver(post_delete, sender=DeliveryPriceTier)
def _clear_delivery_zone_cache(*args, **kwargs):
    clear_delivery_zone_cache()
