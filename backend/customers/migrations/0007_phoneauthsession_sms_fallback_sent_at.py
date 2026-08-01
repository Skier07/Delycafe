from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('customers', '0006_customer_legal_consents'),
    ]

    operations = [
        migrations.AddField(
            model_name='phoneauthsession',
            name='sms_fallback_sent_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Резервная SMS отправлена',
            ),
        ),
    ]
