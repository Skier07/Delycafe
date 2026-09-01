from django.db import models

from customers.models import Customer


class Order(models.Model):
    class DeliveryType(models.TextChoices):
        OZERSK = 'ozersk', 'Озёрск'
        PROMPLOSHADKA = 'promploshadka', 'Промплощадка'
        TATYSH = 'tatysh', 'Татыш'
        PICKUP = 'pickup', 'Самовывоз'

    class DeliveryTimeType(models.TextChoices):
        ASAP = 'asap', 'Как можно скорее'
        BY_TIME = 'by_time', 'Ко времени'

    class PaymentType(models.TextChoices):
        CARD = 'card', 'Картой'
        SBP = 'sbp', 'СБП'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'unpaid', 'Ожидает оплаты'
        PAID = 'paid', 'Оплачен'
        FAILED = 'failed', 'Ошибка оплаты'
        REFUNDED = 'refunded', 'Возврат'

    class Status(models.TextChoices):
        NEW = 'new', 'Новый'
        ACCEPTED = 'accepted', 'Принят'
        COOKING = 'cooking', 'Готовится'
        DELIVERY = 'delivery', 'В доставке'
        DONE = 'done', 'Завершён'
        CANCELED = 'canceled', 'Отменён'

    customer = models.ForeignKey(
        Customer,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders',
        verbose_name='Клиент',
    )

    phone = models.CharField(
        max_length=30,
        verbose_name='Телефон',
    )

    customer_name = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Имя клиента',
    )

    delivery_type = models.CharField(
        max_length=50,
        default=DeliveryType.OZERSK,
        verbose_name='Тип доставки',
    )

    address = models.TextField(
        blank=True,
        verbose_name='Адрес',
    )
    address_locality = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Населный пункт',
    )
    address_entrance = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Подъезд',
    )
    address_floor = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Этаж',
    )
    address_apartment = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Квартира',
    )

    delivery_time_type = models.CharField(
        max_length=30,
        choices=DeliveryTimeType.choices,
        default=DeliveryTimeType.ASAP,
        verbose_name='Тип времени доставки',
    )

    delivery_time = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Время доставки',
    )

    payment_type = models.CharField(
        max_length=20,
        choices=PaymentType.choices,
        default=PaymentType.CARD,
        verbose_name='Способ оплаты',
    )

    payment_status = models.CharField(
        max_length=30,
        choices=PaymentStatus.choices,
        default=PaymentStatus.UNPAID,
        verbose_name='Статус оплаты',
    )

    payment_amount = models.PositiveIntegerField(
        default=0,
        verbose_name='Сумма к оплате',
    )

    payment_provider = models.CharField(
        max_length=60,
        blank=True,
        verbose_name='Платёжный провайдер',
    )

    payment_external_id = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='ID платежа у провайдера',
    )

    payment_url = models.URLField(
        blank=True,
        max_length=512,
        verbose_name='Ссылка на оплату',
    )

    saby_order_number = models.CharField(
        max_length=50,
        blank=True,
        verbose_name='Номер заказа Saby',
    )

    saby_sale_id = models.CharField(
        max_length=100,
        blank=True,
        verbose_name='Sale ID Saby',
    )

    saby_external_id = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='External ID Saby',
    )

    saby_dispatch_error = models.TextField(
        blank=True,
        verbose_name='Ошибка отправки в Saby',
    )

    saby_payment_registered = models.BooleanField(
        default=False,
        verbose_name='Оплата зарегистрирована в Saby',
    )

    saby_bonus_applied = models.BooleanField(
        default=False,
        verbose_name='Бонусы применены в Saby',
    )

    saby_payment_error = models.TextField(
        blank=True,
        verbose_name='Ошибка регистрации оплаты в Saby',
    )

    admin_email_sent_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Письмо администратору отправлено',
    )

    paid_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Дата оплаты',
    )

    comment = models.TextField(
        blank=True,
        verbose_name='Комментарий',
    )

    products_total = models.PositiveIntegerField(
        default=0,
        verbose_name='Сумма товаров',
    )

    delivery_price = models.PositiveIntegerField(
        default=0,
        verbose_name='Стоимость доставки',
    )

    discount_amount = models.PositiveIntegerField(
        default=0,
        verbose_name='Скидка',
    )

    bonus_spent = models.PositiveIntegerField(
        default=0,
        verbose_name='Списано бонусов',
    )

    bonus_earned = models.PositiveIntegerField(
        default=0,
        verbose_name='Начислено бонусов',
    )

    bonus_compensated = models.BooleanField(
    	default=False,
    	verbose_name='Бонусы компенсированы',
    )

    first_order_discount_applied = models.BooleanField(
        default=False,
        verbose_name='Применена скидка первого заказа',
    )

    total_price = models.PositiveIntegerField(
        default=0,
        verbose_name='Итого',
    )

    status = models.CharField(
        max_length=30,
        choices=Status.choices,
        default=Status.NEW,
        verbose_name='Статус заказа',
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания',
    )

    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Дата обновления',
    )

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Заказ'
        verbose_name_plural = 'Заказы'

    def __str__(self):
        return f'Заказ #{self.id} — {self.phone}'


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items',
        verbose_name='Заказ',
    )

    product_title = models.CharField(
        max_length=180,
        verbose_name='Товар',
    )

    variant_title = models.CharField(
        max_length=80,
        blank=True,
        verbose_name='Вариант',
    )

    product_api_id = models.CharField(
        max_length=80,
        blank=True,
        verbose_name='ID товара в API',
    )

    saby_id = models.PositiveIntegerField(
        null=True,
        blank=True,
        verbose_name='Saby ID',
    )

    quantity = models.PositiveIntegerField(
        default=1,
        verbose_name='Количество',
    )

    price = models.PositiveIntegerField(
        default=0,
        verbose_name='Цена',
    )

    total_price = models.PositiveIntegerField(
        default=0,
        verbose_name='Сумма',
    )

    class Meta:
        verbose_name = 'Позиция заказа'
        verbose_name_plural = 'Позиции заказа'

    def __str__(self):
        return f'{self.product_title} × {self.quantity}'


