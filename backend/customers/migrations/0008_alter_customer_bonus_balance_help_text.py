from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('customers', '0007_phoneauthsession_sms_fallback_sent_at'),
    ]

    operations = [
        migrations.AlterField(
            model_name='customer',
            name='bonus_balance',
            field=models.PositiveIntegerField(
                default=0,
                help_text=(
                    'Локальный баланс приложения. API Saby по телефону '
                    'недоступен — сверка с Presto вручную; sync из Saby '
                    'баланс не перезаписывает.'
                ),
                verbose_name='Бонусный баланс',
            ),
        ),
    ]
