from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('orders', '0007_order_cash_payment_type'),
    ]

    operations = [
        migrations.AlterField(
            model_name='order',
            name='payment_type',
            field=models.CharField(
                choices=[('card', 'Картой'), ('sbp', 'СБП')],
                default='card',
                max_length=20,
                verbose_name='Способ оплаты',
            ),
        ),
    ]
