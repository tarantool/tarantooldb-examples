# Использование Tarantool Cluster Federation

[Tarantool Cluster Federation](https://www.tarantool.io/en/clustersfederation/) позволяет выполнять репликацию шардированных данных между двумя независимыми кластерами Tarantool DB.

Для работы `Tarantool Cluster Federation` необходимы:

- Активный кластер Tarantool DB, откуда читаются реплицируемые данные
- Пассивный кластер Tarantool DB, куда пишутся реплицируемые данные
- etcd для фейловера кластеров Tarantool DB
- Репликатор `Tarantool Cluster Federation`, а именно бинарные файлы `tcf-destination` и `tcf-gateway`.

В примере будут продемострированы запуск кластеров Tarantool DB в `docker` в связке с `Tarantool Cluster Federation` и работа репликатора между кластерами.

## Запуск стенда

1. Запустим кластер etcd

``docker compose -f docker-compose-etcd.yml up -d``

Дожидаемся пока в логах (`docker compose -f docker-compose-etcd.yml logs etcd1`) не появится:

```txt
tarantool_cluster_federation-etcd1-1  | 2024-03-13 05:53:59.137345 I | etcdserver/api: enabled capabilities for version 3.4
```

2. Запустим кластера TarantoolDB

``docker compose -f docker-compose-clusters.yml up --force-recreate -d``

Дожидаемся поднятия кластеров [**А**](http://localhost:8080) и [**B**](http://localhost:9080). 

3. Запускаем репликатор

``docker compose -f docker-compose-replicator.yml up --force-recreate -d --build``

В результате запуска стенда запустятся два кластера Tarantool DB, кластер etcd из трех нод, сервис репликатора `Tarantool Cluster Federation`.


Файлы конфигурации `Tarantool Cluster Federation`:

- [Конфиг кластера A](./bootstrap-A/config.yml)
- [Конфиг кластера B](./bootstrap-A/config.yml)
- [Конфиг для репликации из A в B](./config_repl_AB.yaml)
- [Конфиг для репликации из B в A](./config_repl_BA.yaml)

## Пример репликации

В результате запуска стенда настроена репликация из [**кластера А**](http://localhost:8080) в [**кластер B**](http://localhost:9080).

Далее рассмотрим репликацию в действии:

1. Подключаемся к роутеру-А ``tt connect admin:cookie-A@localhost:3300``
2. Запустим вставку данных ``localhost:3300> box.schema.func.call('__start_data_stream')``
3. Через space-explorer можно увидеть как реплициируются данные из [A](http://localhost:8080/admin/space-explorer/hosts) в [B](http://localhost:8080/admin/space-explorer/hosts)

Отключить запись данных можно так ``box.schema.func.call('__stop_data_stream')``.

## Оключение стенда

Чтобы отключить стенд выполните следующие команды:

- ``docker compose -f docker-compose-replicator.yml down``
- ``docker compose -f docker-compose-clusters.yml down``
- ``docker compose -f docker-compose-etcd.yml down``
