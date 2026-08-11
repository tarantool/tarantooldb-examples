# Запуск кластера в CI

При работе в CI возникает необходимость запускать Docker в Docker или другой виртуальной среде.
В примере описано, как при таком подходе решить возможную проблему с передачей локальной папки в Docker-образ.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Контейнер user-host](#контейнер-user-host)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `up_in_ci`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `up_in_ci` расположен в директории `examples/up_in_ci`.
>  * Отдельный архив [up_in_ci.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fup_in_ci&filename=up_in_ci), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию `up_in_ci`:

```shell
cd examples/up_in_ci
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d --build
```

## Контейнер user-host

Контейнер `user-host` указывается в файле `docker-compose.yml`.
Подробное описание контейнера приводится в руководстве по запуску кластера через Docker Compose в разделе [Контейнер user-host](../deploy_docker_compose/README.md).

В примере конфигурация контейнера `user-host` выглядит так:

```yaml
user-host:
  build:
    context: .
    dockerfile: bootstrap.Dockerfile
  networks:
    - tarantooldb_network
  environment:
    - TARANTOOLDB_TARGET_URI=tarantool-router:8081
  working_dir: /bootstrap/
  command: sh -c "./bootstrap.sh && ./health_check.sh && ./migrate.sh"
  depends_on:
    - tarantool-router
    - tarantool-storage1
    - tarantool-storage2
    - tarantool-storage3
    - tarantool-storage4
```

Здесь:

* `build.context.dockerfile` — сборка отдельного контейнера, в который копируются папка `bootstrap` и пользовательские скрипты;
* `networks` — название подсети;
* `environment` — задание переменных окружения:
  * `TARANTOOLDB_TARGET_URI` — адрес, по которому доступны API-команды кластера.
    Используется скриптами [bootstrap.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-bootstrap), [health_check.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-health_check) и [migrate.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-migrate);
* `working_dir` — директория, в которой лежат файл конфигурации и файлы миграций;
* `command` — запуск скриптов [bootstrap.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-bootstrap), [health_check.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-health_check) и [migrate.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-migrate);
* `depends_on` — секция определяет, что контейнер `user-host` запускается только после запуска всех остальных узлов кластера;
* `volumes` — передача в контейнер директории с настройками кластера и пользовательской логикой, чтобы они стали доступны для скриптов.

## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
