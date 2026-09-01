from datetime import time

from django.db import migrations, models
import django.db.models.deletion


WHY_TRY_BY_CATEGORY = {
    'Пицца': (
        'Отличный вариант для тех, кто любит насыщенный вкус, тянущийся сыр '
        'и сытную подачу. Подходит как для одного плотного приёма пищи, так и для компании.'
    ),
    'Шаурма': (
        'Сытный вариант для быстрого перекуса. Хорошо подойдёт, когда хочется '
        'горячее блюдо без долгого ожидания.'
    ),
    'Бургеры': (
        'Хороший выбор для любителей сочной начинки, мягкой булочки и насыщенного вкуса.'
    ),
    'Фастфуд': (
        'Удобная позиция к основному заказу или как самостоятельный перекус. '
        'Особенно хорошо подходит для компании.'
    ),
    'Картошечка в фольге': (
        'Сытная горячая позиция, которую можно взять отдельно или дополнить начинкой по вкусу.'
    ),
    'Соусы': (
        'Подходит как дополнение к картошке, шаурме, бургерам, закускам и другим позициям меню.'
    ),
    'Напитки': (
        'Хорошо дополняет заказ и помогает сбалансировать вкус основных блюд.'
    ),
    'Десерты': (
        'Подходит в конце заказа, если хочется добавить что-то сладкое и завершить приём пищи.'
    ),
    'Паста': (
        'Горячее и сытное блюдо с насыщенным вкусом. Подходит как самостоятельная позиция.'
    ),
    'Пироги': (
        'Сытная выпечка для одного или нескольких человек. Хороший вариант к обеду или ужину.'
    ),
    'Салаты': (
        'Лёгкое дополнение к основному блюду или самостоятельная позиция для тех, '
        'кто хочет что-то свежее.'
    ),
    'Супы': (
        'Горячее первое блюдо, которое хорошо подходит для полноценного обеда.'
    ),
}

DEFAULT_WHY_TRY = (
    'Вкусная позиция из меню, которую можно добавить к основному заказу '
    'или взять как самостоятельный вариант.'
)

IMPORTANT_TEXTS = (
    (
        'Внешний вид',
        'Состав и внешний вид могут немного отличаться в зависимости от партии ингредиентов.',
        10,
    ),
    (
        'Готовится после заказа',
        'Блюдо готовится после оформления заказа.',
        20,
    ),
)

PIE_WARNING = (
    'Внимание! Заказы на пироги принимаются минимум за сутки. '
    'Если вы хотите заказать пирог на завтра, вы можете оформить заказ сегодня до 17 часов!'
)


def seed_snippets(apps, schema_editor):
    Category = apps.get_model('catalog', 'Category')
    CatalogSnippet = apps.get_model('catalog', 'CatalogSnippet')
    Product = apps.get_model('catalog', 'Product')
    ProductSnippet = apps.get_model('catalog', 'ProductSnippet')

    important_snippets = []

    for name, text, sort_order in IMPORTANT_TEXTS:
        snippet, _ = CatalogSnippet.objects.get_or_create(
            name=name,
            defaults={
                'section': 'important',
                'text': text,
                'style': 'normal',
                'is_default': True,
                'sort_order': sort_order,
            },
        )
        important_snippets.append(snippet)

    category_snippets = {}

    for title, text in WHY_TRY_BY_CATEGORY.items():
        category = Category.objects.filter(title=title).first()
        snippet, _ = CatalogSnippet.objects.get_or_create(
            name=f'Почему стоит: {title}',
            defaults={
                'section': 'why_try',
                'text': text,
                'style': 'normal',
                'is_default': False,
                'default_for_category_id': category.id if category else None,
                'sort_order': 10,
            },
        )

        if category and snippet.default_for_category_id is None:
            snippet.default_for_category = category
            snippet.save(update_fields=['default_for_category'])

        category_snippets[title] = snippet

    default_why_try, _ = CatalogSnippet.objects.get_or_create(
        name='Почему стоит: общее',
        defaults={
            'section': 'why_try',
            'text': DEFAULT_WHY_TRY,
            'style': 'normal',
            'is_default': False,
            'sort_order': 10,
        },
    )

    pies = Category.objects.filter(title='Пироги').first()

    if pies:
        pies.preorder_lead_days = 1
        pies.preorder_cutoff_time = time(17, 0)
        pies.save(update_fields=['preorder_lead_days', 'preorder_cutoff_time'])

        pie_warning, _ = CatalogSnippet.objects.get_or_create(
            name='Пироги: заказ за сутки',
            defaults={
                'section': 'important',
                'text': PIE_WARNING,
                'style': 'warning',
                'is_default': False,
                'default_for_category': pies,
                'sort_order': 5,
            },
        )
    else:
        pie_warning = None

    for product in Product.objects.select_related('category').all():
        for snippet in important_snippets:
            ProductSnippet.objects.get_or_create(
                product=product,
                snippet=snippet,
                defaults={'is_enabled': True},
            )

        category_title = product.category.title if product.category_id else ''
        why_try = category_snippets.get(category_title, default_why_try)
        ProductSnippet.objects.get_or_create(
            product=product,
            snippet=why_try,
            defaults={'is_enabled': True},
        )

        if pie_warning and category_title == 'Пироги':
            ProductSnippet.objects.get_or_create(
                product=product,
                snippet=pie_warning,
                defaults={'is_enabled': True},
            )


