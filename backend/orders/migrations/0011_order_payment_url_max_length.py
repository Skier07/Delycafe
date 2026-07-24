from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0010_order_admin_email_sent_at'),
    ]

    operations = [
        migrations.AlterField(
            model_name='order',
            name='payment_url',
            field=models.URLField(
                blank=True,
                max_length=512,
                verbose_name='Ссылка на оплату',
            ),
        ),
    ]
