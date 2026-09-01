from django.db import migrations, models


def enable_cutoff_for_pies(apps, schema_editor):
    Category = apps.get_model('catalog', 'Category')
    Category.objects.filter(title='Пироги').update(preorder_cutoff_enabled=True)


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0007_product_info_blocks_and_preorder'),
    ]

    operations = [
        migrations.AddField(
            model_name='category',
            name='preorder_cutoff_enabled',
            field=models.BooleanField(
                default=False,
                help_text='Если включено и указано время «Принимать заказы до», после этого времени (по Уралу) товары категории нельзя заказать.',
                verbose_name='Ограничение по времени заказа',
            ),
        ),
        migrations.RunPython(enable_cutoff_for_pies, migrations.RunPython.noop),
    ]
