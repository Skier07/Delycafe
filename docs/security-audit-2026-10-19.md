# Проверка безопасности и ошибок Delycafe

Дата: 19 октября 2026, Asia/Yekaterinburg. Проверена локальная рабочая копия, HEAD `0fb4dfd` (Delivery), версия приложения 1.6.1+61.

## Вывод

Найдены 5 проблем приоритета P1 и 5 проблем приоритета P2. P1 означает первоочередное исправление, P2 — следующую очередь. Это приоритет исправления, не числовая оценка CVSS. Признаков состоявшейся атаки проверка не устанавливает.

Проверка включала исходники Flutter, Django API, авторизацию, бонусы, создание и оплату заказов, формирование запроса в Saby, тарифы доставки, платёжный WebView и конфигурацию сборки. Исполняемые проверки работали на временной SQLite-базе в памяти и синтетических данных. Сетевые операции в итоговом прогоне бэкенда блокировались. Бизнес-код не изменён, на сервер ничего не загружено, платежей и SMS не отправлено.

## Результаты проверок

- Существующие Flutter-тесты: 99 выполнено, 98 прошли, 1 упал.
- Существующие тесты бэкенда: 131 выполнено, 127 прошли, 2 ошибки и 2 падения.
- Дополнительные проверки аудита: 8 сценариев воспроизвели дефекты; 5 проверок работающих защит прошли. `OK` в их логе означает успешное воспроизведение ожидаемого текущего поведения, а не отсутствие уязвимостей.
- Дополнительная проверка Dart: 4 небезопасных/нежелательных варианта URL приняты фильтром.
- `dart analyze lib test`: 47 замечаний уровня info, без error и warning.
- Локальный Django runtime: 6.0.5; в requirements.txt — 6.0.6. Версия сервера неизвестна.

Работающие защиты: статус платежа требует авторизации и проверяет владельца; запись в каталог через публичный API запрещена; неподтверждённая OTP-сессия не выдаёт токен; успешный callback не подтверждает оплату при недоступном банке. Прошли существующие тесты ротации refresh token и отзыва семейства при повторном использовании, тарифов, расчётов скидок и Saby. Токены приложения хранятся через FlutterSecureStorage.

## Находки

### F01 · P1 · Гостевой заказ получает права владельца номера

**Проверка:** Два сценария воспроизведены через локальный API.

OrderCreateAPIView допускает запрос без токена, а сериализатор выбирает Customer и неоплаченные заказы только по введённому телефону. Владение номером не проверяется перед списанием бонусов, обновлением профиля и отменой предыдущих заказов.

**Доказательство:** Анонимный запрос: HTTP 201, баланс другого тестового клиента 500 → 400, имя профиля изменено. Второй сценарий отменил чужой неоплаченный заказ; банковская сессия осталась записана.

**Последствия:** Использование чужих бонусов, изменение имени/адреса профиля и срыв чужого оформления заказа. Для воспроизведения хватило номера телефона; доступа к SMS не требовалось.

**Исправление:** Разделить гостевые и авторизованные заказы. Бонусы и изменение профиля разрешать только подтверждённому CustomerPrincipal. Повторное использование и отмену разрешать по владельцу или токену конкретного заказа, не по строке телефона. Во Flutter не повторять операции с бонусами анонимно после 401/403.

**Код:** [backend/orders/views.py:24](F:/newApplication/delycafe/backend/orders/views.py:24), [backend/orders/serializers.py:396](F:/newApplication/delycafe/backend/orders/serializers.py:396), [backend/orders/serializers.py:458](F:/newApplication/delycafe/backend/orders/serializers.py:458), [backend/orders/serializers.py:755](F:/newApplication/delycafe/backend/orders/serializers.py:755), [lib/services/order_api_service.dart:102](F:/newApplication/delycafe/lib/services/order_api_service.dart:102).

### F02 · P1 · Поддельный callback переводит оплаченный заказ в failed

**Проверка:** Воспроизведено через локальный публичный endpoint.

Успешное уведомление сверяется с банком, отрицательное — нет. Заказ находится в том числе по предсказуемому orderNumber, после чего payment_status безусловно меняется на failed.

**Доказательство:** Анонимное уведомление изменило синтетический оплаченный заказ paid → failed, HTTP 200. get_alfa_payment_status не вызывался.

