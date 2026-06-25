# Изменение схемы данных с помощью space:format()

В этом руководстве рассказано, как в Tarantool DB изменить первичный индекс существующего спейса без потери данных
путем копирования данных в новый спейс и последующего переименования.

Для работы используются модуль [CRUD](https://github.com/tarantool/crud).

Руководство включает следующие шаги:

* [](user_guide-extend_pk-prereq)
* [](user_guide-extend_pk-schema)
* [](user_guide-extend_pk-files)
* [](user_guide-extend_pk-start_example)
* [](user_guide-extend_pk-load_data)
* [](user_guide-extend_pk-check_data)
* [](user_guide-extend_pk-change_schema)
* [](user_guide-extend_pk-stop_example)

(user_guide-extend_pk-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* исходные файлы примера `migration_extend_space_pk`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `migration_extend_space_pk` расположен в таком архиве в директории `./doc/examples/migration_extend_space_pk/`.

  * Отдельный архив [migration_extend_space_pk.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/migrations/migration_extend_space_pk.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-extend_pk-schema)=
## Схема данных

В качестве примера приведен спейс `bands`:
* `id` идентификатор группы, первичный ключ, [ключ шардирования](admin_guide-sharding).
* `bucket_id` идентификатор бакета, используется модулем [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/).
* `band_name` название группы.
* `year` год основания группы.

Для работы с данными в примере используются методы модуля CRUD.

(user_guide-extend_pk-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `migrations`:

- `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  - `config.yml` -- конфигурация и топология кластера;
  - `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  - `migrations/scenario/` и `migration_next/` -- директории, содержащие файлы с описанием миграций;
- `tools/` -- директория с файлами для запуска кластера etcd и TCM:
  - `docker-compose.yml` -- описание узлов кластера etcd;
  - `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

(user_guide-extend_pk-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301--3308
* 8081

Перейдите в директорию примера `migration_extend_space_pk`:

```
cd ./doc/examples/migration_extend_space_pk/
```

Запустите стенд:

```
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

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

(user_guide-extend_pk-load_data)=
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

(user_guide-extend_pk-check_data)=
## Проверка загруженных данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера. Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:

1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Чтобы проверить загруженные данные, выполните в TCM во вкладке **Terminal** несколько базовых операций в спейсе `bands`, используя модуль CRUD:

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

(user_guide-extend_pk-change_schema)=
## Изменение схемы данных и индекса

Предположим, что теперь нужно изменить схему данных, добавив в нее новое поле `sub_id (integer)` в спейс `bands`.
Это поле также должно стать частью первичного ключа. Значение по умолчанию должно совпадать со значением поля `id`.

Код миграции приведен в файле `./cluster/migration_next/002_extend_bands_pk.lua` примера `migration_extend_space_pk`.
Файл миграции содержит подробные комментарии, описывающие процесс изменения формата, индексов, синхронизации спейсов
и копирования данных.

(user_guide-extend_pk-change_schema-migrations)=
### Выполнение миграции

  ```{admonition} Примечание
  :class: note

  * Миграция в данном примере реализована через создание нового спейса и копирования данных в него.
    Для спейсов на движке memtx это приводит к удвоенному потреблению памяти этим спейсом на время миграции.
  * При работе в режиме MVCC во время миграции может повышаться количество транзакций, завершающихся конфликтом
    т.к. миграция постоянно читает данные из оригинального спейса.
  * Наличие on_replace триггера повышает нагрузку на кластер от операций записи (вместо одной записи
    выполняется две, в старый и новый спейсы) на время миграции.
  ```

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

   Миграция выполнит следующие действия:
   - Создаст спейс `bands_new` с новым форматом и новыми индексами.
   - Создаст на спейсе `bands` on_replace триггер, дублирующий все добавления/удаления/изменения таплов в новый спейс.
   - Скопирует все данные из старого спейса в новый, игнорируя дубли.
   - Переименует старый спейс в `bands_old`, а новый в `bands`.
   - Удалит триггер.

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

    На больших спейсах копирование данных может выполняться очень долго (На спейсе из этого примера, заполненном
    до размера в 32ГБ, этот процесс занимает примерно 3.5 часа на memtx и 4.5 часа на vinyl). Для удобства миграция
    добавляет на каждый сторадж функцию, позволяющую отслеживать процесс копирования данных:
    `box.func.extend_bands_pk_migration_progress:call()`.

    Если во время выполнения миграции произойдет перезапуск узла, то после перезапуска миграция будет запущена заново.
    Все таплы будут прочитаны из старого спейса повторно, но при этом дубликатов уже скопированных таплов в новом спейсе
    не появится. On_replace триггер также будет работать и дублировать все изменения из старого спейса в новый.

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

   В ответах можно увидеть новое поле sub_id и убедиться, что оно является частью первичного ключа.

5. Удалите спейс `bands_old`. Для этого повторите пункты 1 — 3 для миграции `003_drop_bands_old.lua`.

(user_guide-extend_pk-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
