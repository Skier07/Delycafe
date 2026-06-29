from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('customers', '0004_customer_saby_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='PhoneAuthSession',
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
                    'phone',
                    models.CharField(
                        db_index=True,
                        max_length=30,
                        verbose_name='Телефон',
                    ),
                ),
                (
                    'mode',
                    models.CharField(
                        choices=[
                            ('sms', 'SMS OTP'),
                            ('mobile_id', 'Mobile ID'),
                        ],
                        max_length=20,
                        verbose_name='Режим',
                    ),
                ),
                (
                    'status',
                    models.CharField(
                        choices=[
                            ('pending', 'Ожидание'),
                            ('awaiting_otp', 'Нужен код'),
                            ('verified', 'Подтверждено'),
                            ('failed', 'Ошибка'),
                        ],
                        default='pending',
                        max_length=20,
                        verbose_name='Статус',
                    ),
                ),
                (
                    'smsaero_id',
                    models.PositiveIntegerField(
                        blank=True,
                        null=True,
                        verbose_name='ID в SMS Aero',
                    ),
                ),
                (
                    'code_hash',
                    models.CharField(
                        blank=True,
                        max_length=64,
                        verbose_name='Хэш кода',
                    ),
                ),
                (
                    'verify_attempts',
                    models.PositiveSmallIntegerField(
                        default=0,
                        verbose_name='Попытки ввода',
                    ),
                ),
                (
                    'expires_at',
                    models.DateTimeField(verbose_name='Истекает'),
                ),
                (
                    'verified_at',
                    models.DateTimeField(
                        blank=True,
                        null=True,
                        verbose_name='Подтверждено',
                    ),
                ),
                (
                    'created_at',
                    models.DateTimeField(
                        auto_now_add=True,
                        verbose_name='Создано',
                    ),
                ),
                (
                    'updated_at',
                    models.DateTimeField(
                        auto_now=True,
                        verbose_name='Обновлено',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Сессия SMS-авторизации',
                'verbose_name_plural': 'Сессии SMS-авторизации',
                'ordering': ['-created_at'],
            },
        ),
    ]