**Последствия:** Порча статуса оплаты и нарушение последующей обработки заказов. Это изменение записи бэкенда, а не возврат денег в банке. Даже запоздалое настоящее уведомление может перезаписать более новый статус.

**Исправление:** Для любых уведомлений получать авторитетный статус банка, проверять привязку и сумму, менять состояние под блокировкой с разрешёнными переходами. Не понижать paid на основании неподтверждённого события. Подпись уведомлений, если предусмотрена договорённостью с банком, — дополнительная защита.

**Код:** [backend/payments/callback_handlers.py:48](F:/newApplication/delycafe/backend/payments/callback_handlers.py:48), [backend/payments/callback_handlers.py:146](F:/newApplication/delycafe/backend/payments/callback_handlers.py:146), [backend/payments/views.py:128](F:/newApplication/delycafe/backend/payments/views.py:128).

### F03 · P1 · Подтверждённую сессию входа можно забрать по числовому ID

**Проверка:** Воспроизведено на просроченной Mobile ID сессии.

OTP complete доступен без авторизации, принимает последовательный session_id и необязательный phone. Для уже verified сессии проверка срока действия отключена. Секрета, связывающего сессию с устройством, нет.

**Доказательство:** Сессия verified с expires_at сутки назад: по одному session_id API вернул access_token и refresh_token. Номер и код в запрос не передавались; токены в отчёт не включены.

**Последствия:** Перехват незавершённого подтверждённого входа, например если владелец подтвердил SIM-PUSH, но приложение не забрало результат. Это не вход в произвольный аккаунт без предварительного подтверждения: нужна существующая ещё не потреблённая verified сессия.

**Исправление:** Выдать случайный секрет авторизационной сессии, требовать его на status/verify/complete, проверять TTL во всех состояниях. Завершение и потребление сессии выполнять атомарно и однократно. Один обязательный телефон вместо секрета проблему не решит.

**Код:** [backend/customers/views.py:590](F:/newApplication/delycafe/backend/customers/views.py:590), [backend/customers/services/otp_auth_service.py:205](F:/newApplication/delycafe/backend/customers/services/otp_auth_service.py:205), [backend/customers/services/otp_auth_service.py:576](F:/newApplication/delycafe/backend/customers/services/otp_auth_service.py:576), [backend/customers/services/otp_auth_service.py:597](F:/newApplication/delycafe/backend/customers/services/otp_auth_service.py:597).

### F04 · P1 · Цена проверяется отдельно от идентификатора товара Saby

**Проверка:** Воспроизведено до формирования payload Saby.

Если переданный saby_id не найден среди активных товаров, цена берётся по product_api_id. apply_validated_item_prices заменяет только price и сохраняет исходный saby_id. В Saby передаётся этот несогласованный ID с вычисленной ценой.

**Доказательство:** Запрос с saby_id неактивной позиции за 5000 ₽ и product_api_id активной позиции за 1000 ₽ принят. Локальный payload Saby содержит ID дорогой позиции и cost=950 ₽ после скидки самовывоза. Внешний запрос не выполнялся.

**Последствия:** Несоответствие оплаченного товара отправленной номенклатуре; возможен заказ выключенной позиции по цене другой. Проверка равенства общей суммы Saby сама по себе эту ошибку не ловит.

**Исправление:** Однозначно разрешать товар/вариант на сервере и брать из одной записи ID Saby, цену, название и активность категории. Противоречащие друг другу идентификаторы отклонять до создания заказа и оплаты.

**Код:** [backend/orders/catalog_pricing.py:114](F:/newApplication/delycafe/backend/orders/catalog_pricing.py:114), [backend/orders/catalog_pricing.py:146](F:/newApplication/delycafe/backend/orders/catalog_pricing.py:146), [backend/orders/services.py:1064](F:/newApplication/delycafe/backend/orders/services.py:1064).

### F05 · P1 · Поздняя оплата отменённого заказа использует уже возвращённые бонусы

**Проверка:** Воспроизведена локальная цепочка отмена → подтверждение оплаты.

_cancel_unpaid_orders отменяет заказ и возвращает бонусы без закрытия/сверки его банковской сессии. confirm_order_paid принимает последующее подтверждение, сохраняет canceled и bonus_compensated=True, но пытается отправить заказ в Saby.

