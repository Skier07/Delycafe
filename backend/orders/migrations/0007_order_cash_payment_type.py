from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0006_order_delivery_address_details'),
    ]

    operations = [
        migrations.AlterField(
            model_name='order',
            name='payment_type',
            field=models.CharField(
                choices=[
                    ('card', 'Картой'),
                    ('sbp', 'СБП'),
                    ('cash', 'Наличкой'),
                ],
                default='card',
                max_length=20,
                verbose_name='Способ оплаты',
            ),
        ),
    ]
