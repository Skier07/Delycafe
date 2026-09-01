# Generated manually for configurable info block sections and rich content.

import catalog.info_content
from django.db import migrations, models
import django.db.models.deletion


def seed_info_sections(apps, schema_editor):
    InfoSectionDefinition = apps.get_model('catalog', 'InfoSectionDefinition')

    InfoSectionDefinition.objects.get_or_create(
        code='why_try',
        defaults={
            'title': 'Почему стоит попробовать',
            'sort_order': 10,
        },
    )
    InfoSectionDefinition.objects.get_or_create(
        code='important',
        defaults={
            'title': 'Что важно знать',
            'sort_order': 20,
        },
    )


def migrate_snippet_sections(apps, schema_editor):
    InfoSectionDefinition = apps.get_model('catalog', 'InfoSectionDefinition')
    CatalogSnippet = apps.get_model('catalog', 'CatalogSnippet')
    ProductInfoNote = apps.get_model('catalog', 'ProductInfoNote')

    section_map = {
        definition.code: definition
        for definition in InfoSectionDefinition.objects.all()
    }

    for snippet in CatalogSnippet.objects.all():
        section_code = getattr(snippet, 'section', 'important')
        definition = section_map.get(section_code) or section_map['important']
        snippet.info_section_id = definition.id
        snippet.content = catalog.info_content.parse_content(
            None,
            getattr(snippet, 'text', '') or '',
        )
        snippet.save(update_fields=['info_section_id', 'content'])

    for note in ProductInfoNote.objects.all():
        section_code = getattr(note, 'section', 'important')
        definition = section_map.get(section_code) or section_map['important']
        note.info_section_id = definition.id
        note.content = catalog.info_content.parse_content(
            None,
            getattr(note, 'text', '') or '',
        )
        note.save(update_fields=['info_section_id', 'content'])


def unseed_info_sections(apps, schema_editor):
    InfoSectionDefinition = apps.get_model('catalog', 'InfoSectionDefinition')
    InfoSectionDefinition.objects.filter(
        code__in=['why_try', 'important'],
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0008_category_preorder_cutoff_enabled'),
    ]

    operations = [
        migrations.CreateModel(
            name='InfoSectionDefinition',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                (
                    'code',
                    models.SlugField(
                        max_length=50,
                        unique=True,
                        verbose_name='Код (для API)',
                    ),
                ),
                (
                    'title',
                    models.CharField(
                        max_length=120,
                        verbose_name='Заголовок в приложении',
                    ),
                ),
                (
                    'sort_order',
                    models.PositiveIntegerField(
                        default=0,
                        verbose_name='Порядок',
                    ),
                ),
                (
                    'is_active',
                    models.BooleanField(
                        default=True,
                        verbose_name='Активен',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Тип блока информации',
                'verbose_name_plural': 'Типы блоков информации',
                'ordering': ['sort_order', 'id'],
            },
        ),
        migrations.RunPython(seed_info_sections, unseed_info_sections),
        migrations.AddField(
            model_name='catalogsnippet',
            name='content',
            field=models.JSONField(
                blank=True,
                default=dict,
                verbose_name='Содержимое',
            ),
        ),
        migrations.AddField(
            model_name='catalogsnippet',
            name='info_section',
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='snippets',
                to='catalog.infosectiondefinition',
                verbose_name='Блок в карточке',
            ),
        ),
        migrations.AddField(
            model_name='productinfonote',
            name='content',
            field=models.JSONField(
                blank=True,
                default=dict,
                verbose_name='Содержимое',
            ),
        ),
        migrations.AddField(
            model_name='productinfonote',
            name='info_section',
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='product_notes',
                to='catalog.infosectiondefinition',
                verbose_name='Блок в карточке',
            ),
        ),
        migrations.AddField(
            model_name='productsnippet',
            name='override_content',
            field=models.JSONField(
                blank=True,
                default=dict,
                verbose_name='Свой текст для этого товара',
            ),
        ),
        migrations.AlterField(
            model_name='catalogsnippet',
            name='text',
            field=models.TextField(
                blank=True,
                help_text='Заполняется автоматически из редактора.',
                verbose_name='Текст (поиск)',
            ),
        ),
        migrations.AlterField(
            model_name='productinfonote',
            name='text',
            field=models.TextField(
                blank=True,
                help_text='Заполняется автоматически из редактора.',
                verbose_name='Текст (поиск)',
            ),
        ),
        migrations.AlterField(
            model_name='productsnippet',
            name='override_text',
            field=models.TextField(
                blank=True,
                help_text='Используйте редактор ниже. Это поле только для совместимости.',
                verbose_name='Свой текст (устар.)',
            ),
        ),
        migrations.RunPython(migrate_snippet_sections, migrations.RunPython.noop),
        migrations.RemoveField(
            model_name='catalogsnippet',
            name='section',
        ),
        migrations.RemoveField(
            model_name='productinfonote',
            name='section',
        ),
        migrations.AlterField(
            model_name='catalogsnippet',
            name='info_section',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='snippets',
                to='catalog.infosectiondefinition',
                verbose_name='Блок в карточке',
            ),
        ),
        migrations.AlterField(
            model_name='productinfonote',
            name='info_section',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='product_notes',
                to='catalog.infosectiondefinition',
                verbose_name='Блок в карточке',
            ),
        ),
    ]