**Доказательство:** 100 бонусов списаны, затем возвращены при отмене. После позднего подтверждения: payment_status=paid, status=canceled, бонусы остались на балансе, отправка в Saby вызвана. Сетевые действия были заменены заглушками.

**Последствия:** Расхождение статусов, скидка по уже компенсированным бонусам и риск повторного использования одного баланса. Банковское окно может оставаться открытым, пока пользователь меняет корзину.

**Исправление:** Согласовать отмену с состоянием банковского платежа и вести резерв бонусов до окончательного исхода оплаты. Для позднего paid нужен явный согласованный переход и обработка резерва/компенсации; просто игнорировать уже полученные деньги нельзя.

**Код:** [backend/orders/serializers.py:396](F:/newApplication/delycafe/backend/orders/serializers.py:396), [backend/orders/services.py:96](F:/newApplication/delycafe/backend/orders/services.py:96), [backend/orders/services.py:721](F:/newApplication/delycafe/backend/orders/services.py:721), [backend/orders/services.py:733](F:/newApplication/delycafe/backend/orders/services.py:733), [backend/orders/services.py:760](F:/newApplication/delycafe/backend/orders/services.py:760).

### F06 · P2 · Основной путь подтверждения оплаты не проверяет сумму и валюту

**Проверка:** Воспроизведено на функции обработки синтетического ответа банка.

Проверки номера заказа, валюты и сумм есть в payments/reconciliation.py, но _apply_alfa_status_response при orderStatus=2 сразу вызывает confirm_order_paid. Этот путь используется обычной проверкой статуса и успешным callback.

**Доказательство:** При ожидаемых 1600 ₽ синтетический ответ с amount=100 копеек, другой валютой и другим orderNumber всё равно вызвал подтверждение. Реальный банк таких данных в тесте не возвращал.

**Последствия:** Защита от рассогласования суммы зависит от способа обработки платежа. Это не доказательство возможности подделать HTTPS-ответ банка; дефект проявится при ошибочной привязке сессии, изменении данных или неожиданном ответе.

**Исправление:** Использовать единый validate_paid_response во всех путях, подтверждающих оплату, перед любыми письмами, начислениями и отправкой в Saby.

**Код:** [backend/payments/services.py:207](F:/newApplication/delycafe/backend/payments/services.py:207), [backend/payments/services.py:725](F:/newApplication/delycafe/backend/payments/services.py:725), [backend/payments/reconciliation.py:10](F:/newApplication/delycafe/backend/payments/reconciliation.py:10).

### F07 · P2 · Отключение клиента не прекращает доступ

**Проверка:** Воспроизведено через API профиля.

CustomerTokenAuthentication ищет запись по ID и телефону, но не требует is_active=True. Синхронизация клиента из Saby также может вернуть is_active=True.

**Доказательство:** Тестовый клиент отключён после выдачи токена; GET профиля с этим токеном вернул HTTP 200. Обращение к Saby при проверке отключено.

**Последствия:** Административная блокировка не защищает профиль и операции существующей сессии. Для старых долгоживущих access token окно особенно велико.

**Исправление:** Проверять is_active при аутентификации и выдаче токенов; блокировать/отзывать сессии при отключении. Не реактивировать локально заблокированного клиента обычной синхронизацией.

**Код:** [backend/customers/authentication.py:52](F:/newApplication/delycafe/backend/customers/authentication.py:52), [backend/customers/views.py:456](F:/newApplication/delycafe/backend/customers/views.py:456), [backend/customers/services/saby_customer_service.py:707](F:/newApplication/delycafe/backend/customers/services/saby_customer_service.py:707).

### F08 · P2 · Фильтр платёжного WebView пропускает посторонние домены

**Проверка:** Воспроизведено вызовом настоящих Dart-функций без сети.

Доверие определяется через contains('alfabank'), подстроки пути success/fail и маркеры acs/3ds. Проверка не ограничивается точным HTTPS origin.

**Доказательство:** alfabank.attacker.invalid, attacker.invalid/api/payments/success/ и attacker.invalid/acs/login приняты как платёжные URL и оставлены внутри WebView. HTTP-ссылка настоящего шлюза тоже принята фильтром; системная политика телефона может дополнительно блокировать HTTP.

**Последствия:** Если недоверенная ссылка попадёт в цепочку оплаты, приложение способно показать её как платёжную страницу. Это ослабление защиты от фишинга; наличие реального внешнего источника такой ссылки здесь не доказано. Ложный success сам по себе не подтверждает оплату — статус всё ещё проверяется бэкендом.

