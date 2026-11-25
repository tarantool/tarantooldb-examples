# Идемпотентное выполнение CRUD-операций (параметр `idempotency`)

Параметр `idempotency` доступен с версии TDB 3.5.0.

В этом руководстве показано, как выполнять DML-операции CRUD идемпотентно: передавать
ключ идемпотентности в параметре `idempotency` операций `crud.insert`, `crud.update`,
`crud.upsert` и других, обрабатывать ошибки повторов, наблюдать за состоянием
идемпотентности с помощью метрик и управлять его очисткой методами
`crud.idempotency.cleanup()` и `crud.idempotency.delete()`.

Сценарии выполняются из Lua через терминал TCM. Отдельный раздел показывает
идемпотентность в хранимой процедуре — примитив `crud.idempotency.mark()`, вызываемый
через `crud.storage_call()`.

Подробное описание методов и параметров приведено в
[справочнике модуля CRUD](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/crud).

Содержание:

- [Идемпотентное выполнение CRUD-операций (параметр `idempotency`)](#идемпотентное-выполнение-crud-операций-параметр-idempotency)
  - [Пререквизиты](#пререквизиты)
  - [Используемые файлы](#используемые-файлы)
  - [Запуск стенда](#запуск-стенда)
  - [Монотонный режим: поток платежей](#монотонный-режим-поток-платежей)
  - [Случайный режим: операции с внешним идентификатором](#случайный-режим-операции-с-внешним-идентификатором)
  - [Смена режима ключа](#смена-режима-ключа)
  - [Обработка ошибок повтора в приложении](#обработка-ошибок-повтора-в-приложении)
  - [Идемпотентность в хранимой процедуре](#идемпотентность-в-хранимой-процедуре)
  - [Поведение при смене мастера](#поведение-при-смене-мастера)
  - [Окно идемпотентности (TTL)](#окно-идемпотентности-ttl)
  - [Очистка истекших маркеров](#очистка-истекших-маркеров)
  - [Удаление маркера по ключу](#удаление-маркера-по-ключу)
  - [Мониторинг и метрики](#мониторинг-и-метрики)
  - [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB версии 3.4.0 или выше;
* приложение Docker Compose;
* исходные файлы примера `crud_idempotency`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `crud_idempotency` расположен в директории `examples/crud_idempotency`.
> * Отдельный архив [crud_idempotency.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fcrud_idempotency&filename=crud_idempotency), скачанный из этого репозитория.

## Используемые файлы

В руководстве используются следующие файлы примера `crud_idempotency`:

* `Makefile` — запуск и остановка стенда;
* `tt/cluster/` — директория с файлами для запуска кластера Tarantool DB:
  * `config.yml` — конфигурация кластера (роли `crud-router` и `crud-storage`,
    экспорт метрик, режимы отказоустойчивости);
  * `docker-compose.yml` — описание узлов кластера и применение миграции;
  * `migrations/scenario/001_payments.lua` — миграция, создающая спейсы `accounts` и
    `orders` и хранимую функцию `app.process_payment`;
* `tt/tools/` — директория с файлами для запуска etcd и TCM:
  * `docker-compose.yml` — описание узлов etcd и TCM;
  * `tcm.yml` — конфигурация [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081
* 8088

Перейдите в директорию примера `crud_idempotency`:

```shell
cd examples/crud_idempotency
```

Стенд состоит из:

* кластера Tarantool DB:
  * 2 роутера;
  * 2 набора реплик по 3 хранилища;
* кластера etcd из 3 узлов;
* 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM).

Запустите стенд следующей командой:

```shell
make start
```

Команда `make start` создает сеть Docker, запускает кластер etcd, публикует конфигурацию
кластера в etcd, запускает TCM и узлы Tarantool DB, выполняет начальную инициализацию
кластера (bootstrap шардирования) и применяет миграции. Проверить успешное завершение
инициализации можно в логах:

```shell
docker compose -f tt/cluster/docker-compose.yml logs init_host | tail -1
```

Вывод:

```text
Initialize has completed successfully.
```

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

* **Username**: `admin`
* **Password**: `secret`

В ходе запуска кластера выполняется миграция из файла `./tt/cluster/migrations/scenario/001_payments.lua`,
которая создает два шардированных спейса и хранимую функцию:

* `accounts` — счета клиентов (ключ шардирования `account_id`). Спейс создан с
  `is_sync = true` — записи подтверждаются кворумом реплик; это предусловие гарантии
  идемпотентности при смене мастера (см. раздел [Поведение при смене мастера](#поведение-при-смене-мастера));
* `orders` — заказы с внешним идентификатором (ключ шардирования `external_id`);
* `app.process_payment` — хранимая функция для раздела
  [Идемпотентность в хранимой процедуре](#идемпотентность-в-хранимой-процедуре).

В TCM откройте вкладку **Stateboard**. После применения настроек кластера в наборе реплик
`router-msk` доступен узел `router-msk`. Все сценарии ниже выполняются в его терминале:
выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

## Монотонный режим: поток платежей

Чтобы включить идемпотентность, передайте параметр `idempotency` в `opts` вызова.
Сценарий: обработчик читает поток платежей и зачисляет каждый платеж на счет. Ключ
идемпотентности — имя потока (`payments-1`), `seq` — смещение сообщения в потоке.
Ретрай после таймаута передает ту же пару `(key, seq)`.

Создайте счет с балансом 1000:

```lua
crud.insert('accounts', {1, box.NULL, 1000})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1000]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Зачислите первый платеж — сообщение с offset 1041 на 100:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1041, ttl = 3600}})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1100]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Платеж применен: баланс вырос на 100, а для пары `('payments-1', 12477)` сохранер маркер с
`applied_max = 1041` и сроком жизни 3600 секунд.

Выполним ту же операцию повторно, имитируя ретрай после таймаута:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1041, ttl = 3600}})
```

Операция отклонена — вместо результата возвращается ошибка `IdempotencyDuplicateError`:

```yaml
---
- err: operation for key 'payments-1' in bucket 12477 is already applied (applied_max=1041)
  key: payments-1
  bucket_id: 12477
  seq: 1041
  applied_max: 1041
  class_name: IdempotencyDuplicateError
...
```

Баланс не изменился:

```lua
crud.get('accounts', {1})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1100]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Передайте теперь меньший номер — сообщение с offset 1040, доставка которого задержалась:

```lua
res, err = crud.update('accounts', {1}, {{'+', 'balance', 100}},
                       {idempotency = {key = 'payments-1', seq = 1040, ttl = 3600}})
err.class_name, err.applied_max
```

Вывод:

```yaml
---
- IdempotencyStaleError
- 1041
...
```

Отставание распознается по классу `IdempotencyStaleError`: значение `seq` меньше
примененного `applied_max` (поле `err.applied_max`), повторять такое сообщение нельзя —
оно уже обработано.

Новое сообщение с offset 1042 применяется обычным образом:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1042, ttl = 3600}})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1200]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

## Случайный режим: операции с внешним идентификатором

Сценарий: заказ поступает из внешней системы с идентификатором `external_id`. Клиент
генерирует первичный ключ `order_id` самостоятельно — при ретрае после таймаута он
генерируется заново. Сначала посмотрите, что происходит без идемпотентности — две
попытки вставки одного и того же заказа:

```lua
fiber = require('fiber')
crud.insert('orders', {101, 'order-external-42', box.NULL, 500, fiber.time()})
crud.insert('orders', {102, 'order-external-42', box.NULL, 500, fiber.time()})
crud.select('orders')
```

Вывод (последняя команда):

```yaml
---
- metadata: [{'name': 'order_id', 'type': 'unsigned'}, {'name': 'external_id', 'type': 'string'},
    {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'amount', 'type': 'unsigned'},
    {'name': 'created_at', 'type': 'unsigned'}]
  rows:
  - [101, 'order-external-42', 1044, 500, 1795608317]
  - [102, 'order-external-42', 1044, 500, 1795608317]
- null
...
```

В спейсе оказался дубль: два заказа с одним внешним идентификатором. Уберите данные и
повторите сценарий с идемпотентностью:

```lua
crud.delete('orders', {101}, {bucket_id = 1044})
```

Вывод:

```yaml
---
- rows:
  - [101, 'order-external-42', 1044, 500, 1795608317]
  metadata: [{'name': 'order_id', 'type': 'unsigned'}, {'name': 'external_id', 'type': 'string'},
    {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'amount', 'type': 'unsigned'},
    {'name': 'created_at', 'type': 'unsigned'}]
- null
...
```

Вставьте заказ, передав внешний идентификатор в роли ключа идемпотентности (`seq` не
передается — случайный режим):

```lua
crud.insert('orders', {201, 'order-external-42', box.NULL, 500, os.time()},
            {idempotency = {key = 'order-external-42', ttl = 86400}})
```

Вывод:

```yaml
---
- rows:
  - [201, 'order-external-42', 1044, 500, 1795608317]
  metadata: [{'name': 'order_id', 'type': 'unsigned'}, {'name': 'external_id', 'type': 'string'},
    {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'amount', 'type': 'unsigned'},
    {'name': 'created_at', 'type': 'unsigned'}]
- null
...
```

Повторная вставка — клиент сгенерировал новый `order_id`, но передает тот же ключ
идемпотентности:

```lua
crud.insert('orders', {202, 'order-external-42', box.NULL, 500, os.time()},
            {idempotency = {key = 'order-external-42', ttl = 86400}})
```

Вывод:

```yaml
---
- err: operation for key 'order-external-42' in bucket 1044 is already applied
  key: order-external-42
  bucket_id: 1044
  seq: null
  applied_max: null
  class_name: IdempotencyDuplicateError
...
```

Дубль не создан:

```lua
crud.select('orders')
```

Вывод:

```yaml
---
- metadata: [{'name': 'order_id', 'type': 'unsigned'}, {'name': 'external_id', 'type': 'string'},
    {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'amount', 'type': 'unsigned'},
    {'name': 'created_at', 'type': 'unsigned'}]
  rows:
  - [201, 'order-external-42', 1044, 500, 1795608317]
- null
...
```

## Смена режима ключа

Выполните операцию с ключом `payments-1` без `seq`, как к случайному ключу:

```lua
res, err = crud.update('accounts', {1}, {{'+', 'balance', 100}},
                       {idempotency = {key = 'payments-1', ttl = 3600}})
err.class_name, err.mode, err.applied_max
```

Вывод:

```yaml
---
- IdempotencyModeMismatchError
- monotone
- 1042
...
```

Операция не выполнилась, баланс не изменился. Изменить режим у маркера нельзя, только дождаться
его удаления — истечением окна или сбросом
ключа `crud.idempotency.delete()`.

## Обработка ошибок повтора в приложении

Классы ошибок различаются по `err.class_name`, числовых кодов нет. Нужные значения
передаются полями объекта ошибки (`key`, `bucket_id`, `seq`, `applied_max`, `mode`), а не
текстом сообщения: `err.err` предназначен только для логов и UI.

| Класс | Когда возникает | Что делать клиенту |
|---|---|---|
| `IdempotencyDuplicateError` | операция уже применена: `seq = applied_max` (монотонный) или ключ уже использован (случайный) | не повторять, подтвердить позицию обработки |
| `IdempotencyStaleError` | `seq < applied_max` — значение отстало | не повторять, подтвердить позицию; `err.applied_max` — для политики отложенных сообщений и метрик |
| `IdempotencyModeMismatchError` | существует маркер с другим режимом | ошибка интеграции: не повторять; использовать ключ в режиме `err.mode` либо удалить его `crud.idempotency.delete()` и завести заново |
| `IdempotencyError` | неверные `opts` или аргументы административных методов; `mark` вне транзакции, на роутере или на реплике | ошибка запроса или окружения: исправить и повторить — операция не применилась |

Типичный обработчик потока различает классы ошибок:

```lua
-- Внутри обработчика потока: retry передает тот же (key, seq)
local _, err = crud.update('accounts', {msg.account_id},
                           {{'+', 'balance', msg.amount}},
                           {idempotency = {key = 'payments-' .. msg.stream_id,
                                           seq = msg.offset, ttl = 3600}})
if err == nil then
    return 'applied'
end
if err.class_name == 'IdempotencyDuplicateError' then
    return 'already_applied'
end
if err.class_name == 'IdempotencyStaleError' then
    return 'stale', err.applied_max
end
error(err) -- Иная ошибка.
```

## Идемпотентность в хранимой процедуре

В миграции примера зарегистрирована функция `app.process_payment` — она зачисляет платеж
на счет внутри `box.atomic()` с использованием `crud.idempotency.mark()`:

```lua
return box.atomic(function()
    -- Проверка и запись маркера идемпотентности — в той же
    -- транзакции, что и изменение баланса: применяются
    -- обе записи либо ни одна.
    local _, err = crud.idempotency.mark({
        key = idem.key,
        seq = idem.seq,
        ttl = idem.ttl,
        bucket_id = account.bucket_id,
        engine = 'memtx',
    })
    if err ~= nil then
        -- Повтор, отставание или смена режима ключа —
        -- откат транзакции целиком, баланс не меняется.
        error(err)
    end
    local updated = box.space.accounts:update(
        {account_id}, {{'+', 'balance', amount}})
    return updated.balance
end)
```

Вызовите функцию через `crud.storage_call`, передав ключ идемпотентности аргументом:

```lua
result, err = crud.storage_call('app.process_payment',
    {1, 100, {key = 'payments-2', seq = 7, ttl = 3600}},
    {space_name = 'accounts', key = {1}})
result.returns[1], err
```

Вывод:

```yaml
---
- 1300
- null
...
```

Платеж применен: баланс счета вырос со 1200 до 1300. Повторите вызов с той же парой
`(key, seq)`:

```lua
result, err = crud.storage_call('app.process_payment',
    {1, 100, {key = 'payments-2', seq = 7, ttl = 3600}},
    {space_name = 'accounts', key = {1}})
result, err
```

Вывод:

```yaml
---
- null
- err: operation for key 'payments-2' in bucket 12477 is already applied (applied_max=7)
  key: payments-2
  bucket_id: 12477
  seq: 7
  applied_max: 7
  class_name: IdempotencyDuplicateError
...
```

Транзакция отклонена целиком: баланс счета остался 1300. Ошибка `mark` откатывает весь
пакет процедуры. DML внутри процедуры не должны задавать собственный `opts.idempotency`:
дедупликация выполняется одним маркером на весь пакет.

## Поведение при смене мастера

Примените платеж — и предположим, что ответ клиенту был потерян:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1043, ttl = 3600}})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1400]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Определите, какой набор реплик владеет бакетом счета и кто в нем мастер:

```lua
rs = require('vshard').router.route(12477)
rs.name, rs.master.name
```

Вывод:

```yaml
---
- storage-1
- storage-1-brn
...
```

Имя мастера зависит от выборов внутри набора реплик — в вашем стенде оно может отличаться.
Остановите контейнер этого узла (подставьте имя из вывода выше):

```shell
docker compose -f tt/cluster/docker-compose.yml stop tarantool-storage-1-brn
```

Вывод:

```text
 Container cluster-tarantool-storage-1-brn-1 Stopped
```

Подождите 10–15 секунд, пока набор реплик выберет нового мастера, а роутер его
обнаружит, и повторите ту же операцию — ретрай потерянного вызова:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1043, ttl = 3600}})
```

Вывод:

```yaml
---
- err: operation for key 'payments-1' in bucket 12477 is already applied (applied_max=1043)
  key: payments-1
  bucket_id: 12477
  seq: 1043
  applied_max: 1043
  class_name: IdempotencyDuplicateError
...
```

Повтор после смены мастера не применил операцию заново: маркер с `applied_max = 1043`
пережил failover вместе с данными. Проверьте баланс — он не изменился:

```lua
crud.get('accounts', {1})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1400]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Новое сообщение потока применяется на новом мастере уже обычным образом:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1044, ttl = 3600}})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1500]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Верните остановленный узел в стенд (подставьте имя узла, который останавливали):

```shell
docker compose -f tt/cluster/docker-compose.yml start tarantool-storage-1-brn
```

## Окно идемпотентности (TTL)

Примените операцию с коротким окном в 5 секунд:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1045, ttl = 5}})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1600]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Подождите, пока окно истечет, и повторите ту же операцию:

```lua
require('fiber').sleep(6)
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-1', seq = 1045, ttl = 5}})
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 1700]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Маркер истек, и операция применилась заново.

## Очистка истекших маркеров

Создайте маркер с коротким окном, дождитесь истечения и удалите истекшее принудительно:

```lua
crud.update('accounts', {1}, {{'+', 'balance', 100}},
            {idempotency = {key = 'payments-3', seq = 1, ttl = 2}})
require('fiber').sleep(3)
crud.idempotency.cleanup(0)
```

Вывод первой команды:

```yaml
---
- rows:
  - [1, 12477, 1800]
  metadata: [{'name': 'account_id', 'type': 'unsigned'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'balance', 'type': 'unsigned'}]
- null
...
```

Вывод последней команды:

```yaml
---
- 1
...
```

## Удаление маркера по ключу

Удалите ключ `payments-2` c монотонным режимом созданный ранее:

```lua
crud.idempotency.delete('payments-2')
```

Вывод:

```yaml
---
- 1
...
```

Теперь ключ можно завести заново в любом режиме — например, в случайном, без `seq`:

```lua
res, err = crud.update('accounts', {1}, {{'+', 'balance', 100}},
                       {idempotency = {key = 'payments-2', ttl = 3600}})
err == nil
```

Вывод:

```yaml
---
- true
...
```

Обращение без `seq` к ключу, заведенному монотонным, до сброса завершалось бы ошибкой
`IdempotencyModeMismatchError` (см. раздел [Смена режима ключа](#смена-режима-ключа)).

## Мониторинг и метрики

Чтобы просмотреть метрики в TCM:

1. Перейдите на вкладку **Stateboard**.
2. Выберите в наборе реплик `storage-1` любой узел (например, `storage-1-msk`) и в
   открывшемся окне перейдите на вкладку **Metrics**.
3. Найдите метрики `tnt_crud_idempotency_*` — после выполненных выше сценариев счетчик
   `tnt_crud_idempotency_ops_total` содержит статусы `applied`, `duplicate` и `stale`
   по спейсам `accounts` и `orders`.

## Остановка стенда

Для остановки стенда выполните следующую команду:

```shell
make stop
```
