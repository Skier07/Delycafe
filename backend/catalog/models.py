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


class ProductGalleryImage(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='gallery_images',
        verbose_name='Товар',
    )
    image = models.ImageField(
        upload_to='products/gallery/',
        verbose_name='Фото',
    )
    sort_order = models.PositiveIntegerField(
        default=500,
        verbose_name='Порядок',
    )

    class Meta:
        ordering = ['sort_order', 'id']
        verbose_name = 'Фото товара'
        verbose_name_plural = 'Фото товара'

    def __str__(self):
        return f'Фото #{self.id} — {self.product.title}'


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


class InfoSectionDefinition(models.Model):
    code = models.SlugField(
        max_length=50,
        unique=True,
        verbose_name='Код (для API)',
    )
    title = models.CharField(
        max_length=120,
        verbose_name='Заголовок в приложении',
    )
    sort_order = models.PositiveIntegerField(
        default=0,
        verbose_name='Порядок',
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен',
    )

    class Meta:
        ordering = ['sort_order', 'id']
        verbose_name = 'Тип блока информации'
        verbose_name_plural = 'Типы блоков информации'

    def __str__(self):
        return self.title


class InfoStyle(models.TextChoices):
    NORMAL = 'normal', 'Обычный'
    WARNING = 'warning', 'Предупреждение'


class CatalogSnippet(models.Model):
    name = models.CharField(
        max_length=120,
        verbose_name='Название в админке',
    )
    info_section = models.ForeignKey(
        InfoSectionDefinition,
        on_delete=models.PROTECT,
        related_name='snippets',
        verbose_name='Блок в карточке',
    )
    content = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='Содержимое',
    )
    text = models.TextField(
        verbose_name='Текст (поиск)',
        help_text='Заполняется автоматически из редактора.',
        blank=True,
    )
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
        ordering = ['info_section__sort_order', 'sort_order', 'id']
        verbose_name = 'Текстовый блок'
        verbose_name_plural = 'Текстовые блоки'

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        from catalog.info_content import content_to_plain_text

        self.text = content_to_plain_text(self.content)
        super().save(*args, **kwargs)


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
        verbose_name='Свой текст (устар.)',
        help_text='Используйте редактор ниже. Это поле только для совместимости.',
    )
    override_content = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='Свой текст для этого товара',
    )

    class Meta:
        unique_together = ('product', 'snippet')
        verbose_name = 'Блок товара'
        verbose_name_plural = 'Блоки товара'

    def __str__(self):
        return f'{self.product} — {self.snippet}'

    def resolved_text(self):
        from catalog.info_content import content_to_plain_text, resolved_lines

        override_lines = resolved_lines(
            self.override_content,
            self.override_text,
        )

        if override_lines:
            return content_to_plain_text({'lines': override_lines})

        return content_to_plain_text(self.snippet.content, self.snippet.text)

    def resolved_lines(self):
        from catalog.info_content import resolved_lines

        override_lines = resolved_lines(
            self.override_content,
            self.override_text,
        )

        if override_lines:
            return override_lines

        return resolved_lines(self.snippet.content, self.snippet.text)


class ProductInfoNote(models.Model):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='info_notes',
    )
    info_section = models.ForeignKey(
        InfoSectionDefinition,
        on_delete=models.PROTECT,
        related_name='product_notes',
        verbose_name='Блок в карточке',
    )
    content = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='Содержимое',
    )
    text = models.TextField(
        verbose_name='Текст (поиск)',
        help_text='Заполняется автоматически из редактора.',
        blank=True,
    )
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
        return f'{self.product} — {self.info_section.title}'

    def save(self, *args, **kwargs):
        from catalog.info_content import content_to_plain_text

        self.text = content_to_plain_text(self.content)
        super().save(*args, **kwargs)
