import uuid

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('customers', '0008_alter_customer_bonus_balance_help_text'),
    ]

    operations = [
        migrations.CreateModel(
            name='CustomerRefreshToken',
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
                    'family_id',
                    models.UUIDField(
                        db_index=True,
                        default=uuid.uuid4,
                        editable=False,
                        verbose_name='Семейство токенов',
                    ),
                ),
                (
                    'token_hash',
                    models.CharField(
                        editable=False,
                        max_length=64,
                        unique=True,
                        verbose_name='Хэш refresh token',
                    ),
                ),
                (
                    'expires_at',
                    models.DateTimeField(
                        db_index=True,
                        verbose_name='Истекает',
                    ),
                ),
                (
                    'last_used_at',
                    models.DateTimeField(
                        blank=True,
                        null=True,
                        verbose_name='Последнее использование',
                    ),
                ),
                (
                    'revoked_at',
                    models.DateTimeField(
                        blank=True,
                        null=True,
                        verbose_name='Отозван',
                    ),
                ),
                (
                    'created_at',
                    models.DateTimeField(
                        auto_now_add=True,
                        verbose_name='Создан',
                    ),
                ),
                (
                    'customer',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='refresh_tokens',
                        to='customers.customer',
                        verbose_name='Клиент',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Refresh-сессия клиента',
                'verbose_name_plural': 'Refresh-сессии клиентов',
                'ordering': ['-created_at'],
            },
        ),
    ]
