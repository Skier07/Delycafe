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
        verbose_name='Адрес доставки',
    )

    bonus_balance = models.PositiveIntegerField(
        default=0,
        verbose_name='Баланс бонусов',
    )

    first_order_discount_available = models.BooleanField(
        default=True,
        verbose_name='Скидка 20% доступна',
        help_text='Доступна скидка 20% на первый заказ в приложении.',
    )

    first_order_discount_used = models.BooleanField(
        default=False,
        verbose_name='Скидка 20% использована',
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
        if self.name:
            return f'{self.name} — {self.phone}'

        return self.phone


class BonusTransaction(models.Model):
    class TransactionType(models.TextChoices):
        EARN = 'earn', 'Начисление'
        SPEND = 'spend', 'Списание'
        REFUND = 'refund', 'Возврат'
        MANUAL = 'manual', 'Ручная корректировка'

    customer = models.ForeignKey(
        Customer,
        on_delete=models.CASCADE,
        related_name='bonus_transactions',
        verbose_name='Клиент',
    )

    transaction_type = models.CharField(
        max_length=20,
        choices=TransactionType.choices,
        verbose_name='Тип операции',
    )

    amount = models.IntegerField(
        verbose_name='Количество бонусов',
        help_text='Положительное число — начисление, отрицательное — списание.',
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
        verbose_name='Дата операции',
    )

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Бонусная операция'
        verbose_name_plural = 'Бонусные операции'

    def __str__(self):
        return f'{self.customer.phone} — {self.amount} бонусов'