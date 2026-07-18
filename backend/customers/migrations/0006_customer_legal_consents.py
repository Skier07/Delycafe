from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('customers', '0005_phone_auth_session'),
    ]

    operations = [
        migrations.AddField(
            model_name='customer',
            name='terms_accepted_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Пользовательское соглашение принято',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='privacy_accepted_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Политика конфиденциальности принята',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='pd_consent_accepted_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Согласие на обработку ПД',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='marketing_consent_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Согласие на рекламные сообщения',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='legal_docs_version',
            field=models.CharField(
                blank=True,
                max_length=32,
                verbose_name='Версия юридических документов',
            ),
        ),
    ]
