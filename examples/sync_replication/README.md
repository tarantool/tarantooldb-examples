# Включение и использование синхронной репликации

В этом руководстве показано, как настроить кластер Tarantool DB для работы в режиме синхронной репликации, а также как повысить надежность переключения лидеров с помощью перевода кластера в режим `election_mode = 'manual'`.

Для примера используется база данных заказов клиентов (`orders`), требовательная к гарантиям сохранности данных при отказе узлов.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Особенности работы синхронной репликации](#особенности-работы-синхронной-репликации)
* [Запуск стенда и проверка статуса](#запуск-стенда-и-проверка-статуса)
* [Включение синхронного режима через HTTP API](#включение-синхронного-режима-через-http-api)
* [Запись данных в синхронный спейс](#запись-данных-в-синхронный-спейс)
* [Проверка устойчивости синхронной репликации при отказе узлов](#проверка-устойчивости-синхронной-репликации-при-отказе-узлов)
* [Перевод наборов реплик в election\_mode = manual](#перевод-репликасетов-в-election_mode--manual)
  * [Проверка текущего режима](#проверка-текущего-режима)
  * [Динамическая смена режимов выборов](#динамическая-смена-режимов-выборов)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* исходные файлы примера `sync_replication`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `sync_replication` расположен в директории `examples/sync_replication`.
>  * Отдельный архив [sync_replication.zip](https://download-directory.github.io/?url=https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master/examples/sync_replication&filename=sync_replication), скачанный из этого репозитория.

## Особенности работы синхронной репликации

Синхронная репликация гарантирует, что транзакция считается успешно завершенной только после того, как запись в журнал упреждающей записи (WAL) выполнена на лидере и после подтверждена кворумом реплик.

Для корректной работы [автоматического восстановления после отказов](https://www.tarantool.io/docs/tdb/ru/1_x/admin_guide/failover) (failover) и захвата синхронной очереди в Tarantool DB должны быть соблюдены все условия ниже:

1. Включён `failover_mode = 'stateful'`.
2. Включена поддержка синхронного режима через переменную окружения: `TARANTOOL_ENABLE_SYNCHRO_MODE=true`.
   > `TARANTOOL_ENABLE_SYNCHRO_MODE` работает только в сочетании с `stateful` failover и автоматически вызывает `box.ctl.promote()` на новых лидерах репликасетов.

> [!IMPORTANT]
>  Ограничения:
>  * Режим Stateful failover не поддерживает работу с репликасетами, у которых включена опция `all_rw = true`, а также с репликасетами, состоящими из одного узла.
>  * Если автоматический failover отключен, для корректной работы с синхронными спейсами потребуется вручную вызывать `box.ctl.promote()` на новых лидерах репликасетов. 

## Запуск стенда и проверка статуса

Для успешного запуска должны быть свободны порты:

* 3301—3306;
* 8081—8086;
* 12379, 12380, 22379, 22380, 32379, 32380.

Перейдите в папку с примером `sync_replication` и запустите стенд:

```shell
cd examples/sync_replication
docker compose up -d
```

Команда развернет стенд, который состоит из:
* кластера Tarantool DB из двух шардов и двух роутеров;
* кластера etcd для работы восстановления после сбоев (failover) кластера Tarantool DB.

После запуска должны работать все контейнеры, кроме `user-host`.

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.

## Включение синхронного режима через HTTP API

В миграции мы создаём спейс `orders`, который сконфигурирован как синхронный (содержит флаг `is_sync = true`). Однако по умолчанию после старта кластера **системные спейсы** создаются в асинхронном режиме.

Чтобы перевести системные спейсы в синхронный режим, отправьте POST-запрос на HTTP-ендпоинт `/sync` любого узла (например, на порт 8081):

```shell
curl -X POST "http://localhost:8081/sync"
```

При успешном выполнении команда вернет JSON-ответ со статусом `success` для стораджей и списком синхронных спейсов:

```json
{
    "router-msk" : {
        "status" : "skipped",
        "async_spaces" : [ "_vinyl_deferred_delete", "_schema", "_collation", "_vcollation", "_space", "_vspace", "_sequence", "_sequence_data", "_vsequence", "_index", "_vindex", "_func", "_vfunc", "_user", "_vuser", "_priv", "_vpriv", "_cluster", "_trigger", "_truncate", "_space_sequence", "_vspace_sequence", "_fk_constraint", "_ck_constraint", "_func_index", "_session_settings", "dictionary_data", "dictionary_vclock", "_migrations" ],
        "sync_spaces" : [ ]
    },
    "router-spb" : {
        "status" : "skipped",
        "async_spaces" : [ "_vinyl_deferred_delete", "_schema", "_collation", "_vcollation", "_space", "_vspace", "_sequence", "_sequence_data", "_vsequence", "_index", "_vindex", "_func", "_vfunc", "_user", "_vuser", "_priv", "_vpriv", "_cluster", "_trigger", "_truncate", "_space_sequence", "_vspace_sequence", "_fk_constraint", "_ck_constraint", "_func_index", "_session_settings", "dictionary_data", "dictionary_vclock", "_migrations" ],
        "sync_spaces" : [ ]
    },
    "storage-1" : {
        "status" : "success",
        "async_spaces" : [ "_vinyl_deferred_delete", "_sequence_data", "_session_settings", "dictionary_data", "dictionary_vclock", "_crud_settings_local" ],
        "sync_spaces" : [ "_schema", "_collation", "_vcollation", "_space", "_vspace", "_sequence", "_vsequence", "_index", "_vindex", "_func", "_vfunc", "_user", "_vuser", "_priv", "_vpriv", "_cluster", "_trigger", "_truncate", "_space_sequence", "_vspace_sequence", "_fk_constraint", "_ck_constraint", "_func_index", "_bucket", "_migrations", "orders", "_ddl_sharding_key" ]
    },
    "storage-2" : {
        "status" : "success",
        "async_spaces" : [ "_vinyl_deferred_delete", "_sequence_data", "_session_settings", "dictionary_data", "dictionary_vclock", "_crud_settings_local" ],
        "sync_spaces" : [ "_schema", "_collation", "_vcollation", "_space", "_vspace", "_sequence", "_vsequence", "_index", "_vindex", "_func", "_vfunc", "_user", "_vuser", "_priv", "_vpriv", "_cluster", "_trigger", "_truncate", "_space_sequence", "_vspace_sequence", "_fk_constraint", "_ck_constraint", "_func_index", "_bucket", "_migrations", "orders", "_ddl_sharding_key" ]
    }
}
```

> [!WARNING]
>  Опасность совмещения синхронных и асинхронных спейсов:
> 
>  Асинхронные транзакции коммитятся на лидере мгновенно, без подтверждения реплик. При аварийном переключении лидера асинхронные данные могут остаться только на старом узле.
>  При восстановлении связи это приведет к ошибке ER_SPLIT_BRAIN, для устранения которой потребуется ручной rebootstrap старого лидера.

## Запись данных в синхронный спейс

1. Подключитесь к одному из роутеров с помощью команды `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

2. Выполните запись заказов в спейс `orders` через модуль `crud`:

```shell
localhost:3301> crud.insert_object_many('orders', {
    {order_id = 1, customer_name = 'Customer_A', amount = 1500.00, status = 'new'},
    {order_id = 2, customer_name = 'Customer_B', amount = 3200.50, status = 'paid'},
})
---
- rows:
  - [1, 12477, 'Customer_A', 1500, 'new']
  - [2, 21401, 'Customer_B', 3200.5, 'paid']
  metadata: [{'name': 'order_id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'customer_name', 'type': 'string'}, {'name': 'amount', 'type': 'number'},
    {'name': 'status', 'type': 'string'}]
- null
...
```

Поскольку спейс `orders` работает в синхронном режиме, операция записи завершается только после того, как WAL-запись подтверждена кворумом реплик.

## Проверка устойчивости синхронной репликации при отказе узлов

Чтобы убедиться, что синхронная репликация гарантирует сохранность данных и предотвращает запись при отсутствии связи с большинством, протестируем поведение кластера при потере кворума.

В нашей топологии используется 2 шарда по 3 узла в каждом (`msk`, `spb`, `brn`). Для репликасета из 3 узлов минимальный кворум равен **2** (`floor(3/2) + 1`).

Остановим по 2 узла в обоих шардах, оставив только лидеров:

```shell
docker compose stop tarantool-storage-1-spb tarantool-storage-1-brn tarantool-storage-2-spb tarantool-storage-2-brn
```

Теперь в каждом репликасете работает только **1 узел из 3**. Минимальный кворум (2 узла) не набран.

Попытка обновить данные завершится ошибкой по таймауту:

```shell
localhost:3301> crud.replace('orders', {1, box.NULL, 'Customer_C', 1500.00, 'new
'})
---
- null
- line: 123
  class_name: ReplaceError
  err: "Failed to call replace on storage-side: CallError: Failed for 25c18355-d0e6-4817-877f-65298985a847:
    Function returned an error: {\"errno\":110,\"code\":0,\"trace\":[{\"file\":\".\\/tarantool\\/src\\/box\\/lua\\/net_box.c\",\"line\":2364}],\"type\":\"TimedOut\",\"message\":\"timed
    out\",\"base_type\":\"TimedOut\"}\nstack traceback:\n\t.../tarantooldb/.rocks/share/tarantool/crud/common/call.lua:252:
    in function 'single'\n\t...tool/tarantooldb/.rocks/share/tarantool/crud/replace.lua:116:
    in function 'method'\n\t...ldb/.rocks/share/tarantool/crud/common/sharding/init.lua:217:
    in function 'func'\n\t...arantooldb/.rocks/share/tarantool/crud/common/schema.lua:101:
    in function <...arantooldb/.rocks/share/tarantool/crud/common/schema.lua:96>\n\t[C]:
    in function 'pcall'\n\teval:43: in main chunk\n\t[C]: at 0x561df8669a20"
  file: '...tool/tarantooldb/.rocks/share/tarantool/crud/replace.lua'
  str: "ReplaceError: Failed to call replace on storage-side: CallError: Failed for
    25c18355-d0e6-4817-877f-65298985a847: Function returned an error: {\"errno\":110,\"code\":0,\"trace\":[{\"file\":\".\\/tarantool\\/src\\/box\\/lua\\/net_box.c\",\"line\":2364}],\"type\":\"TimedOut\",\"message\":\"timed
    out\",\"base_type\":\"TimedOut\"}\nstack traceback:\n\t.../tarantooldb/.rocks/share/tarantool/crud/common/call.lua:252:
    in function 'single'\n\t...tool/tarantooldb/.rocks/share/tarantool/crud/replace.lua:116:
    in function 'method'\n\t...ldb/.rocks/share/tarantool/crud/common/sharding/init.lua:217:
    in function 'func'\n\t...arantooldb/.rocks/share/tarantool/crud/common/schema.lua:101:
    in function <...arantooldb/.rocks/share/tarantool/crud/common/schema.lua:96>\n\t[C]:
    in function 'pcall'\n\teval:43: in main chunk\n\t[C]: at 0x561df8669a20"
...
```

Это штатное и ожидаемое поведение: Tarantool DB блокирует запись, предотвращая рассинхронизацию и потерю данных в условиях отсутствия связи с большинством узлов.

Запустите остановленные контейнеры обратно:

```shell
docker compose start tarantool-storage-1-spb tarantool-storage-1-brn tarantool-storage-2-spb tarantool-storage-2-brn
```

Как только реплики поднимутся и догонят WAL лидера, кворум восстановится, и операции записи снова будут завершаться успешно:

```shell
localhost:3301> crud.replace('orders', {1, box.NULL, 'Customer_C', 1500.00, 'new'})
---
- rows:
  - [1, 12477, 'Customer_C', 1500, 'new']
  metadata: [{'name': 'order_id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'customer_name', 'type': 'string'}, {'name': 'amount', 'type': 'number'},
    {'name': 'status', 'type': 'string'}]
- null
...
```

## Перевод репликасетов в election_mode = manual

По умолчанию `stateful failover` использует `election_mode = 'off'`, полагаясь при смене лидера на сравнение `vclock`.

Перевод кластера в `election_mode = 'manual'` включает механизм выборов Raft при вызове `box.ctl.promote()`. В этом режиме новый лидер должен не просто догнать WAL старого мастера, но и собрать кворум узлов. Это защищает от ситуаций, когда узел объявляется мастером, будучи изолированным от остальных реплик.

Ниже рассмотрен пример проверки и изменения режима выборов. Подробное руководство по миграции также доступно в [документации Cartridge](https://www.tarantool.io/ru/doc/2.11/book/cartridge/cartridge_dev/#migrating-a-stateful-replicaset-to-manual-election-mode).

### Проверка текущего режима

Подключитесь к лидеру первого хранилища (`storage-1-msk`, порт 3303):

```shell
tt connect admin:secret-cluster-cookie@localhost:3303
```

В данном примере режим выборов `manual` предварительно задан через переменные окружения на всех узлах хранилища:

```yaml
TARANTOOL_ELECTION_MODE: "manual"
TARANTOOL_ELECTION_FENCING_MODE: "off"
```

Проверьте текущие настройки:

```shell
localhost:3303> box.cfg.election_mode
---
- manual
...

localhost:3303> box.cfg.election_fencing_mode
---
- off
...
```

### Динамическая смена режимов выборов

Начиная с Cartridge версии 2.17.0 (Tarantool DB 1.2.6) вы можете динамически переключать режим выборов, вызывая хелперы на всех лидерах хранилищ:

* `require('cartridge.lua-api.failover').switch_to_manual_election_mode()` — перевод в `manual election mode`.
* `require('cartridge.lua-api.failover').switch_to_off_election_mode()` — выключение `election mode`.

#### Динамическое отключение election mode

```shell
localhost:3303> require('cartridge.lua-api.failover').switch_to_off_election_mode()
---
- true
...
localhost:3303> box.cfg.election_mode
---
- off
...

localhost:3303> box.cfg.election_fencing_mode
---
- soft
...

```

#### Повторное включение manual election mode

```shell
localhost:3303> require('cartridge.lua-api.failover').switch_to_manual_election_mode()
---
- true
...

localhost:3303> box.cfg.election_mode
---
- manual
...

localhost:3303> box.cfg.election_fencing_mode
---
- off
...
```

> [!WARNING]
>  Эти хелперы применяют настройки динамически, но не являются персистентными. Перед будущими рестартами узлов необходимо явно переопределить переменные окружения `TARANTOOL_ELECTION_MODE` и `TARANTOOL_ELECTION_FENCING_MODE`.

## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
