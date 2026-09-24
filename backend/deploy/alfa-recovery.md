# Восстановление пропущенных подтверждений Альфа-Банка

Банк подтвердил для delycafe-149 статус 2, зачисление 3800 копеек RUB (810),
возврат 0. В backend заказ остался unpaid. Это не подтверждает причину
недоставки/необработки callback: рабочие журналы и настройки callback ещё нужны.

## Обновление

Перенести из этой версии проекта файлы с сохранением каталогов:

- `payments/services.py`
- `payments/reconciliation.py` (новый)
- `orders/management/commands/sync_alfa_payments.py` (новый)
- `orders/management/commands/expire_stale_unpaid_orders.py`
- `orders/order_notification_service.py`
- `config/settings.py`

Сохранить серверный `.env`. Если настройки на сервере редактируются прямо
в settings.py, перенести только добавление EMAIL_TIMEOUT, не заменять настройки
сервера целиком. Исправление delivery.isPickup/paymentType в orders/services.py
из предыдущей версии также должно быть установлено. Миграций нет.

Перезапустить рабочий сервис backend (в примерах проекта — delycafe_backend).

## Заказ 149

Из backend с активированным серверным venv:

```bash
python manage.py sync_alfa_payments --order-id=149
python manage.py sync_alfa_payments --order-id=149 --apply
```

Первая команда только проверяет банк. `bank_paid` означает совпадение номера,
суммы, валюты и отсутствие возврата. Вторая повторно проверяет банк и запускает
обычный обработчик подтверждения: письмо, создание заказа Saby, регистрацию
оплаты. Она не создаёт банковский платёж и не списывает деньги повторно.

`processed` означает завершение вызова обработчика: отдельно проверить поля
email_sent, saby_number, saby_payment_registered и выведенные ошибки.
Флаг saby_payment_registered означает принятие задания Saby, а не доказательство
выхода бумаги. Завершение проверяется GET /retail/order/{saleKey}/state.
`skipped` означает, что заказ уже не unpaid либо отменён; не сбрасывать статусы
для принудительного повтора. Оплаченные заказы команда повторно не обрабатывает.

## Резервная сверка

В deploy/cron.example добавлена строка sync_alfa_payments --apply раз в минуту.
Внести именно эту строку в crontab пользователя backend, проверив пути и наличие
/usr/bin/flock. Копирование файла cron.example само по себе расписание не включает.
Журнал и lock-файл расположены в /var/www/delycafe_backend/; пользователь backend
должен иметь право создавать там файлы. flock исключает пересечение запусков cron.

Автоматически выбираются до 100 последних unpaid-заказов за 7 дней с банковским
ID. Отменённые/paid/failed-заказы не обрабатываются. Не включать массовые повторы
создания/оплаты в Saby для старых заказов без сверки уже созданных чеков.

Сверка дополняет callback. Нужно отдельно проверить, что рабочий процесс использует
нужную БД, а банковские уведомления поступают на /api/payments/alfa/callback/.

## Проверки

```bash
python manage.py test orders.test_alfa_reconciliation orders.test_order_notification orders.test_saby_order_creation orders.test_pickup_discount --settings=config.test_settings
```

Нужны актуальные test_*.py и зависимости backend. Локально 21 целевой тест прошёл
с изолированным URLConf (в окружении проверки нет PyJWT); реальные банковские,
SMTP и кассовые запросы в тестах заменены заглушками.
