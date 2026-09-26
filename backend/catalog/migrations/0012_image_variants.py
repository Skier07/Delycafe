from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('catalog', '0011_content_cms')]
    operations = [
        migrations.AddField(
            model_name=name,
            name='image_variants',
            field=models.JSONField(default=list, blank=True, editable=False),
        )
        for name in ('product', 'productgalleryimage')
    ]
