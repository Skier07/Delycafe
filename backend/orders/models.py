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
        max_length=30,
        choices=DeliveryType.choices,
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
