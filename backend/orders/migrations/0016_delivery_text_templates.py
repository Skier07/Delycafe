from django.db import migrations, models


def configure_templates(apps, schema_editor):
    Zone = apps.get_model('orders', 'DeliveryZone')
    Section = apps.get_model('orders', 'DeliveryInfoSection')
    # Only replace known initial text; never overwrite an operator's custom notes.
    descriptions = {
        'ozersk': ('Озёрск: от 2000 ₽ бесплатно, от 1000 до 2000 ₽ — 250 ₽, до 1000 ₽ — 300 ₽',
                   '{{delivery_tariff:ozersk}}'),
        'promploshadka': ('Промплощадка: доставка 400 ₽', '{{delivery_tariff:promploshadka}}'),
        'tatysh': ('Татыш: доставка 550 ₽, минимальное время — около 2 часов',
                   '{{delivery_tariff:tatysh}}\nМинимальное время — около 2 часов.'),
    }
    for code, (old, new) in descriptions.items():
        Zone.objects.filter(code=code, checkout_description__in=[old, '']).update(checkout_description=new)
    Zone.objects.filter(code='promploshadka', checkout_description=(
        'Промплощадка: доставка 400 ₽. Адрес указывать не нужно — доставка на производственную территорию.'
    )).update(checkout_description=(
        '{{delivery_tariff:promploshadka}}\nАдрес указывать не нужно — доставка на производственную территорию.'
    ))
    Section.objects.filter(content=(
        'от 2000₽ — бесплатно\nот 1000 до 2000₽ — доставка 250₽\n< 1000₽ — доставка 300₽'
    )).update(content='{{delivery_tariff:ozersk}}')
    Section.objects.filter(content='Стоимость: 550₽\nМинимум: 2 часа').update(
        content='{{delivery_tariff:tatysh}}\nМинимум: 2 часа'
    )
    if Zone.objects.filter(code='promploshadka').exists() and not Section.objects.filter(
        content__contains='{{delivery_tariff:promploshadka}}'
    ).exists() and not Section.objects.filter(title__icontains='пром').exists():
        Section.objects.create(title='Доставка на промплощадку', content='{{delivery_tariff:promploshadka}}', sort_order=45)


class Migration(migrations.Migration):
    dependencies = [('orders', '0015_promploshadka_no_address')]
    operations = [
        migrations.AlterField(
            model_name='deliveryzone', name='checkout_description',
            field=models.TextField(blank=True, verbose_name='Описание в оформлении заказа',
                help_text='Для актуальной цены используйте {{delivery_tariff:код_зоны}}, например {{delivery_tariff:ozersk}}. Остальной текст можно редактировать.'),
        ),
        migrations.AlterField(
            model_name='deliveryinfosection', name='content',
            field=models.TextField(verbose_name='Текст',
                help_text='Автоматические тарифы: {{delivery_tariff:ozersk}}, {{delivery_tariff:promploshadka}}, {{delivery_tariff:tatysh}}. Вместо метки приложение получит актуальные цены.'),
        ),
        migrations.RunPython(configure_templates, migrations.RunPython.noop),
    ]
