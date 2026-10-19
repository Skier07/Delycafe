from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('customers', '0009_customerrefreshtoken')]
    operations = [
        migrations.AddField(model_name='customer', name='tokens_revoked_at',
                            field=models.DateTimeField(null=True, blank=True, editable=False)),
        migrations.AddField(model_name='phoneauthsession', name='session_secret_hash',
                            field=models.CharField(max_length=64, blank=True, editable=False)),
        migrations.AddField(model_name='phoneauthsession', name='consumed_at',
                            field=models.DateTimeField(null=True, blank=True, editable=False)),
    ]
