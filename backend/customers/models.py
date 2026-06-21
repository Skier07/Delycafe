from django.db import models


class Customer(models.Model):
    phone = models.CharField(
        max_length=30,
        unique=True,
        verbose_name='Телефон',
    )
    name = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Имя',
    )
    default_address = models.TextField(
        blank=True,
        verbose_name='Адрес по умолчанию',
    )
    bonus_balance = models.PositiveIntegerField(
        default=0,
        verbose_name='Бонусный баланс',
    )
    first_order_discount_available = models.BooleanField(
        default=True,
        verbose_name='Скидка первого заказа доступна',
    )
    first_order_discount_used = models.BooleanField(
        default=False,
        verbose_name='Скидка первого заказа использована',
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен',
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
        verbose_name = 'Клиент'
        verbose_name_plural = 'Клиенты'

    def __str__(self):
        return self.name or self.phone


class CustomerAddress(models.Model):
    customer = models.ForeignKey(
        Customer,
        on_delete=models.CASCADE,
        related_name='addresses',
        verbose_name='Клиент',
    )
    title = models.CharField(
        max_length=80,
        default='Адрес',
        verbose_name='Название адреса',
    )
    address = models.TextField(
        verbose_name='Адрес',
    )
    entrance = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Подъезд',
    )
    floor = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Этаж',
    )
    apartment = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Квартира / офис',
    )
    comment = models.TextField(
        blank=True,
        verbose_name='Комментарий к адресу',
    )
    is_default = models.BooleanField(
        default=False,
        verbose_name='Адрес по умолчанию',
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
        ordering = ['-is_default', '-updated_at']
        verbose_name = 'Адрес клиента'
        verbose_name_plural = 'Адреса клиентов'

    @property
    def full_address(self):
        parts = [self.address]

        if self.entrance:
            parts.append(f'подъезд {self.entrance}')

        if self.floor:
            parts.append(f'этаж {self.floor}')

        if self.apartment:
            parts.append(f'кв./офис {self.apartment}')

        return ', '.join(parts)

    def __str__(self):
        return f'{self.customer.phone} — {self.title}: {self.full_address}'


class BonusTransaction(models.Model):
    class TransactionType(models.TextChoices):
        EARN = 'earn', 'Начисление'
        SPEND = 'spend', 'Списание'
        REFUND = 'refund', 'Возврат'
        MANUAL = 'manual', 'Ручная операция'

    customer = models.ForeignKey(
        Customer,
        on_delete=models.CASCADE,
        related_name='bonus_transactions',
        verbose_name='Клиент',
    )
    transaction_type = models.CharField(
        max_length=30,
        choices=TransactionType.choices,
        verbose_name='Тип операции',
    )
    amount = models.IntegerField(
        verbose_name='Количество бонусов',
    )
    comment = models.TextField(
        blank=True,
        verbose_name='Комментарий',
    )
    order_id = models.PositiveIntegerField(
        null=True,
        blank=True,
        verbose_name='ID заказа',
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания',
    )

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Бонусная операция'
        verbose_name_plural = 'Бонусные операции'

    def __str__(self):
        return f'{self.customer.phone} — {self.get_transaction_type_display()} — {self.amount}'
