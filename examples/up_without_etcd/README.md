# Запуск кластера без централизованной конфигурации

В этом руководстве показано, как развернуть кластер Tarantool DB без централизованной конфигурации с помощью
Docker Compose. Если использовать этот способ, веб-интерфейс [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) будет недоступен.

> [!NOTE]
> Развертывание Tarantool DB через Docker-образ используется в ознакомительных целях и
> рассчитано для использования в примерах документации и при тестировании.
> Для целевого развертывания используйте [Ansible Tarantool Enterprise](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_ate#install_guide-ate).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Используемые файлы](#используемые-файлы)
* [Миграции](#миграции)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `up_without_etcd`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `up_without_etcd` расположен в директории `examples/up_without_etcd`.
>  * Отдельный архив [up_without_etcd.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fup_without_etcd&filename=up_without_etcd), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию примера `up_without_etcd`:

```shell
cd examples/up_without_etcd
```

Запустите стенд:

```shell
docker compose up -d
```

Запущенный стенд состоит из:

- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- средств мониторинга (Prometheus, Grafana).

Начальную загрузку модуля [шардирования](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/sharding)
выполняет контейнер `init_host` с помощью утилиты [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt):

```shell
tt replicaset vshard bootstrap tarantool-router-msk:3301
```

## Используемые файлы

В руководстве используются следующие файлы примера `up_without_etcd`:

* `config.yml` — конфигурация и топология кластера;
* `docker-compose.yml` — описание узлов стенда;
* `grafana` — директория, содержащая настройки для ведения мониторинга;
* `prometheus` — директория, содержащая настройки Prometheus для сбора и передачи метрик в Grafana.

## Миграции

Создать необходимые объекты (спейсы и индексы) в этом примере можно двумя способами:

- через [коннектор](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/connectors#user_guide-connectors);
- с помощью утилиты [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt).

В этом примере для создания объектов используется tt CLI:

1. Подключитесь к узлу `storage-1-msk` — лидеру набора реплик `storage-1`:

   ```shell
   tt connect admin:secret-cluster-cookie@0.0.0.0:3303
   ```

2. Выполните на узле `storage-1-msk` следующий код:

    ```lua
    function migrate()
        local sharding_space = box.schema.space.create('_ddl_sharding_key', {
            format = {
                {name = 'space_name', type = 'string', is_nullable = false},
                {name = 'sharding_key', type = 'array', is_nullable = false},
            },
            if_not_exists = true,
        })

        sharding_space:create_index('space_name', {
            type = 'TREE',
            unique = true,
            parts = {{'space_name', 'string', is_nullable = false}},
            if_not_exists = true,
        })

        local s = box.schema.space.create('space_for_crud', {
            if_not_exists = true,
            format = {
                { name = 'id', type = 'integer' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'data', type = 'any' },
            },
        })

        s:create_index('pk', { parts = {'id'}, if_not_exists = true})
        s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        box.space._ddl_sharding_key:replace{s.name, {'id'}}
    end

    migrate()
    ```

   Этот код создаст спейс `space_for_crud`, с которым можно взаимодействовать через модуль [crud](https://www.tarantool.io/docs/tdb/ru/3_x/reference/roles#reference-roles-crud).

3. Выйдите из консоли:

   ```shell
   \quit
   ```

4. Теперь подключитесь к узлу `storage-2-msk` — лидеру набора реплик `storage-2`:

   ```shell
   tt connect admin:secret-cluster-cookie@0.0.0.0:3306
   ```

5. Выполните код миграций из п.2 на узле `storage-2-msk`, а затем выйдите из консоли.
6. Подключитесь к роутеру `router-msk-1`:

   ```shell
   tt connect admin:secret-cluster-cookie@0.0.0.0:3301
   ```

7. Добавьте запись в спейс:

   ```lua
   crud.replace('space_for_crud', {1, nil, 'Data'})
   ```

8. Теперь выполните чтение из спейса:

   ```lua
   crud.get('space_for_crud', {1})
   ```

## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
