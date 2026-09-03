from django.db import migrations


def set_promploshadka_no_address(apps, schema_editor):
    DeliveryZone = apps.get_model('orders', 'DeliveryZone')
    DeliveryZone.objects.filter(code='promploshadka').update(
        requires_address=False,
        checkout_description=(
            'Промплощадка: доставка 400 ₽. Адрес указывать не нужно — '
            'доставка на производственную территорию.'
        ),
    )


def revert_promploshadka(apps, schema_editor):
    DeliveryZone = apps.get_model('orders', 'DeliveryZone')
    DeliveryZone.objects.filter(code='promploshadka').update(
        requires_address=True,
        checkout_description='Промплощадка: доставка 400 ₽',
    )


class Migration(migrations.Migration):
    dependencies = [
        ('orders', '0014_delivery_zones'),
    ]

    operations = [
        migrations.RunPython(
            set_promploshadka_no_address,
            revert_promploshadka,
        ),
    ]
