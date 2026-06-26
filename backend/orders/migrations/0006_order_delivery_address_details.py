from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0005_order_saby_external_id_order_saby_order_number_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='address_locality',
            field=models.CharField(
                blank=True,
                max_length=120,
                verbose_name='Населный пункт',
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='address_entrance',
            field=models.CharField(
                blank=True,
                max_length=20,
                verbose_name='Подъезд',
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='address_floor',
            field=models.CharField(
                blank=True,
                max_length=20,
                verbose_name='Этаж',
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='address_apartment',
            field=models.CharField(
                blank=True,
                max_length=20,
                verbose_name='Квартира',
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='saby_dispatch_error',
            field=models.TextField(
                blank=True,
                verbose_name='Ошибка отправки в Saby',
            ),
        ),
    ]
