from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from .models import Customer, CustomerRefreshToken


@receiver(post_save, sender=Customer)
def revoke_disabled_customer_sessions(sender, instance, **kwargs):
    if not instance.is_active:
        now = timezone.now()
        sender.objects.filter(pk=instance.pk).update(tokens_revoked_at=now)
        instance.tokens_revoked_at = now
        CustomerRefreshToken.objects.filter(
            customer=instance, revoked_at__isnull=True,
        ).update(revoked_at=now)
