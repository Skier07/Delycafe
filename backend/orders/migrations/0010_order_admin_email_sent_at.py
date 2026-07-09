from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0009_order_saby_payment_registered'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='admin_email_sent_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Письмо администратору отправлено',
            ),
        ),
    ]
