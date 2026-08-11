# Запуск кластера из одного узла через Docker Compose

В этом руководстве показано, как развернуть кластер Tarantool DB из одного узла с помощью Docker Compose.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Остановка кластера](#остановка-кластера)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `all_in_one`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `all_in_one` расположен в директории `examples/all_in_one`.
>  * Отдельный архив [all_in_one.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fall_in_one&filename=all_in_one), скачанный из этого репозитория.

## Используемые файлы

В руководстве используются следующие файлы примера `all_in_one`:

* `docker-compose.yml` — описание узлов кластера. Узнать больше: [Запуск кластера через Docker Compose](https://www.tarantool.io/docs/tdb/ru/1_x/admin_guide/deployment/deploy_docker_compose).
* `bootstrap/topology.json` — топология кластера;
* `./tools/client/bootstrap.sh` — скрипт, [применяющий топологию кластера](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-bootstrap);
* `bootstrap/config.yml` — конфигурация кластера;
* `bootstrap/migrations/source` — директория, содержащая файлы с описанием миграций;
* `./tools/client/migrate.sh` — скрипт, [применяющий миграции](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-migrate).

## Запуск стенда

Перейдите в директорию примера `all_in_one`:

```shell
cd examples/all_in_one
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d --build
```

## Остановка кластера

Остановить кластер можно так:

```shell
docker compose down
```