**Исправление:** Парсить URI; проверять HTTPS и точное имя/корректный суффикс домена. Return URL сверять с origin API и точным путём. 3DS и банковские deep link обрабатывать отдельно, не доверяя произвольному слову acs.

**Код:** [lib/utils/url_allowlist.dart:63](F:/newApplication/delycafe/lib/utils/url_allowlist.dart:63), [lib/utils/url_allowlist.dart:92](F:/newApplication/delycafe/lib/utils/url_allowlist.dart:92), [lib/utils/payment_deeplink.dart:27](F:/newApplication/delycafe/lib/utils/payment_deeplink.dart:27), [lib/screens/order_payment_screen.dart:281](F:/newApplication/delycafe/lib/screens/order_payment_screen.dart:281).

### F09 · P2 · Синхронизация доставки держит блокировки базы во время сети

**Проверка:** Подтверждено чтением кода; конкурентная нагрузка PostgreSQL не измерялась.

В atomic-транзакции sync_delivery_tariffs сначала блокирует строки зон через select_for_update, затем делает OAuth-запрос и запрос районов Saby. Чтение delivery-config и расчёт тарифов тоже используют блокировки этих строк.

**Доказательство:** Порядок в saby_delivery_sync.py: строки 94 → 97. Таймауты запросов: 30 с OAuth и 20 с тарифы. Во Flutter получение delivery-config ограничено 15 с.

**Последствия:** Замедление Saby может задержать другие оформления и загрузку условий доставки. Это риск очередей и отказов по таймауту, а не результат проведённого нагрузочного теста. У OrderApiService.createOrder также отсутствует собственный timeout.

**Исправление:** Один синхронизатор с отдельным механизмом взаимного исключения; короткая транзакция записи проверенного снимка тарифов и защита от устаревших ответов. Сохранить проверку актуальности цены перед оплатой. Ограничить ожидание клиента с безопасным повтором по идентификатору операции.

**Код:** [backend/orders/saby_delivery_sync.py:84](F:/newApplication/delycafe/backend/orders/saby_delivery_sync.py:84), [backend/orders/delivery_views.py:28](F:/newApplication/delycafe/backend/orders/delivery_views.py:28), [backend/orders/delivery_pricing.py:15](F:/newApplication/delycafe/backend/orders/delivery_pricing.py:15), [lib/services/order_api_service.dart:94](F:/newApplication/delycafe/lib/services/order_api_service.dart:94).

### F10 · P2 · Зависимость Django отстаёт от опубликованных исправлений безопасности

**Проверка:** Проверен requirements.txt и официальное уведомление Django.

В requirements.txt закреплена 6.0.6; доступный локальный тестовый runtime оказался 6.0.5. Официальный выпуск 6.0.9 от 6 октября 2026 закрывает, в частности, проблему разбора HTTP-заголовков. Версия на сервере не проверялась.

**Доказательство:** requirements.txt:4; локально django.get_version() → 6.0.5; официальный security release 6.0.9. Эксплуатация CVE не проводилась, весь список зависимостей по базе CVE не сканировался.

**Последствия:** Повторная установка по текущему файлу зависимостей оставляет известные исправления за пределами сборки. Результаты локальных тестов не равнозначны тестам точно на серверной версии.

**Исправление:** Согласовать runtime и lock/requirements, обновить поддерживаемую ветку как минимум до выпуска с указанными исправлениями и заново прогнать проверки. Версию установленного Django на сервере проверить отдельно.

**Код:** [backend/requirements.txt:4](F:/newApplication/delycafe/backend/requirements.txt:4).

