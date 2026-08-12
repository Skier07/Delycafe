import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0012_order_saby_bonus_applied'),
    ]

    operations = [
        migrations.CreateModel(
            name='OrderReturn',
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
                    'comment',
                    models.TextField(blank=True, verbose_name='Комментарий'),
                ),
                (
                    'products_total',
                    models.PositiveIntegerField(
                        default=0,
                        verbose_name='Сумма возвращённых товаров',
                    ),
                ),
                (
                    'bonus_earned_reversed',
                    models.PositiveIntegerField(
                        default=0,
                        verbose_name='Снято начисленных бонусов',
                    ),
                ),
                (
                    'bonus_spent_restored',
                    models.PositiveIntegerField(
                        default=0,
                        verbose_name='Возвращено списанных бонусов',
                    ),
                ),
                (
                    'bonuses_applied',
                    models.BooleanField(
                        default=False,
                        verbose_name='Бонусы по возврату применены',
                    ),
                ),
                (
                    'created_at',
                    models.DateTimeField(
                        auto_now_add=True,
                        verbose_name='Дата создания',
                    ),
                ),
                (
                    'order',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='returns',
                        to='orders.order',
                        verbose_name='Заказ',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Возврат по заказу',
                'verbose_name_plural': 'Возвраты по заказам',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='OrderReturnItem',
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
                    'quantity',
                    models.PositiveIntegerField(
                        default=1,
                        verbose_name='Количество',
                    ),
                ),
                (
                    'product_title',
                    models.CharField(max_length=180, verbose_name='Товар'),
                ),
                (
                    'price',
                    models.PositiveIntegerField(default=0, verbose_name='Цена'),
                ),
                (
                    'total_price',
                    models.PositiveIntegerField(default=0, verbose_name='Сумма'),
                ),
                (
                    'order_item',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name='return_items',
                        to='orders.orderitem',
                        verbose_name='Позиция заказа',
                    ),
                ),
                (
                    'order_return',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='items',
                        to='orders.orderreturn',
                        verbose_name='Возврат',
                    ),
                ),
            ],
            options={
                'verbose_name': 'Позиция возврата',
                'verbose_name_plural': 'Позиции возврата',
            },
        ),
    ]
