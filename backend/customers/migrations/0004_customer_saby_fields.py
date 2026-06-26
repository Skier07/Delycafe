from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('customers', '0003_alter_bonustransaction_amount_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='customer',
            name='saby_customer_id',
            field=models.PositiveIntegerField(
                blank=True,
                null=True,
                verbose_name='ID клиента в Saby',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='saby_external_id',
            field=models.CharField(
                blank=True,
                max_length=64,
                null=True,
                unique=True,
                verbose_name='UUID клиента в Saby',
            ),
        ),
        migrations.AddField(
            model_name='customer',
            name='saby_synced_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                verbose_name='Дата синхронизации с Saby',
            ),
        ),
    ]
