from django.db import models


class Category(models.Model):
    title = models.CharField(max_length=120)
    slug = models.SlugField(max_length=140, unique=True)

    saby_category_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        unique=True,
    )


    sort_order = models.PositiveIntegerField(default=500)
    is_active = models.BooleanField(default=True)

    show_in_app = models.BooleanField(
        default=False,
        verbose_name='Показывать в приложении',
    )

    preorder_lead_days = models.PositiveIntegerField(
        default=0,
        verbose_name='Заказывать минимум за (суток)',
        help_text='0 — без ограничения. 1 — заказ минимум на завтра.',
    )
    preorder_cutoff_enabled = models.BooleanField(
        default=False,
        verbose_name='Ограничение по времени заказа',
        help_text=(
            'Если включено и указано время «Принимать заказы до», '
            'после этого времени (по Уралу) товары категории нельзя заказать.'
        ),
    )
    preorder_cutoff_time = models.TimeField(
        blank=True,
        null=True,
        verbose_name='Принимать заказы до',
        help_text='После этого времени сегодня товары категории нельзя заказать. Например 17:00 для пирогов.',
    )

    class Meta:
        ordering = ['sort_order', 'title']
        verbose_name = 'Категория'
        verbose_name_plural = 'Категории'

    def __str__(self):
        return self.title


class Product(models.Model):
    class Source(models.TextChoices):
        MANUAL = 'manual', 'Создан вручную'
        SABY = 'saby', 'Saby'

    manual_category = models.BooleanField(
        default=False,
        verbose_name='Категория назначена вручную',
    )

    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name='products',
    )

    saby_id = models.PositiveIntegerField(
        null=True,
        blank=True,
        unique=True,
        help_text='ID товара из Saby. Без него товар нельзя отправить в заказ.',
    )

    saby_name = models.CharField(
        max_length=180,
        blank=True,
        help_text='Оригинальное название товара из Saby.',
    )

    source = models.CharField(
        max_length=20,
        choices=Source.choices,
        default=Source.MANUAL,
    )

    needs_review = models.BooleanField(
        default=False,
        help_text='Товар требует оформления перед публикацией.',
    )

    title = models.CharField(max_length=180)
    description = models.TextField(blank=True)

    image = models.ImageField(
        upload_to='products/',
        blank=True,
        null=True,
    )

    price = models.PositiveIntegerField(default=0)
    weight = models.CharField(max_length=60, blank=True)

    is_new = models.BooleanField(default=False)
    is_hit = models.BooleanField(default=False)
    sort_order = models.PositiveIntegerField(default=500)
    is_active = models.BooleanField(default=True)

    show_in_app = models.BooleanField(
        default=False,
        verbose_name='Показывать в приложении',
    )

    has_variants = models.BooleanField(default=False)
    sort_order = models.PositiveIntegerField(default=500)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category__sort_order', 'sort_order', 'title']
        verbose_name = 'Товар'
        verbose_name_plural = 'Товары'

    def __str__(self):
        return self.title


class NewSabyProduct(Product):
    class Meta:
        proxy = True
        verbose_name = 'Новый товар из Saby'
        verbose_name_plural = 'Новые товары из Saby'


class ProductVariant(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='variants',
    )

    saby_id = models.PositiveIntegerField(
        null=True,
        blank=True,
        unique=True,
        help_text='ID варианта из Saby, например маленькая/средняя/большая пицца.',
    )

    saby_name = models.CharField(
        max_length=180,
        blank=True,
        help_text='Оригинальное название варианта из Saby.',
    )

    title = models.CharField(max_length=80)
    price = models.PositiveIntegerField(default=0)
    weight = models.CharField(max_length=60, blank=True)
    sort_order = models.PositiveIntegerField(default=500)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['sort_order', 'title']
        verbose_name = 'Вариант товара'
        verbose_name_plural = 'Варианты товара'

    def __str__(self):
        return f'{self.product.title} — {self.title}'


class InfoSection(models.TextChoices):
    WHY_TRY = 'why_try', 'Почему стоит попробовать'
    IMPORTANT = 'important', 'Что важно знать'


class InfoStyle(models.TextChoices):
    NORMAL = 'normal', 'Обычный'
    WARNING = 'warning', 'Предупреждение'


class CatalogSnippet(models.Model):
    name = models.CharField(
        max_length=120,
        verbose_name='Название в админке',
    )
    section = models.CharField(
        max_length=20,
        choices=InfoSection.choices,
        default=InfoSection.IMPORTANT,
        verbose_name='Блок в карточке',
    )
    text = models.TextField(verbose_name='Текст')
    style = models.CharField(
        max_length=20,
        choices=InfoStyle.choices,
        default=InfoStyle.NORMAL,
        verbose_name='Оформление',
    )
    is_default = models.BooleanField(
        default=False,
        verbose_name='Подключать ко всем новым товарам',
    )
    default_for_category = models.ForeignKey(
        Category,
        on_delete=models.SET_NULL,
        related_name='default_snippets',
        blank=True,
        null=True,
        verbose_name='Подключать к новым товарам категории',
    )
    sort_order = models.PositiveIntegerField(default=100)

    class Meta:
        ordering = ['section', 'sort_order', 'id']
        verbose_name = 'Текстовый блок'
        verbose_name_plural = 'Текстовые блоки'

    def __str__(self):
        return self.name


class ProductSnippet(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='product_snippets',
    )
    snippet = models.ForeignKey(
        CatalogSnippet,
        on_delete=models.CASCADE,
        related_name='product_links',
    )
    is_enabled = models.BooleanField(
        default=True,
        verbose_name='Показывать',
    )
    override_text = models.TextField(
        blank=True,
        verbose_name='Свой текст для этого товара',
        help_text='Пусто — берётся общий текст блока.',
    )

    class Meta:
        unique_together = ('product', 'snippet')
        verbose_name = 'Блок товара'
        verbose_name_plural = 'Блоки товара'

    def __str__(self):
        return f'{self.product} — {self.snippet}'

    def resolved_text(self):
        return (self.override_text or self.snippet.text).strip()


class ProductInfoNote(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='info_notes',
    )
    section = models.CharField(
        max_length=20,
        choices=InfoSection.choices,
        default=InfoSection.IMPORTANT,
        verbose_name='Блок в карточке',
    )
    text = models.TextField(verbose_name='Текст')
    style = models.CharField(
        max_length=20,
        choices=InfoStyle.choices,
        default=InfoStyle.WARNING,
        verbose_name='Оформление',
    )
    sort_order = models.PositiveIntegerField(default=500)

    class Meta:
        ordering = ['sort_order', 'id']
        verbose_name = 'Свой текст товара'
        verbose_name_plural = 'Свои тексты товара'

    def __str__(self):
        return f'{self.product} — {self.get_section_display()}'
