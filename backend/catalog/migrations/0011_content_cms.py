from django.db import migrations, models
import django.db.models.deletion


def seed_content(apps, schema_editor):
    ContentPost = apps.get_model('catalog', 'ContentPost')
    AppPageContent = apps.get_model('catalog', 'AppPageContent')

    if not ContentPost.objects.filter(post_type='news', title='Скидка в день рождения').exists():
        ContentPost.objects.create(
            post_type='news',
            title='Скидка в день рождения',
            body={
                'lines': [
                    {
                        'type': 'text',
                        'text': (
                            'Скидка 20% в день вашего рождения '
                            '(за 2 дня до и после даты).'
                        ),
                        'marker': 'none',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': 'Скидка не распространяется на пироги.',
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': (
                            'Чтобы получить скидку, ИМЕНИННИК должен предъявить '
                            'паспорт. Предъявить чужой паспорт не получится.'
                        ),
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': (
                            'Если день рождения отмечает ребенок — нужен '
                            'паспорт родителей.'
                        ),
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': 'Внимание! Скидка 1 раз в год (1 заказ).',
                        'marker': 'none',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '#b42318',
                        'bold': True,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                ],
            },
            plain_text='',
            is_published=True,
            sort_order=100,
        )

    AppPageContent.objects.update_or_create(
        key='bonus_rules',
        defaults={
            'title': 'Как работают бонусы',
            'body': {
                'lines': [
                    {
                        'type': 'text',
                        'text': (
                            'После заказа начисляется {{earn_percent}}% '
                            'бонусами от суммы заказа.'
                        ),
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': '1 бонус = 1 ₽.',
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': (
                            'Бонусами можно оплатить до {{max_spend_percent}}% '
                            'суммы заказа. Если бонусов меньше — спишутся '
                            'все имеющиеся.'
                        ),
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                    {
                        'type': 'text',
                        'text': (
                            'При самовывозе действует скидка '
                            '{{pickup_discount_percent}}% на сумму заказа '
                            'только в мобильном приложении.'
                        ),
                        'marker': 'bullet',
                        'font_size': 'normal',
                        'font_family': 'default',
                        'align': 'left',
                        'color': '',
                        'bold': False,
                        'italic': False,
                        'underline': False,
                        'image_url': '',
                        'full_bleed': False,
                    },
                ],
            },
            'plain_text': '',
        },
    )


def unseed_content(apps, schema_editor):
    ContentPost = apps.get_model('catalog', 'ContentPost')
    AppPageContent = apps.get_model('catalog', 'AppPageContent')
    ContentPost.objects.filter(
        post_type='news',
        title='Скидка в день рождения',
    ).delete()
    AppPageContent.objects.filter(key='bonus_rules').delete()


class Migration(migrations.Migration):
    dependencies = [
        ('catalog', '0010_product_gallery'),
    ]

    operations = [
        migrations.CreateModel(
            name='ContentPost',
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
                    'post_type',
                    models.CharField(
                        choices=[('news', 'Новость'), ('promo', 'Акция')],
                        max_length=20,
                        verbose_name='Тип',
                    ),
                ),
                ('title', models.CharField(max_length=200, verbose_name='Заголовок')),
                (
                    'cover_image',
                    models.ImageField(
                        blank=True,
                        null=True,
                        upload_to='content/covers/',
                        verbose_name='Обложка',
                    ),
                ),
                (
                    'body',
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text=(
                            'Плейсхолдеры процентов: {{earn_percent}}, '
                            '{{max_spend_percent}}, {{pickup_discount_percent}} — '
                            'подставятся из настроек промо автоматически.'
                        ),
                        verbose_name='Текст и оформление',
                    ),
                ),
                (
                    'plain_text',
                    models.TextField(blank=True, verbose_name='Текст (поиск)'),
                ),
                (
                    'is_published',
                    models.BooleanField(default=True, verbose_name='Опубликовано'),
                ),
                (
                    'sort_order',
                    models.PositiveIntegerField(default=500, verbose_name='Порядок'),
                ),
                (
                    'published_at',
                    models.DateTimeField(
                        blank=True,
                        null=True,
                        verbose_name='Дата публикации',
                    ),
                ),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Новость / акция',
                'verbose_name_plural': 'Новости и акции',
                'ordering': ['sort_order', '-published_at', '-id'],
            },
        ),
        migrations.CreateModel(
            name='AppPageContent',
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
                    'key',
                    models.CharField(
                        choices=[('bonus_rules', 'Как работают бонусы')],
                        max_length=60,
                        unique=True,
                        verbose_name='Страница',
                    ),
                ),
                (
                    'title',
                    models.CharField(
                        default='Как работают бонусы',
                        max_length=200,
                        verbose_name='Заголовок',
                    ),
                ),
                (
                    'body',
                    models.JSONField(
                        blank=True,
                        default=dict,
                        help_text=(
                            'Используйте {{earn_percent}}, {{max_spend_percent}}, '
                            '{{pickup_discount_percent}} — проценты подставятся '
                            'из API промо.'
                        ),
                        verbose_name='Текст и оформление',
                    ),
                ),
                (
                    'plain_text',
                    models.TextField(blank=True, verbose_name='Текст (поиск)'),
                ),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Текст страницы приложения',
                'verbose_name_plural': 'Тексты страниц приложения',
            },
        ),
        migrations.CreateModel(
            name='ContentPostImage',
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
                    'image',
                    models.ImageField(
                        upload_to='content/images/',
                        verbose_name='Картинка',
                    ),
                ),
                (
                    'sort_order',
                    models.PositiveIntegerField(default=500, verbose_name='Порядок'),
                ),
                (
                    'post',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='images',
                        to='catalog.contentpost',
                        verbose_name='Материал',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Картинка материала',
                'verbose_name_plural': 'Картинки материала',
                'ordering': ['sort_order', 'id'],
            },
        ),
        migrations.RunPython(seed_content, unseed_content),
    ]