**Источник:** [официальное уведомление Django](https://www.djangoproject.com/weblog/2026/oct/06/security-releases/).

Для F08 рекомендация сверена с [Android Developers: Unsafe URI Loading](https://developer.android.com/privacy-and-security/risks/unsafe-uri-loading).

## Дополнительные наблюдения и настройки для проверки

### Режим SMS в production

При SMSAERO_ENABLED=False код разрешает фиксированный dev-код даже с DEBUG=False. Это условный риск: фактическая настройка сервера не читалась. Отключение SMS должно закрывать вход для обычных клиентов; демо-доступ App Review нужно изолировать и настраивать явно.

[Открыть файл](F:/newApplication/delycafe/backend/customers/services/otp_auth_service.py:405).

### Базы данных в Git

git ls-files включает backend/db.sqlite3 и db.sqlite3. В backend/db.sqlite3 обнаружены 1 auth_user, 2 клиента, 3 заказа и 2 записи сессий. Чувствительные значения не извлекались. Публичность репозитория и актуальность этих данных неизвестны; убрать данные из версионирования, оценить историю и доступ.

[Открыть файл](F:/newApplication/delycafe/backend/db.sqlite3).

### Подпись Android

release использует signingConfigs.getByName("debug"). Нужна управляемая release-подпись; перед сменой ключа проверить совместимость с уже установленными APK и настройками магазина.

[Открыть файл](F:/newApplication/delycafe/android/app/build.gradle.kts:37).

### Настройки HTTPS

Локальный check --deploy выдал HSTS, SSL redirect и пустой ALLOWED_HOSTS. Это не утверждение о сервере: .env и Nginx там отличаются. Проверить эти параметры на сервере, не включая DEBUG.

[Открыть файл](F:/newApplication/delycafe/backend/config/settings.py:28).

### Логи заказов

SabyOrderService пишет полный payload заказа с именем, телефоном и адресом в INFO-лог. Проверить доступ/срок хранения и заменить на минимальные технические поля.

[Открыть файл](F:/newApplication/delycafe/backend/orders/services.py:865).

### Падающие тесты

Flutter: ожидается 44×44, компонент задан 46×46. Бэкенд: два теста предзаказа не создают обязательные согласия; два теста SMS оставляют mobile_id_status ненастроенным MagicMock, который превращается в успешный числовой статус. Это дефекты/рассогласование тестов, а не доказательство четырёх сбоев у пользователей.

[Открыть файл](F:/newApplication/delycafe/test/widgets/glass_back_button_test.dart:13).

## Порядок исправления

1. Закрыть анонимные операции над чужим клиентом/заказами и потребление OTP по числовому ID (F01, F03).
2. Защитить все переходы статуса оплаты и обработать позднюю оплату отменённых заказов (F02, F05, F06).
3. Связать цену и номенклатуру одной серверной записью (F04).
4. Довести блокировку аккаунта, фильтрацию URL, синхронизацию доставки и зависимости (F07–F10).
5. Исправить тестовые фикстуры, добавить отрицательные регрессионные тесты и проверить всё на PostgreSQL и реальных устройствах.

Для F01 важно сохранить гостевое оформление без доступа к бонусам и профилю чужого номера. Для F03 потребуется согласованное обновление протокола входа приложения и бэкенда; нельзя оставлять обход для старых клиентов. При отказе в бонусах старое приложение должно предложить повторный вход/обновление, а не автоматически продолжать небезопасный путь.

## Границы проверки

Не проверялись: рабочая база и логи сервера, его .env/Nginx/TLS/firewall, публичность и полная история Git, реальная отправка в Saby/кассу и фискализация, реальный эквайринг/SMS, конкурентная нагрузка PostgreSQL, весь транзитивный список CVE и работа на физических iOS/Android. Статический аудит и тесты не гарантируют отсутствия остальных ошибок.

## Артефакты

- [Лог бэкенд-тестов](F:/newApplication/delycafe/build/security-audit-backend.log)
- [Лог Flutter-тестов](F:/newApplication/delycafe/build/security-audit-flutter.log)
- [Статический анализ Dart](F:/newApplication/delycafe/build/security-audit-analyze.log)
- [Сценарии воспроизведения](F:/newApplication/delycafe/build/security-audit/audit_probes.py)
- [Изолированный запуск проверок](F:/newApplication/delycafe/build/security-audit/run_backend_audit.py)
- [Результаты воспроизведения](F:/newApplication/delycafe/build/security-audit/probes.log)
- [Проверка фильтра URL](F:/newApplication/delycafe/build/security-audit/url_probe.dart)
- [Результаты фильтра URL](F:/newApplication/delycafe/build/security-audit/url-probe.log)
- [Локальный check --deploy](F:/newApplication/delycafe/build/security-audit/deploy-check.log)

Логи и скрипты лежат в build и будут удалены при очистке сборки. Содержание выводов сохранено в этом отчёте. Имевшиеся до проверки изменения cron.example, удаление delivery-tariffs.md и .vscode/settings.json не менялись.

