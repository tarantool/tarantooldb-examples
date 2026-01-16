(admin_guide-up_without_etcd)=
# Запуск кластера без централизованной конфигурации

В этом руководстве показано, как развернуть кластер Tarantool DB без централизованной конфигурации с помощью
Docker Compose. Если использовать этот способ, веб-интерфейс [Tarantool Cluster Manager](getting_started-tcm) будет недоступен.

```{admonition} Примечание
:class: note

Запуск с помощью Docker Compose является вспомогательным и используется для тестирования и демонстрации
в примерах документации. Для целевого развертывания используйте [инсталлятор Ansible Tarantool Enterprise](admin_guide-deploy_ate).
```

Содержание:

* [](admin_guide-up_without_etcd-prereq)
* [](admin_guide-up_without_etcd-start_example)
* [](admin_guide-up_without_etcd-files)
* [](admin_guide-up_without_etcd-migrations)
* [](admin_guide-up_without_etcd-stop_example)

(admin_guide-up_without_etcd-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `up_without_etcd`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `up_without_etcd` расположен в таком архиве в директории `./doc/examples/up_without_etcd/`.
    
  * Отдельный архив [up_without_etcd.tar.gz](https://tarantool.io/ru/tarantooldb/doc/2.x/examples/up_without_etcd/up_without_etcd.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-up_without_etcd-start_example)=
## Запуск стенда

Перейдите в директорию примера `up_without_etcd`:

```shell
cd ./doc/examples/up_without_etcd/
```

Запустите стенд:

```shell
docker compose up -d
```

Запущенный стенд состоит из:

- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- средств мониторинга (Prometheus, Grafana).

(admin_guide-up_without_etcd-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `up_without_etcd`:

* `config.yml` -- конфигурация и топология кластера;
* `docker-compose.yml` -- описание узлов стенда;
* `grafana` -- директория, содержащая настройки для ведения мониторинга;
* `prometheus` -- директория, содержащая настройки Prometheus для сбора и передачи метрик в Grafana.

(admin_guide-up_without_etcd-migrations)=
## Миграции

Создать необходимые объекты (спейсы и индексы) в этом примере можно двумя способами:

- через [коннектор](user_guide-connectors);
- с помощью утилиты [tt CLI](install-install_tt).

В этом примере для создания объектов используется tt CLI:

1. Подключитесь к узлу `storage-1-msk` -- лидеру набора реплик `storage-1`:

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

   Этот код создаст спейс `space_for_crud`, с которым можно взаимодействовать через модуль [crud](reference-roles-crud).

3. Выйдите из консоли:

   ```shell
   \quit
   ```

4. Теперь подключитесь к узлу `storage-2-msk` -- лидеру набора реплик `storage-2`:

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

(admin_guide-up_without_etcd-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
