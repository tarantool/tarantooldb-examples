# Запуск кластера через Docker Compose

В этом руководстве показано, как развернуть Tarantool DB с помощью Docker Compose.

> [!NOTE]
> Данный способ является вспомогательным и используется для тестирования и демонстрации в примерах документации.
> Для целевого развертывания используйте [инсталлятор Ansible Tarantool Enterprise](https://www.tarantool.io/docs/tdb/ru/1_x/admin_guide/deployment/deploy_ate#admin_guide-deploy_ate).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Используемые файлы](#используемые-файлы)
* [Конфигурация контейнера для узла Tarantool DB](#конфигурация-контейнера-для-узла-tarantool-db)
* [Контейнер user-host](#контейнер-user-host)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `up_with_docker_compose`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `up_with_docker_compose` расположен в директории `examples/up_with_docker_compose`.
>  * Отдельный архив [up_with_docker_compose.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fup_with_docker_compose&filename=up_with_docker_compose), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию примера `up_with_docker_compose`:

```shell
cd examples/up_with_docker_compose
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d --build
```

## Используемые файлы

В руководстве используются следующие файлы примера `up_with_docker_compose`:

* `docker-compose.yml` — описание узлов кластера;
* `bootstrap/topology.json` — топология кластера;
* `./tools/client/bootstrap.sh` — скрипт, [применяющий топологию кластера](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-bootstrap);
* `bootstrap/config.yml` — конфигурация кластера;
* `bootstrap/migrations/source` — директория, содержащая файлы с описанием миграций;
* `./tools/client/migrate.sh` — скрипт, [применяющий миграции](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-migrate).

## Конфигурация контейнера для узла Tarantool DB

Конфигурация контейнера для узла Tarantool DB задается в файле `docker-compose.yml`:

```yaml
tarantool-router-msk:
  image: tarantooldb:1x-latest
  networks:
    - tarantooldb_network
  ports:
    - "8081:8081"
    - "3301:3301"
  environment:
    - TARANTOOL_ADVERTISE_URI=tarantool-router-msk:3301
    - TARANTOOL_ALIAS=router-msk
```

Здесь:
* `image` — название Docker-образа, используемого для создания контейнера;
* `networks` — название подсети;
* `ports` — используемые порты;
* `environment` — переменные окружения для опций Tarantool и Cartridge:
  * `TARANTOOL_ADVERTISE_URI` — адрес и порт, на котором узел доступен в кластере;
  * `TARANTOOL_ALIAS` — название узла кластера.

  Полный список опций доступен в документации к модулю [cartridge.argparse](https://www.tarantool.io/ru/doc/2.11/book/cartridge/cartridge_api/modules/cartridge.argparse/) и в описании [Docker-образа](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB.

## Контейнер user-host

В файле `docker-compose.yml` есть специальный контейнер ``user-host``.
Он выступает в роли компьютера разработчика, с которого выполняются:

1. Настройка топологии кластера и первоначальный запуск (bootstrap) модуля шардирования [vshard](https://www.tarantool.io/ru/doc/2.11/book/admin/vshard_admin/).
2. Загрузка клиентского кода в кластер: описание спейсов и функций (миграции)

В примере конфигурация контейнера `user-host` выглядит так:

```yaml
user-host:
  image: tarantooldb:1x-latest
  networks:
    - tarantooldb_network
  environment:
    - TARANTOOLDB_TARGET_URI=tarantool-router-msk:8081
    - BOOTSTRAP_FAILOVER=1
    - TARANTOOLDB_BOOTSTRAP_TIMEOUT=60
  working_dir: /usr/share/tarantool/tarantooldb/tools/client/
  command: /bin/sh -c "./bootstrap.sh && ./health_check.sh && ./migrate.sh"
  depends_on:
    - tarantool-router-msk
    - tarantool-router-spb
    - tarantool-storage-1-msk
    - tarantool-storage-1-spb
    - tarantool-storage-2-msk
    - tarantool-storage-2-spb
    - etcd1
    - etcd2
    - etcd3
  volumes:
    - ./bootstrap/:/bootstrap/
```

Здесь:

* `image` — название Docker-образа, используемого для создания контейнера;
  Используется как источник скриптов `bootstrap.sh`, `health_check.sh` и `migrate.sh`.
  Предполагается, что в реальных условиях скрипты будут загружены на компьютер разработчика из [личного кабинета tarantool.io](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb).
* `networks` — название подсети;
* `environment` — переменные окружения:
  * `TARANTOOLDB_TARGET_URI` — адрес, по которому доступны API-команды кластера.
    Используется скриптами `bootstrap.sh`, `health_check.sh` и `migrate.sh`;
  * `BOOTSTRAP_FAILOVER` — первоначальный запуск механизма восстановления после сбоев (failover);
  * `TARANTOOLDB_BOOTSTRAP_TIMEOUT` — время ожидания первоначального запуска (bootstrap);
* `working_dir` — директория, в которой лежат скрипты;
* `command` — запуск скриптов `bootstrap.sh`, `health_check.sh` и `migrate.sh`;
* `depends_on` — секция определяет, что контейнер `user-host` запускается только после запуска всех остальных узлов кластера;
* `volumes` — передача в контейнер директории с настройками кластера и пользовательской логикой, чтобы они стали доступны для скриптов.

## Остановка стенда

Остановить кластер можно так:

```shell
docker compose down
```
