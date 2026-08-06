from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0011_order_payment_url_max_length'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='saby_bonus_applied',
            field=models.BooleanField(
                default=False,
                verbose_name='Бонусы применены в Saby',
            ),
        ),
    ]