class OrderReturn(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='returns',
        verbose_name='Заказ',
    )
    comment = models.TextField(
        blank=True,
        verbose_name='Комментарий',
    )
    products_total = models.PositiveIntegerField(
        default=0,
        verbose_name='Сумма возвращённых товаров',
    )
    bonus_earned_reversed = models.PositiveIntegerField(
        default=0,
        verbose_name='Снято начисленных бонусов',
    )
    bonus_spent_restored = models.PositiveIntegerField(
        default=0,
        verbose_name='Возвращено списанных бонусов',
    )
    bonuses_applied = models.BooleanField(
        default=False,
        verbose_name='Бонусы по возврату применены',
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания',
    )

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Возврат по заказу'
        verbose_name_plural = 'Возвраты по заказам'

    def __str__(self):
        return f'Возврат #{self.id} по заказу #{self.order_id}'


class OrderReturnItem(models.Model):
    order_return = models.ForeignKey(
        OrderReturn,
        on_delete=models.CASCADE,
        related_name='items',
        verbose_name='Возврат',
    )
    order_item = models.ForeignKey(
        OrderItem,
        on_delete=models.PROTECT,
        related_name='return_items',
        verbose_name='Позиция заказа',
    )
    quantity = models.PositiveIntegerField(
        default=1,
        verbose_name='Количество',
    )
    product_title = models.CharField(
        max_length=180,
        verbose_name='Товар',
    )
    price = models.PositiveIntegerField(
        default=0,
        verbose_name='Цена',
    )
    total_price = models.PositiveIntegerField(
        default=0,
        verbose_name='Сумма',
    )

    class Meta:
        verbose_name = 'Позиция возврата'
        verbose_name_plural = 'Позиции возврата'

    def __str__(self):
        return f'{self.product_title} × {self.quantity}'


class DeliveryZone(models.Model):
    class PricingMode(models.TextChoices):
        TIERED = 'tiered', 'По сумме заказа'
        FIXED = 'fixed', 'Фиксированная'
        FREE = 'free', 'Бесплатно'

    code = models.SlugField(
        max_length=50,
        unique=True,
        verbose_name='Код (для API)',
    )
    title = models.CharField(
        max_length=120,
        verbose_name='Название',
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активна',
    )
    sort_order = models.PositiveIntegerField(
        default=0,
        verbose_name='Порядок',
    )
    pricing_mode = models.CharField(
        max_length=20,
        choices=PricingMode.choices,
        default=PricingMode.FIXED,
        verbose_name='Тип тарифа',
    )
    fixed_price = models.PositiveIntegerField(
        default=0,
        verbose_name='Фиксированная цена',
    )
    requires_address = models.BooleanField(
        default=True,
        verbose_name='Нужен адрес',
    )
    default_locality = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Населённый пункт по умолчанию',
    )
    lead_minutes = models.PositiveIntegerField(
        default=90,
        verbose_name='Мин. время до доставки (мин)',
    )
    checkout_description = models.TextField(
        blank=True,
        verbose_name='Описание в оформлении заказа',
    )

    class Meta:
        ordering = ['sort_order', 'id']
        verbose_name = 'Зона доставки'
        verbose_name_plural = 'Зоны доставки'

    def __str__(self):
        return self.title


class DeliveryPriceTier(models.Model):
    zone = models.ForeignKey(
        DeliveryZone,
        on_delete=models.CASCADE,
        related_name='price_tiers',
        verbose_name='Зона',
    )
    min_cart_total = models.PositiveIntegerField(
        verbose_name='Сумма заказа от (₽)',
    )
    price = models.PositiveIntegerField(
        verbose_name='Цена доставки (₽)',
    )
    sort_order = models.PositiveIntegerField(
        default=0,
        verbose_name='Порядок',
    )

    class Meta:
        ordering = ['sort_order', 'min_cart_total']
        verbose_name = 'Тариф доставки'
        verbose_name_plural = 'Тарифы доставки'

    def __str__(self):
        return f'{self.zone.title}: от {self.min_cart_total} ₽ — {self.price} ₽'


class DeliveryInfoSection(models.Model):
    class SectionType(models.TextChoices):
        INFO = 'info', 'Информация'
        WARNING = 'warning', 'Важно'

    title = models.CharField(
        max_length=200,
        blank=True,
        verbose_name='Заголовок',
    )
    content = models.TextField(
        verbose_name='Текст',
    )
    section_type = models.CharField(
        max_length=20,
        choices=SectionType.choices,
        default=SectionType.INFO,
        verbose_name='Тип',
    )
    sort_order = models.PositiveIntegerField(
        default=0,
        verbose_name='Порядок',
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активна',
    )

    class Meta:
        ordering = ['sort_order', 'id']
        verbose_name = 'Блок «Доставка и оплата»'
        verbose_name_plural = 'Блоки «Доставка и оплата»'

    def __str__(self):
        return self.title or f'Блок #{self.id}'