def unseed_snippets(apps, schema_editor):
    CatalogSnippet = apps.get_model('catalog', 'CatalogSnippet')
    CatalogSnippet.objects.filter(
        name__in=[
            'Внешний вид',
            'Готовится после заказа',
            'Почему стоит: общее',
            'Пироги: заказ за сутки',
            *[f'Почему стоит: {title}' for title in WHY_TRY_BY_CATEGORY],
        ]
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0006_product_manual_category'),
    ]

    operations = [
        migrations.AddField(
            model_name='category',
            name='preorder_cutoff_time',
            field=models.TimeField(
                blank=True,
                help_text='После этого времени сегодня товары категории нельзя заказать. Например 17:00 для пирогов.',
                null=True,
                verbose_name='Принимать заказы до',
            ),
        ),
        migrations.AddField(
            model_name='category',
            name='preorder_lead_days',
            field=models.PositiveIntegerField(
                default=0,
                help_text='0 — без ограничения. 1 — заказ минимум на завтра.',
                verbose_name='Заказывать минимум за (суток)',
            ),
        ),
        migrations.CreateModel(
            name='CatalogSnippet',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=120, verbose_name='Название в админке')),
                ('section', models.CharField(choices=[('why_try', 'Почему стоит попробовать'), ('important', 'Что важно знать')], default='important', max_length=20, verbose_name='Блок в карточке')),
                ('text', models.TextField(verbose_name='Текст')),
                ('style', models.CharField(choices=[('normal', 'Обычный'), ('warning', 'Предупреждение')], default='normal', max_length=20, verbose_name='Оформление')),
                ('is_default', models.BooleanField(default=False, verbose_name='Подключать ко всем новым товарам')),
                ('sort_order', models.PositiveIntegerField(default=100)),
                ('default_for_category', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='default_snippets', to='catalog.category', verbose_name='Подключать к новым товарам категории')),
            ],
            options={
                'verbose_name': 'Текстовый блок',
                'verbose_name_plural': 'Текстовые блоки',
                'ordering': ['section', 'sort_order', 'id'],
            },
        ),
        migrations.CreateModel(
            name='ProductSnippet',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('is_enabled', models.BooleanField(default=True, verbose_name='Показывать')),
                ('override_text', models.TextField(blank=True, help_text='Пусто — берётся общий текст блока.', verbose_name='Свой текст для этого товара')),
                ('product', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='product_snippets', to='catalog.product')),
                ('snippet', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='product_links', to='catalog.catalogsnippet')),
            ],
            options={
                'verbose_name': 'Блок товара',
                'verbose_name_plural': 'Блоки товара',
                'unique_together': {('product', 'snippet')},
            },
        ),
        migrations.CreateModel(
            name='ProductInfoNote',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('section', models.CharField(choices=[('why_try', 'Почему стоит попробовать'), ('important', 'Что важно знать')], default='important', max_length=20, verbose_name='Блок в карточке')),
                ('text', models.TextField(verbose_name='Текст')),
                ('style', models.CharField(choices=[('normal', 'Обычный'), ('warning', 'Предупреждение')], default='warning', max_length=20, verbose_name='Оформление')),
                ('sort_order', models.PositiveIntegerField(default=500)),
                ('product', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='info_notes', to='catalog.product')),
            ],
            options={
                'verbose_name': 'Свой текст товара',
                'verbose_name_plural': 'Свои тексты товара',
                'ordering': ['sort_order', 'id'],
            },
        ),
        migrations.RunPython(seed_snippets, unseed_snippets),
    ]
