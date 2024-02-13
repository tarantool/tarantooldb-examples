# Конфигурация и запуск кластера из одного узла через docker compose

Для этого примера понадобятся:
* Docker-образ Tarantool DB ([установить](../../INSTALL.md))
* Docker compose

Для запуска кластера из директории ``all_in_one`` выполните:
```shell
docker compose up -d --build 
```

## Используемые файлы

- Узел кластера описан в [docker-compose.yml](./docker-compose.yml), [подробнее](../up_with_docker_compose/README.md)
  об описании сервисов
- Топология кластера описана в [bootstrap/topology.json](./bootstrap/topology.json)
- Для применения топологии кластера используется скрипт [/client/utils/bootstrap.sh](../../../client/utils/bootstrap.md)
- Конфигурация кластера описана в [bootstrap/config.yml](./bootstrap/config.yml)
- Миграции описываются в [bootstrap/migrations/source](./bootstrap/migrations/source/)
- Для применения миграций используется скрипт [/client/utils/migrate.sh](../../../client/utils/migrate.md)

## Останов стенда
Останов стенда производится командой:
```shell
docker compose down
```
