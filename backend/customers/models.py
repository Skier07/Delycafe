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
    saby_external_id = models.CharField(
        max_length=64,
        blank=True,
        null=True,
        unique=True,
        verbose_name='UUID клиента в Saby',
    )
    saby_customer_id = models.PositiveIntegerField(
        blank=True,
        null=True,
        verbose_name='ID клиента в Saby',
    )
    saby_synced_at = models.DateTimeField(
        blank=True,
        null=True,
        verbose_name='Дата синхронизации с Saby',
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


class PhoneAuthSession(models.Model):
    class Mode(models.TextChoices):
        SMS = 'sms', 'SMS OTP'
        MOBILE_ID = 'mobile_id', 'Mobile ID'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Ожидание'
        AWAITING_OTP = 'awaiting_otp', 'Нужен код'
        VERIFIED = 'verified', 'Подтверждено'
        FAILED = 'failed', 'Ошибка'

    phone = models.CharField(
        max_length=30,
        db_index=True,
        verbose_name='Телефон',
    )
    mode = models.CharField(
        max_length=20,
        choices=Mode.choices,
        verbose_name='Режим',
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        verbose_name='Статус',
    )
    smsaero_id = models.PositiveIntegerField(
        null=True,
        blank=True,
        verbose_name='ID в SMS Aero',
    )
    code_hash = models.CharField(
        max_length=64,
        blank=True,
        verbose_name='Хэш кода',
    )
    verify_attempts = models.PositiveSmallIntegerField(
        default=0,
        verbose_name='Попытки ввода',
    )
    expires_at = models.DateTimeField(
        verbose_name='Истекает',
    )
    verified_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Подтверждено',
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Создано',
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Обновлено',
    )

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Сессия SMS-авторизации'
        verbose_name_plural = 'Сессии SMS-авторизации'

    def __str__(self):
        return f'{self.phone} — {self.mode} — {self.status}'

    @property
    def is_expired(self) -> bool:
        from django.utils import timezone

        return timezone.now() >= self.expires_at

    def mark_verified(self) -> None:
        from django.utils import timezone

        self.status = self.Status.VERIFIED
        self.verified_at = timezone.now()
        self.save(update_fields=['status', 'verified_at', 'updated_at'])

    def mark_failed(self) -> None:
        self.status = self.Status.FAILED
        self.save(update_fields=['status', 'updated_at'])
