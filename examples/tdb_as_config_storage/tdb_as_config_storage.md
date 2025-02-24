(admin_guide-tdb_as_config_storage)=
# Запуск кластера Tarantool DB как централизованного хранилища конфигураций

В этом руководстве показано, как развернуть кластер Tarantool DB в качестве централизованного хранилища
конфигураций.
Чтобы узлы в наборе реплик Tarantool действовали как хранилище конфигураций, используется технологическая роль [config.storage](configuration_reference-config_storage).
Узнать больше о хранилище конфигураций на базе Tarantool можно в документации [Tarantool](https://www.tarantool.io/ru/doc/latest/platform/configuration/configuration_etcd/#tarantool-based-storage).

Смотрите также: [](admin_guide-up_without_etcd).

```{admonition} Примечание
:class: note

Данный способ является вспомогательным и используется для тестирования и демонстрации в примерах документации.
Для целевого развертывания используйте [инсталлятор Ansible Tarantool Enterprise](admin_guide-deploy_ate).
```

Содержание:

* [](admin_guide-tdb_as_config_storage-prereq)
* [](admin_guide-tdb_as_config_storage-start_example)
* [](admin_guide-tdb_as_config_storage-files)
* [](admin_guide-tdb_as_config_storage-check)
* [](admin_guide-tdb_as_config_storage-stop_example)

(admin_guide-tdb_as_config_storage-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `tdb_as_config_storage`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `tdb_as_config_storage` расположен в таком архиве в директории `./doc/examples/tdb_as_config_storage/`.
    
  * Отдельный архив [tdb_as_config_storage.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/tdb_as_config_storage/tdb_as_config_storage.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-tdb_as_config_storage-start_example)=
## Запуск стенда

Перейдите в директорию примера `tdb_as_config_storage`:

```shell
cd ./doc/examples/tdb_as_config_storage/
```

Запустите кластер Tarantool DB:

```shell
make start
```

Команда запускает централизованное хранилище конфигурации -- вспомогательный кластер 
Tarantool DB, затем загружает в него конфигурацию и после запускает основной кластер Tarantool DB.

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- вспомогательного кластера Tarantool DB из 3 узлов;
- 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- средств мониторинга ([Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/)).

После запуска должны работать все контейнеры, кроме `load_config`.
Также после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 -- веб-интерфейс TCM;
* http://localhost:9090 -- веб-интерфейс Prometheus;
* http://localhost:3000 -- веб-интерфейс Grafana.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081). Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

(admin_guide-tdb_as_config_storage-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `tdb_as_config_storage`:

* `config_storage/` -- директория с файлами для запуска вспомогательного кластера Tarantool DB:
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;
* `main_cluster/` -- директория с файлами для запуска основного кластера Tarantool DB:
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  * `load-config.yml` -- команды загрузки конфигурации в централизованное хранилище;
* `tools/` -- директория с файлами для запуска TCM и средств мониторинга:
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/tooling/tcm/);
  * `grafana/` -- директория с настройками для ведения мониторинга;
  * `prometheus/` -- директория с настройками Prometheus для сбора и передачи метрик в Grafana;
  * `docker-compose.yml` -- описание узлов TCM и средств мониторинга;
* `Makefile` -- инструкции утилиты `make` для запуска и остановки всего стенда.

(admin_guide-tdb_as_config_storage-check)=
## Проверка работы кластера

1. В TCM перейдите на вкладку **Migrations** и добавьте файл `001.lua`:
    ```lua
    local helpers = require('tt-migrations.helpers')
    
    local function apply()
    
        local space_bands = box.schema.space.create('bands', {
            if_not_exists = true,
            format = {
                { name = 'id', type = 'integer' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'band_name', type = 'string' },
                { name = 'year', type = 'integer' },
            },
        })
        space_bands:create_index('primary_key', { parts = {'id'}, if_not_exists = true})
        space_bands:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    
        helpers.register_sharding_key(space_bands.name, {'id'})
    
        return true
    end
    
    return {
        apply = {
            scenario = apply,
        },
    }
    ```

2. Нажмите **Save**, чтобы сохранить изменения.
3. Нажмите **Apply**, чтобы применить миграции.
4. Перейдите на вкладку **Tuples**. Выберите в списке созданный спейс `bands`. Откроется новая вкладка с содержимым кортежей спейса `bands`.
5. Перейдите на вкладку **Stateboard** и нажмите на набор реплик `router-msk`. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
6. Во вкладке **Terminal**  добавьте новую запись:
   ```lua
   crud.insert_object('bands', {id = 4, band_name = 'The Beatles', year = 1960})
   ```

7. Теперь просмотрите содержимое таблицы:
   ```lua
   crud.select('bands')
   ```
8. Закройте окно роутера и перейдите на вкладку **Tuples**. Просмотрите еще раз содержимое
   спейса `bands` -- в списке появилась добавленная запись.

(admin_guide-tdb_as_config_storage-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
