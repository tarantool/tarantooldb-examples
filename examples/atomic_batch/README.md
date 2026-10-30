# Атомарное выполнение CRUD-операций через crud.atomic_batch()

 Метод `crud.atomic_batch()` доступен с версии TDB 3.3.0.
 Пример добавлен в версии 3.4.0.

В примере рассматривается метод `crud.atomic_batch`, который выполняет упорядоченный список
простых CRUD-операций (`get`, `insert`, `replace`, `update`, `upsert`, `delete`) над разными
спейсами атомарно — в рамках одной транзакции на одном шарде. Если хотя бы одна операция
завершается ошибкой или операции нацелены на разные бакеты, вся транзакция откатывается,
а данные остаются в исходном состоянии.

В качестве сценария используется перевод средств между счетами одного клиента: списание со
счёта-источника, зачисление на счёт-получатель и запись в журнал переводов должны примениться
все вместе либо не примениться вовсе.

В примере показаны два способа вызова `crud.atomic_batch`:

* напрямую из Lua на роутере;
* из Go-приложения через коннектор [`go-tarantool`](https://pkg.go.dev/github.com/tarantool/go-tarantool/v3) v3.

Подробное описание метода приведено в
[справочнике модуля CRUD](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/crud#reference_lua-crud_atomic_batch).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Выполнение перевода из Lua](#выполнение-перевода-из-lua)
* [Выполнение перевода из Go-приложения](#выполнение-перевода-из-go-приложения)
* [Просмотр метрик в TCM](#просмотр-метрик-в-tcm)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB 3.3.0 или новее;
* приложение Docker Compose;
* [Go](https://go.dev/dl/) 1.24 или новее — для запуска Go-приложения;
* исходные файлы примера `atomic_batch`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `atomic_batch` расположен в директории `examples/atomic_batch`.
> * Отдельный архив [atomic_batch.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fatomic_batch&filename=atomic_batch), скачанный из этого репозитория.

## Используемые файлы

В руководстве используются следующие файлы примера `atomic_batch`:

* `Makefile` — запуск и остановка стенда;
* `go/` — директория с Go-приложением:
  * `main.go` — приложение, вызывающее `crud.atomic_batch`;
  * `go.mod`, `go.sum` — файлы модуля Go с зависимостью `go-tarantool`;
* `tt/cluster/` — директория с файлами для запуска кластера Tarantool DB:
  * `config.yml` — конфигурация кластера;
  * `docker-compose.yml` — описание узлов кластера и применение миграции;
  * `migrations/scenario/001_wallet.lua` — миграция, создающая спейсы `accounts` и `transfers`;
* `tt/tools/` — директория с файлами для запуска etcd и TCM:
  * `docker-compose.yml` — описание узлов etcd и TCM;
  * `tcm.yml` — конфигурация [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081
* 8088

Перейдите в директорию примера `atomic_batch`:

```shell
cd examples/atomic_batch
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

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

* **Username**: `admin`
* **Password**: `secret`

В TCM откройте вкладку **Stateboard**. После применения настроек в наборе реплик `router-msk`
доступен узел `router-msk`.

В ходе запуска кластера выполняется миграция из файла `./tt/cluster/migrations/scenario/001_wallet.lua`.
В результате создаются два шардированных спейса:

* `accounts` — счета клиентов (ключ шардирования `client_id`);
* `transfers` — журнал переводов (ключ шардирования `client_id`).

## Выполнение перевода из Lua

Операцию `crud.atomic_batch` можно вызвать напрямую из Lua на роутере.

1. В TCM откройте вкладку **Stateboard**.
2. Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите
   на вкладку **Terminal**.
3. Во вкладке **Terminal** создайте два начальных счёта одного клиента:

   ```lua
   crud.insert('accounts', {1, 'main', nil, 1000})
   crud.insert('accounts', {1, 'savings', nil, 500})
   ```

4. Выполните атомарный перевод `100` со счёта `main` на счёт `savings` с записью в журнал:

   ```lua
   operations = {
       { type = 'update', space = 'accounts', key = {1, 'main'}, operations = {{'-', 'balance', 100}} },
       { type = 'update', space = 'accounts', key = {1, 'savings'}, operations = {{'+', 'balance', 100}} },
       { type = 'insert', space = 'transfers', tuple = {1001, 1, nil, 'main', 'savings', 100, os.time()}},
   }

   res, err = crud.atomic_batch(operations, { timeout = 5 })
   ```

   При успехе `err == nil`, а `res.data` содержит результаты выполненных операций.

   Проверьте балансы счетов:

   ```lua
   crud.get('accounts', {1, 'main'})
   ```

   Вывод:

   ```yaml
   ---
   - rows:
     - [1, 'main', 12477, 900]
     metadata: [{'name': 'client_id', 'type': 'unsigned'}, {'name': 'account_type', 'type': 'string'},
       {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'balance', 'type': 'unsigned'}]
   - null
   ...
   ```

   ```lua
   crud.get('accounts', {1, 'savings'})
   ```

   Вывод:

   ```yaml
   ---
   - rows:
     - [1, 'savings', 12477, 600]
     metadata: [{'name': 'client_id', 'type': 'unsigned'}, {'name': 'account_type', 'type': 'string'},
       {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'balance', 'type': 'unsigned'}]
   - null
   ...
   ```

5. Повторите тот же батч. Вставка перевода с тем же `txn_id` завершится ошибкой дубликата
   ключа, и весь батч откатится:

   ```lua
   res, err = crud.atomic_batch(operations, { timeout = 5 })
   ```

   Посмотрите текст ошибки:

   ```lua
   err.err
   ```

   Вывод:

   ```yaml
   ---
   - 'Operation #3 (insert on "transfers") failed: AtomicBatchError: Duplicate key exists
     in unique index "primary" in space "transfers" with old tuple - [1001, 1, 12477,
     "main", "savings", 100, 1793206721] and new tuple - [1001, 1, 12477, "main", "savings",
     100, 1793206729]'
   ...
   ```

   Теперь `err ~= nil`, а балансы счетов остаются прежними.

## Выполнение перевода из Go-приложения

То же самое можно сделать из Go-приложения. В примере используется коннектор
[`go-tarantool`](https://pkg.go.dev/github.com/tarantool/go-tarantool/v3) v3.
Пакет операций передаётся в вызов `crud.atomic_batch`:

```go
req := tarantool.NewCallRequest("crud.atomic_batch").
    Args([]any{operations, map[string]any{"timeout": 5}})
```

Откройте вторую вкладку терминала и перейдите в директорию `atomic_batch/go`:

```shell
cd examples/atomic_batch/go
```

Запустите Go-приложение:

```shell
go run main.go
```

Приложение очищает спейсы, создаёт начальные счета и выполняет тот же перевод.
Затем оно повторяет перевод — вставка падает на дубликате ключа, и весь батч
откатывается.

Вывод после окончания работы приложения выглядит так:

```shell
Balances before transfer: main=1000 savings=500
Transfer 1001 applied (3 rows returned)
Balances after transfer:  main=900 savings=600
Duplicate transfer 1001 rolled back: Operation #3 (insert on "transfers") failed: AtomicBatchError: Duplicate key exists in unique index "primary" in space "transfers" with old tuple - [1001, 1, 12477, "main", "savings", 100, 1793206788] and new tuple - [1001, 1, 12477, "main", "savings", 100, 1793206788]
Balances after rollback:  main=900 savings=600
```

Проверьте, что данные появились в спейсах. Для этого в TCM перейдите на вкладку
**Tuples** и выберите спейс `accounts` или `transfers`.

## Просмотр метрик в TCM

Метод `crud.atomic_batch` ведёт статистику, которая экспортируется в формате Prometheus:

* `tnt_crud_stats{operation="atomic_batch"}` — количество вызовов и время выполнения самого
  метода `atomic_batch` на роутере;
* `tnt_crud_atomic_batch_sub_ops` — статистика вложенных операций батча (`get`, `insert`,
  `update` и т.д.) с метками `operation` и `status`.

Метрики доступны на роутере по адресу `/metrics`.

Чтобы просмотреть метрики в TCM:

1. Перейдите на вкладку **Stateboard**.
2. Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите
   на вкладку **Metrics**.

Подробная информация о мониторинге в Tarantool DB приведена в разделе
[Мониторинг в Tarantool DB](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/monitoring).

## Остановка стенда

Для остановки стенда выполните следующую команду:

```shell
make stop
```
