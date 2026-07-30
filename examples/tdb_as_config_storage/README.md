# Запуск кластера Tarantool DB как централизованного хранилища конфигураций

В этом руководстве показано, как развернуть кластер Tarantool DB в качестве централизованного хранилища
конфигураций.
Чтобы узлы в наборе реплик Tarantool действовали как хранилище конфигураций, используется технологическая роль [config.storage](https://www.tarantool.io/docs/tdb/ru/3_x/reference/configuration_reference#configuration_reference-config_storage).
Узнать больше о хранилище конфигураций на базе Tarantool можно в документации [Tarantool](https://www.tarantool.io/ru/doc/latest/platform/configuration/configuration_etcd/#tarantool-based-storage).

Смотрите также: [Запуск кластера без централизованной конфигурации](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker/deploy_without_etcd).

> [!NOTE]
> Развертывание Tarantool DB через Docker-образ используется в ознакомительных целях и
> рассчитано для использования в примерах документации и при тестировании.
> Для целевого развертывания используйте [Ansible Tarantool Enterprise](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_ate#install_guide-ate).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Используемые файлы](#используемые-файлы)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `tdb_as_config_storage`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `tdb_as_config_storage` расположен в директории `examples/tdb_as_config_storage`.
>  * Отдельный архив [tdb_as_config_storage.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Ftdb_as_config_storage&filename=tdb_as_config_storage), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию примера `tdb_as_config_storage`:

```shell
cd examples/tdb_as_config_storage
```

Запустите кластер Tarantool DB:

```shell
make start
```

Команда запускает централизованное хранилище конфигурации — вспомогательный кластер
Tarantool DB, затем загружает в него конфигурацию и после запускает основной кластер Tarantool DB.

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- вспомогательного кластера Tarantool DB из 3 узлов;
- 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
- средств мониторинга ([Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/)).

После запуска должны работать все контейнеры, кроме `load_config`.
Также после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 — веб-интерфейс TCM;
* http://localhost:9090 — веб-интерфейс Prometheus;
* http://localhost:3000 — веб-интерфейс Grafana.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081). Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

## Используемые файлы

В руководстве используются следующие файлы примера `tdb_as_config_storage`:

* `config_storage/` — директория с файлами для запуска вспомогательного кластера Tarantool DB:
  * `config.yml` — конфигурация и топология кластера;
  * `docker-compose.yml` — описание узлов кластера Tarantool DB;
* `main_cluster/` — директория с файлами для запуска основного кластера Tarantool DB:
  * `config.yml` — конфигурация и топология кластера;
  * `docker-compose.yml` — описание узлов кластера Tarantool DB;
  * `migrations/scenario/` — директория, содержащая файлы с описанием миграций;
* `tools/` — директория с файлами для запуска TCM и средств мониторинга:
  * `tcm.yml` — конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/tooling/tcm/);
  * `grafana/` — директория с настройками для ведения мониторинга;
  * `prometheus/` — директория с настройками Prometheus для сбора и передачи метрик в Grafana;
  * `docker-compose.yml` — описание узлов TCM и средств мониторинга;
* `Makefile` — инструкции утилиты `make` для запуска и остановки всего стенда.

## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
