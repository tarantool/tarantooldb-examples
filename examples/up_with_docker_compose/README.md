# Конфигурация и запуск кластера через docker compose

Для этого примера понадобятся:
* Docker-образ TarantoolDB ([установить](../../INSTALL.md))
* Docker compose

Для запуска кластера из директории ``up_with_docker_compose`` выполните:
```shell
docker compose up -d --build 
```

## Используемые файлы

- Узлы кластера описаны в [docker-compose.yml](./docker-compose.yml)
- Топология кластера описана в [bootstrap/topology.json](./bootstrap/topology.json)
- Для применения топологии кластера используется скрипт [/client/utils/bootstrap.sh](../../../client/utils/bootstrap.md)
- Конфигурация кластера описана в [bootstrap/config.yml](./bootstrap/config.yml)
- Миграции описываются в [bootstrap/migrations/source](./bootstrap/migrations/source/)
- Для применения миграций используется скрипт [/client/utils/migrate.sh](../../../client/utils/migrate.md)

## Пример конфигурации контейнера для узла TarantoolDB

```yaml
tarantool-router:
  image: tarantooldb:latest
  networks:
    - tarantooldb_network
  ports:
    - "8080:8081"
    - "3300:3301"
  environment:
    - TARANTOOL_ADVERTISE_URI=tarantool-router:3301
```

В ``environment`` перечиляются опции через переменные окружения для ``tarantool`` и ``cartridge``. Список опций
доступен в документации к модулю
[cartridge.argparse](https://www.tarantool.io/ru/doc/latest/book/cartridge/cartridge_api/modules/cartridge.argparse/),
а также в описании [докер-образа](doc/DOCKERFILE.md).

## Контейнер `user-host`

В [``docker-compose.yml``](./docker-compose.yml) есть специальный контейнер ``user-host``. Он выполняет роль компьютера
разработчика с которого выполняются:
1. Настройка топологии кластера и первоначальный запуск (bootstrap) модуля шардирования
   [vshard](https://www.tarantool.io/ru/doc/latest/book/admin/vshard_admin/).
   > **Примечание**
   >
   > Данный способ используется только для демонстрации в примерах документации. В нормальных условиях это выполняет
   > инсталлятор (Ansible Tarantool Enterprise).
2. Загрузка клиентского кода в кластер: описание спкейсов, функций и т. д. (миграции)

```yaml
user-host:
  image: tarantooldb:latest
  networks:
    - tarantooldb_network
  environment:
    - TARANTOOLDB_TARGET_URI=tarantool-router:8081
  working_dir: /usr/share/tarantool/tarantooldb/client/utils/
  command: /bin/bash -c "./bootstrap.sh && ./migrate.sh"
  depends_on:
    - tarantool-router
    - tarantool-storage1
    - tarantool-storage2
    - tarantool-storage3
    - tarantool-storage4
  volumes:
    - ./bootstrap/:/bootstrap/
```

Рассмотрим его состав более подробно:
* `image: tarantooldb:latest` - образ используется только как источник скриптов `bootstrap.sh` и `migrate.sh`
  ([подробнее](../../../client/utils/README.md)) Предполагается, что в реальных условиях данные скрипты будут загружены на компьютер разработчика из 
  [клиентской зоны](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb).
* `environment` - в данной секции мы устанавливаем переменные окружения, в частности `TARANTOOLDB_TARGET_URI`, которая
  используется скриптами `bootstrap.sh` и `migrate.sh` для определения адреса, по которому доступны API-команды
  кластера.
* `working_dir` - указывает на папку, в которой лежат скрипты
* `depends_on` - данный контейнер запускается только после запуска всех остальных узлов кластера
* `volumes` - здесь мы пробрасываем в контейнер директорию с настройками кластера и пользовательской логикой, чтобы они стали доступны для скриптов.

## Останов стенда
Останов стенда производится командой:
```shell
docker compose down
```
