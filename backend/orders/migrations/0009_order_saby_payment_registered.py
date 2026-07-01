from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0008_remove_cash_payment_type'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='saby_payment_registered',
            field=models.BooleanField(
                default=False,
                verbose_name='Оплата зарегистрирована в Saby',
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='saby_payment_error',
            field=models.TextField(
                blank=True,
                verbose_name='Ошибка регистрации оплаты в Saby',
            ),
        ),
    ]
