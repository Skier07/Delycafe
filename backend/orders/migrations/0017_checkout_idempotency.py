from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('orders', '0016_delivery_text_templates')]
    operations = [
        migrations.AddField(model_name='order', name='checkout_key',
                            field=models.UUIDField(null=True, blank=True, unique=True, editable=False)),
        migrations.AddField(model_name='order', name='checkout_fingerprint',
                            field=models.CharField(max_length=64, blank=True, editable=False)),
    ]
