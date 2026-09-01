# Generated manually for delivery zones configuration.

from django.db import migrations, models


def seed_delivery_config(apps, schema_editor):
    DeliveryZone = apps.get_model('orders', 'DeliveryZone')
    DeliveryPriceTier = apps.get_model('orders', 'DeliveryPriceTier')
    DeliveryInfoSection = apps.get_model('orders', 'DeliveryInfoSection')

    ozersk = DeliveryZone.objects.create(
        code='ozersk',
        title='Озёрск',
        sort_order=10,
        pricing_mode='tiered',
        requires_address=True,
        default_locality='Озерск',
        lead_minutes=90,
        checkout_description=(
            'Озёрск: от 2000 ₽ бесплатно, от 1000 до 2000 ₽ — 250 ₽, '
            'до 1000 ₽ — 300 ₽'
        ),
    )
    DeliveryPriceTier.objects.bulk_create(
        [
            DeliveryPriceTier(
                zone=ozersk,
                min_cart_total=0,
                price=300,
                sort_order=10,
            ),
            DeliveryPriceTier(
                zone=ozersk,
                min_cart_total=1000,
                price=250,
                sort_order=20,
            ),
            DeliveryPriceTier(
                zone=ozersk,
                min_cart_total=2000,
                price=0,
                sort_order=30,
            ),
        ]
    )

    DeliveryZone.objects.create(
        code='promploshadka',
        title='Промплощадка',
        sort_order=20,
        pricing_mode='fixed',
        fixed_price=400,
        requires_address=True,
        default_locality='Промплощадка',
        lead_minutes=90,
        checkout_description='Промплощадка: доставка 400 ₽',
    )

    DeliveryZone.objects.create(
        code='tatysh',
        title='Татыш',
        sort_order=30,
        pricing_mode='fixed',
        fixed_price=550,
        requires_address=True,
        default_locality='Татыш',
        lead_minutes=120,
        checkout_description=(
            'Татыш: доставка 550 ₽, минимальное время — около 2 часов'
        ),
    )

    DeliveryZone.objects.create(
        code='pickup',
        title='Самовывоз',
        sort_order=40,
        pricing_mode='free',
        requires_address=False,
        lead_minutes=90,
        checkout_description='Самовывоз: скидка 5% на сумму заказа',
    )

    DeliveryInfoSection.objects.bulk_create(
        [
            DeliveryInfoSection(
                title='Доставка и оплата',
                content=(
                    'Оплата возможна через Мир, Visa, Mastercard и СБП.\n\n'
                    'Все платежи защищены SSL.\n'
                    'Данные карты не сохраняются.'
                ),
                section_type='info',
                sort_order=20,
            ),
            DeliveryInfoSection(
                title='Заказ по телефону',
                content=(
                    '+7 (900) 022-30-22\n\n'
                    'При заказе от 3000₽ — предоплата.\n'
                    'Можно оплатить в кафе.'
                ),
                section_type='info',
                sort_order=30,
            ),
            DeliveryInfoSection(
                title='Доставка по Озёрску',
                content=(
                    'от 2000₽ — бесплатно\n'
                    'от 1000 до 2000₽ — доставка 250₽\n'
                    '< 1000₽ — доставка 300₽'
                ),
                section_type='info',
                sort_order=40,
            ),
            DeliveryInfoSection(
                title='Доставка в Татыш',
                content=(
                    'Стоимость: 550₽\n'
                    'Минимум: 2 часа'
                ),
                section_type='info',
                sort_order=50,
            ),
            DeliveryInfoSection(
                title='',
                content=(
                    'Если нет лифта — подъём до 5 этажа бесплатный.\n'
                    'Далее — 50₽/этаж.'
                ),
                section_type='warning',
                sort_order=60,
            ),
        ]
    )


def unseed_delivery_config(apps, schema_editor):
    DeliveryZone = apps.get_model('orders', 'DeliveryZone')
    DeliveryInfoSection = apps.get_model('orders', 'DeliveryInfoSection')

    DeliveryZone.objects.filter(
        code__in=['ozersk', 'promploshadka', 'tatysh', 'pickup'],
    ).delete()
    DeliveryInfoSection.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0013_orderreturn_orderreturnitem'),
    ]

    operations = [
        migrations.AlterField(
            model_name='order',
            name='delivery_type',
            field=models.CharField(
                default='ozersk',
                max_length=50,
                verbose_name='Тип доставки',
            ),
        ),
        migrations.CreateModel(
            name='DeliveryZone',
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
                    models.CharField(max_length=120, verbose_name='Название'),
                ),
                (
                    'is_active',
                    models.BooleanField(default=True, verbose_name='Активна'),
                ),
                (
                    'sort_order',
                    models.PositiveIntegerField(
                        default=0,
                        verbose_name='Порядок',
                    ),
                ),
                (
                    'pricing_mode',
                    models.CharField(
                        choices=[
                            ('tiered', 'По сумме заказа'),
                            ('fixed', 'Фиксированная'),
                            ('free', 'Бесплатно'),
                        ],
                        default='fixed',
                        max_length=20,
                        verbose_name='Тип тарифа',
                    ),
                ),
                (
                    'fixed_price',
                    models.PositiveIntegerField(
                        default=0,
                        verbose_name='Фиксированная цена',
                    ),
                ),
                (
                    'requires_address',
                    models.BooleanField(
                        default=True,
                        verbose_name='Нужен адрес',
                    ),
                ),
                (
                    'default_locality',
                    models.CharField(
                        blank=True,
                        max_length=120,
                        verbose_name='Населённый пункт по умолчанию',
                    ),
                ),
                (
                    'lead_minutes',
                    models.PositiveIntegerField(
                        default=90,
                        verbose_name='Мин. время до доставки (мин)',
                    ),
                ),
                (
                    'checkout_description',
                    models.TextField(
                        blank=True,
                        verbose_name='Описание в оформлении заказа',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Зона доставки',
                'verbose_name_plural': 'Зоны доставки',
                'ordering': ['sort_order', 'id'],
            },
        ),
        migrations.CreateModel(
            name='DeliveryInfoSection',
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
                    'title',
                    models.CharField(
                        blank=True,
                        max_length=200,
                        verbose_name='Заголовок',
                    ),
                ),
                ('content', models.TextField(verbose_name='Текст')),
                (
                    'section_type',
                    models.CharField(
                        choices=[
                            ('info', 'Информация'),
                            ('warning', 'Важно'),
                        ],
                        default='info',
                        max_length=20,
                        verbose_name='Тип',
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
                    models.BooleanField(default=True, verbose_name='Активна'),
                ),
            ],
            options={
                'verbose_name': 'Блок «Доставка и оплата»',
                'verbose_name_plural': 'Блоки «Доставка и оплата»',
                'ordering': ['sort_order', 'id'],
            },
        ),
        migrations.CreateModel(
            name='DeliveryPriceTier',
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
                    'min_cart_total',
                    models.PositiveIntegerField(
                        verbose_name='Сумма заказа от (₽)',
                    ),
                ),
                (
                    'price',
                    models.PositiveIntegerField(
                        verbose_name='Цена доставки (₽)',
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
                    'zone',
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name='price_tiers',
                        to='orders.deliveryzone',
                        verbose_name='Зона',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Тариф доставки',
                'verbose_name_plural': 'Тарифы доставки',
                'ordering': ['sort_order', 'min_cart_total'],
            },
        ),
        migrations.RunPython(seed_delivery_config, unseed_delivery_config),
    ]
