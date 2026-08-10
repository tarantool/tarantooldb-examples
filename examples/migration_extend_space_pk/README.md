# Изменение первичного индекса для существующего спейса

Пример доступен с версии Tarantool DB 3.2.0.

В этом руководстве рассказано, как в Tarantool DB изменить первичный индекс существующего спейса без потери данных.
Данные при этом копируются в новый одноименный спейс, а имя старого спейса обновляется.

Для работы с данными используется модуль [CRUD](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/crud).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Схема данных](#схема-данных)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Загрузка данных](#загрузка-данных)
* [Проверка загруженных данных](#проверка-загруженных-данных)
* [Изменение схемы данных и индекса](#изменение-схемы-данных-и-индекса)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt);
* исходные файлы примера `migration_extend_space_pk`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `migration_extend_space_pk` расположен в директории `examples/migration_extend_space_pk`.
>  * Отдельный архив [migration_extend_space_pk.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fmigration_extend_space_pk&filename=migration_extend_space_pk), скачанный из этого репозитория.

## Схема данных

В качестве примера приведен спейс `bands`:
* `id` — идентификатор группы, первичный ключ, [ключ шардирования](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/sharding);
* `bucket_id` — идентификатор сегмента, используется модулем [vshard](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/sharding);
* `band_name` — название группы;
* `year` — год основания группы.

Для работы с данными в примере используются [методы модуля CRUD](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/crud).

## Используемые файлы

В руководстве используются следующие файлы примера `migration_extend_space_pk`:

- `cluster/` — директория c файлами для запуска кластера Tarantool DB:
  - `config.yml` — конфигурация и топология кластера;
  - `docker-compose.yml` — описание узлов кластера Tarantool DB;
  - `examples_data_bands.csv` — тестовый набор данных;
  - `migrations/scenario/` и `migration_next/` — директории, содержащие файлы с описанием миграций;
- `tools/` — директория с файлами для запуска кластера etcd и TCM:
  - `docker-compose.yml` — описание узлов кластера etcd;
  - `tcm.yml` — конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081

Перейдите в директорию примера `migration_extend_space_pk`:

```shell
cd examples/migration_extend_space_pk
```

Запустите стенд:

```shell
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик узел `storage-1-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** введите следующую команду:

```lua
box.space
```

Проверьте, что в выводе есть спейс `bands`, он создается при запуске кластера.

## Загрузка данных

Исходный код миграции приведен в файле `001_create_space_bands.lua` в директории `./cluster/migrations/scenario/`
примера `migration_extend_space_pk`.

Загрузить тестовые данные в спейс можно с помощью утилиты tt CLI:

```shell
tt crud import \
	admin:secret-cluster-cookie@localhost:3301 \
	examples_data_bands.csv:bands \
	--header
```

## Проверка загруженных данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера. Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** — через TCM. Для этого:

1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Чтобы проверить загруженные данные, выполните в TCM во вкладке **Terminal** несколько базовых CRUD-операций в спейсе `bands`:

```shell
tarantool-router-msk:3301> crud.select('bands', nil, { first = 5 })
---
- metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'band_name', 'type': 'string'}, {'name': 'year', 'type': 'integer'}]
  rows:
  - [1, 12477, 'The Beatles', 1960]
  - [2, 21401, 'The Rolling Stones', 1962]
  - [3, 11804, 'The Who', 1964]
  - [4, 28161, 'Led Zeppelin', 1968]
  - [5, 1172, 'Deep Purple', 1968]
- null
...

tarantool-router-msk:3301> crud.select('bands', {{'==', 'band_name', 'Metallica'}})
---
- metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'band_name', 'type': 'string'}, {'name': 'year', 'type': 'integer'}]
  rows:
  - [15, 20901, 'Metallica', 1981]
- null
...

tarantool-router-msk:3301> crud.insert('bands', {35, box.NULL, 'My Garage Band', 2026})
---
- rows:
  - [35, 9835, 'My Garage Band', 2026]
  metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'band_name', 'type': 'string'}, {'name': 'year', 'type': 'integer'}]
- null
...

tarantool-router-msk:3301> crud.get('bands', 35)
---
- rows:
  - [35, 9835, 'My Garage Band', 2026]
  metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'band_name', 'type': 'string'}, {'name': 'year', 'type': 'integer'}]
- null
...

tarantool-router-msk:3301> crud.delete('bands', 35)
---
- rows:
  - [35, 9835, 'My Garage Band', 2026]
  metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'band_name', 'type': 'string'}, {'name': 'year', 'type': 'integer'}]
- null
...
```

## Изменение схемы данных и индекса

Предположим, что теперь нужно изменить схему данных — добавить в спейс `bands` новое поле `sub_id (integer)`.
Это поле также должно стать частью первичного ключа. Значение по умолчанию для этого поля должно совпадать со значением поля `id`.

Код миграции приведен в файле `./cluster/migration_next/002_extend_bands_pk.lua` примера `migration_extend_space_pk`.
Файл миграции содержит подробные комментарии, которые описывают процесс изменения формата спейса, индексов, синхронизации спейсов,
в также копирования данных.

### Выполнение миграции

> [!NOTE]
> * Миграция в этом примере реализована путем создания нового спейса и копирования данных в него.
>   Для спейсов на движке memtx это приводит к удвоенному потреблению памяти этим спейсом на время миграции.
> * При работе в режиме MVCC во время миграции может увеличиваться количество транзакций, которые завершаются конфликтом.
>   Это связано с тем, что миграция постоянно читает данные из оригинального спейса.
> * Наличие триггера `on_replace` повышает нагрузку на кластер от операций записи на время миграции — вместо одной записи
>   выполняются две, в старый и новый спейсы соответственно.

Выполнить миграцию можно с помощью утилиты [tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/). Для этого:

1. В терминале поместите файл `002_extend_bands_pk.lua` из папки `migration_next` с кодом миграций в папку `./cluster/migrations/scenario/`:

   ```shell
   cd cluster
   cp migration_next/002_extend_bands_pk.lua migrations/scenario/
   ```

2. Загрузите миграции в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish):

   ```shell
   tt migrations publish http://admin:secret-cluster-cookie@localhost:2379/tdb/ migrations
   ```

   Узнать больше о командах `tt migrations` можно в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/migrations/).

3. Примените миграции:

   ```shell
   docker compose exec tarantool-router-msk tt migrations apply http://etcd1:2379/tdb --tarantool-username=admin --tarantool-password=secret-cluster-cookie
   cd ..
   ```

   Миграция выполняет следующие действия:
   - создает спейс `bands_new` с новым форматом и новыми индексами;
   - создает для спейса `bands` триггер `on_replace`, который дублирует все добавления, удаления и изменения кортежей в новый спейс;
   - копирует все данные из старого спейса в новый, игнорируя дубли.
   - переименовывает старый спейс в `bands_old`, а новый — в `bands`;
   - удаляет триггер.

   В случае успеха вывод будет выглядеть так:

   ```shell
   • router-msk:
   •     001_create_space_bands.lua: skipped, already applied
   •     002_extend_bands_pk.lua: successfully applied
   • router-spb:
   •     001_create_space_bands.lua: skipped, already applied
   •     002_extend_bands_pk.lua: successfully applied
   • storage-1:
   •     001_create_space_bands.lua: skipped, already applied
   •     002_extend_bands_pk.lua: successfully applied
   • storage-2:
   •     001_create_space_bands.lua: skipped, already applied
   •     002_extend_bands_pk.lua: successfully applied
   ```

    На больших спейсах копирование данных может выполняться очень долго.
    Например для спейса из этого примера, заполненного
    до размера в 32ГБ, копирование занимает примерно 3.5 часа на memtx и 4.5 часа на vinyl. Для удобства миграция
    добавляет на каждое хрнилище функцию, позволяющую отслеживать процесс копирования данных:
    `box.func.extend_bands_pk_migration_progress:call()`.

    Если во время выполнения миграции происходит перезапуск узла, то после перезапуска миграция будет запущена заново.
    Все кортежи будут прочитаны из старого спейса повторно, но при этом дубликатов уже скопированных спейсов в новом спейсе
    не появится. Триггер `on_replace` также будет работать и дублировать все изменения из старого спейса в новый.

4. Проверьте, что миграция прошла успешно.
   Для этого в TCM во вкладке **Terminal** выполните следующие вызовы:

    ```shell
    tarantool-router-msk:3301> crud.select('bands', nil, { first = 5 })
    ---
    - metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'sub_id', 'type': 'integer'},
        {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'band_name', 'type': 'string'},
        {'name': 'year', 'type': 'integer'}]
      rows:
        - [1, 1, 12477, 'The Beatles', 1960]
        - [2, 2, 21401, 'The Rolling Stones', 1962]
        - [3, 3, 11804, 'The Who', 1964]
        - [4, 4, 28161, 'Led Zeppelin', 1968]
        - [5, 5, 1172, 'Deep Purple', 1968]
    - null
    ...

    tarantool-router-msk:3301> crud.get('bands', 11)
    ---
    - null
    - line: 165
      class_name: GetError
      err: 'Failed to get: Invalid key part count in an exact match (expected 2, got 1)'
      file: /app/tarantooldb/.rocks/share/tarantool/crud/get.lua
      str: 'GetError: Failed to get: Invalid key part count in an exact match (expected 2, got 1)'
    ...

    tarantool-router-msk:3301> crud.get('bands', {11, 11})
    ---
    - rows:
        - [11, 11, 2652, 'Queen', 1970]
      metadata: [{'name': 'id', 'type': 'integer'}, {'name': 'sub_id', 'type': 'integer'},
        {'name': 'bucket_id', 'type': 'unsigned'}, {'name': 'band_name', 'type': 'string'},
        {'name': 'year', 'type': 'integer'}]
    - null
    ...
    ```

   В ответах можно увидеть новое поле `sub_id` и убедиться, что оно является частью первичного ключа.

5. Удалите спейс `bands_old`. Для этого повторите пункты 1 — 3 для миграции `003_drop_bands_old.lua`.

## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
