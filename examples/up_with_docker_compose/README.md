# Конфигурация и запуск кластера через docker-compose

В данном примере показан запуск кластера TarantoolDB с помощью docker.

Для запуска кластера из директории ``up_with_docker_compose`` выполните ``docker compose up`` или ``docker-compose up``.

## Файлы конфигурации

- Инстансы кластера описаны в [docker-compose.yml](./docker-compose.yml).
- Топология кластера описана в [bootstrap/edit-topology.json](./bootstrap/edit-topology.json)
- Для применения топологии кластера используется скрипт [bootstrap-app.sh](../../../bootstrap-app.sh)
- Конфиг для cartridge описан в [bootstrap/config.yml](./bootstrap/config.yml)
- Миграции описываются в [bootstrap/migrations/source](./bootstrap/migrations/source/)

## Пример конфигурации контейнера для инстанса tarantool

```yaml
tarantool-router:
  image: tarantooldb:latest
  networks:
    - tdb
  ports:
    - "8080:8081"
    - "3300:3301"
  environment:
    - TARANTOOL_LISTEN=0.0.0.0:3301
    - TARANTOOL_ADVERTISE_URI=tarantool-router:3301
```

В ``environment`` перечиляются опции через переменные окружения для ``tarantool`` и ``cartridge``. Список опций доступен в документации к модулю [cartridge.argparse](https://www.tarantool.io/ru/doc/latest/book/cartridge/cartridge_api/modules/cartridge.argparse/).

## Контейнер для старта кластера

В [``docker-compose.yml``](./docker-compose.yml) есть специальный контейнер ``tarantool-db-init`` для bootstrap-а кластера(конфигурации модуля [vshard](https://www.tarantool.io/ru/doc/latest/book/admin/vshard_admin/) и ролей cartridge).

```yaml
tarantool-db-init:
  image: tarantooldb:latest
  networks:
   - tdb
  command: |
    /bin/bash -c 'sleep 1; TARANTOOL_TARGET_URI=tarantool-router:8081 /usr/share/tarantool/tarantooldb/bootstrap-app.sh'
  depends_on:
    - tarantool-router
    - tarantool-storage1
    - tarantool-storage2
    - tarantool-storage3
    - tarantool-storage4
  working_dir: /bootstrap
  volumes:
    - ./bootstrap/:/bootstrap/
```

За счет опции ``depends_on`` контейнер запускается только после подъема всех инстансов кластера. Вся пользовательская настройка кластера должна находиться в директории [bootstrap](./bootstrap). В контейнере в опциях ``working_dir`` и ``volumes`` используется данная директория.

Данный контейнер хранит пользовательскую логику для TarantoolDB и конфигурирует кластер через скрипт [bootstrap-app.sh](../../../bootstrap-app.sh).

# Скрипт [bootstrap-app.sh](../../../bootstrap-app.sh)

Скрипт [bootstrap-app.sh](../../../bootstrap-app.sh) выполняет следующие действия:
1. Создает топологию кластера cartridge черз [GraphQL API](https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_admin/#changing-the-cluster-topology)(mutation "editTopology"), используя файл с топологией [bootstrap/edit-topology.json](./bootstrap/edit-topology.json).
2. Создает конфиг кластера из [config.yml](./bootstrap/config.yml) и [миграций](./bootstrap/migrations/source/).
3. Грузит получившийся конфиг в кластер.
4. Запускает миграции.

