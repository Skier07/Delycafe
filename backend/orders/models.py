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

    phone = models.CharField(max_length=30)
    customer_name = models.CharField(max_length=120, blank=True)

    delivery_type = models.CharField(
        max_length=30,
        choices=DeliveryType.choices,
        default=DeliveryType.OZERSK,
    )
    address = models.TextField(blank=True)

    delivery_time_type = models.CharField(
        max_length=30,
        choices=DeliveryTimeType.choices,
        default=DeliveryTimeType.ASAP,
    )
    delivery_time = models.CharField(max_length=20, blank=True)

    payment_type = models.CharField(
        max_length=20,
        choices=PaymentType.choices,
        default=PaymentType.CARD,
    )

    comment = models.TextField(blank=True)

    products_total = models.PositiveIntegerField(default=0)
    delivery_price = models.PositiveIntegerField(default=0)

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

    first_order_discount_applied = models.BooleanField(
        default=False,
        verbose_name='Применена скидка первого заказа',
    )

    total_price = models.PositiveIntegerField(default=0)

    status = models.CharField(
        max_length=30,
        choices=Status.choices,
        default=Status.NEW,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

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
    )

    product_title = models.CharField(max_length=180)
    variant_title = models.CharField(max_length=80, blank=True)

    product_api_id = models.CharField(max_length=80, blank=True)
    saby_id = models.PositiveIntegerField(null=True, blank=True)

    quantity = models.PositiveIntegerField(default=1)
    price = models.PositiveIntegerField(default=0)
    total_price = models.PositiveIntegerField(default=0)

    class Meta:
        verbose_name = 'Позиция заказа'
        verbose_name_plural = 'Позиции заказа'

    def __str__(self):
        return f'{self.product_title} × {self.quantity}'