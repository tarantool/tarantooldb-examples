# Запуск кластеров Tarantool DataBase с TCF и настройка репликатора

В этом руководстве показано, как запустить два независимых кластера Tarantool DB в Docker в связке с [Tarantool Clusters Federation](https://www.tarantool.io/ru/clustersfederation/doc/latest/) (TCF)
и настроить работу репликатора между кластерами.

> [!NOTE]
> TCF поддерживает репликацию шардированных данных в спейсах с асинхронным режимом репликации.
> Это означает, что передача [словарей](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/dictionary) через TCF недоступна.

Для работы Tarantool Clusters Federation необходимы:

* активный кластер Tarantool DB — с него идет чтение реплицируемых данных;
* пассивный кластер Tarantool DB — на него идет запись реплицируемых данных;
* [etcd](https://etcd.io/) — для восстановления после сбоя (failover) кластеров Tarantool DB;
* репликатор Tarantool Clusters Federation — бинарные файлы `tcf-destination` и `tcf-gateway`.
  Инструкция о том, как получить эти файлы, приведена ниже, в секции [Запуск стенда](#запуск-стенда).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Репликация](#репликация)
* [Файлы конфигурации Tarantool Clusters Federation](#файлы-конфигурации-tarantool-clusters-federation)
  - [Кластер A](#кластер-a)
  - [Кластер B](#кластер-b)
  - [Репликация из B в A](#репликация-из-b-в-a)
  - [Репликация из A в B](#репликация-из-a-в-b)
* [Отключение стенда](#отключение-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* архив для развёртывания TCF версии 0.9.0.
  Архив можно скачать в личном кабинете tarantool.io, в разделе [tcf/release/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tcf/release);
* приложение Docker Compose;
* исходные файлы примера `tarantool_clusters_federation`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `tarantool_clusters_federation` расположен в директории `examples/tarantool_clusters_federation`.
>  * Отдельный архив [tarantool_clusters_federation.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Ftarantool_clusters_federation&filename=tarantool_clusters_federation), скачанный из этого репозитория.

> [!NOTE]
> Версия TCF должна соответствовать версии Tarantool DB 1.x, установленной в вашем окружении.
> Например, TCF 0.9.0 поддерживается начиная с версии Tarantool DB 1.2.4.
> Использование несовместимых версий может привести к ошибкам запуска или проблемам в работе компонентов.

## Запуск стенда

Перейдите в директорию с примером:

```shell
cd examples/tarantool_clusters_federation
```

Загрузите в эту директорию архив для развёртывания TCF и распакуйте его в новой папке `tcf_archive`:

```shell
mkdir tcf_archive
tar -xzvf tcf-<VERSION>.tar.gz --directory tcf_archive
```

Здесь:

- `VERSION` — версия продукта.

Пример: `tcf-0.9.0.tar.gz`.

Создайте директорию `bin` и скопируйте в нее бинарные файлы `tcf-destination` и `tcf-gateway` из созданной директории `tcf_archive`:

```shell
mkdir bin
cp tcf_archive/tcf-destination bin && cp tcf_archive/tcf-gateway bin
```

Для запуска примера не требуются архив с TCF и другие файлы из директории `tcf_archive`, так что их можно удалить:

```shell
rm -r tcf_archive
rm -r tcf-<VERSION>.tar.gz
```

Запустите кластер etcd:

```shell
docker compose -f docker-compose-etcd.yml up -d
```

Просмотреть логи можно с помощью следующей команды:

```shell
docker compose -f docker-compose-etcd.yml logs etcd1
```

Дождитесь в логах появления такого сообщения:

```shell
tarantool_cluster_federation-etcd1-1  | 2024-04-02 12:37:41.475318 I | etcdserver/api: enabled capabilities for version 3.5
```

После этого запустите кластеры Tarantool DB:

```shell
docker compose -f docker-compose-clusters.yml up --force-recreate -d
```

Дождитесь, пока поднимутся два кластера:

* кластер [**А**](http://localhost:8080);
* кластер [**B**](http://localhost:9080).

Запустите репликатор:

```shell
docker compose -f docker-compose-replicator.yml up --force-recreate -d --build
```

Запущенный стенд состоит из:
* двух кластеров Tarantool DB,
* кластера etcd из трех узлов;
* сервиса репликатора Tarantool Clusters Federation.

На запущенном стенде настроена репликация из [**кластера А**](http://localhost:8080) в [**кластер B**](http://localhost:9080).
Настройки TCF доступны в веб-интерфейсе Tarantool DB по адресу [http://localhost:8081](http://localhost:8081) на вкладке **TCF**.
Подробная информация о доступных [опциях конфигурации TCF](https://www.tarantool.io/docs/tcf/ru/references/cartridge-yaml)
и [настройке TCF через веб-интерфейс](https://www.tarantool.io/docs/tcf/ru/references/cartridge_ui)
приведена в документации Tarantool Clusters Federation.

## Репликация

Подключитесь к роутеру А, используя команду `tt connect`:

```shell
tt connect admin:cookie-A@localhost:3300
```

Запустите вставку данных с помощью следующей команды:

```shell
localhost:3300> box.schema.func.call('__start_data_stream')
```

После этого откройте веб-интерфейс Tarantool DB и перейдите на вкладку **Space explorer**.
На этой вкладке вы увидите, как реплицируются данные из [кластера A](http://localhost:8080/admin/space-explorer/hosts) в [кластер B](http://localhost:8080/admin/space-explorer/hosts).

Чтобы отключить запись данных, выполните следующую команду:

```shell
box.schema.func.call('__stop_data_stream')
```

## Файлы конфигурации Tarantool Clusters Federation

Файлы конфигурации Tarantool Clusters Federation расположены в корневой директории примера `tarantool_clusters_federation`.

### Кластер A

Конфигурация кластера приведена в файле `./bootstrap-A/config.yml`:

```yaml
cluster_federation:
  cluster_1: cluster_a
  cluster_2: cluster_b

  replication_user: replicator
  replication_password: SuPPerSECreT_PAssw0rd

  status_ttl: 4
  enable_system_check: true
  failover_timeout: 20
  health_check_delay: 3
  max_suspect_counts: 3

  initial_status: active

  dml_users:
    - db_user
```

Полный список поддерживаемых опций конфигурации кластера приведен в разделе
[Конфигурация кластера в YAML (Cartridge)](https://www.tarantool.io/docs/tcf/ru/references/cartridge-yaml) в документации TCF.

Настроить кластер можно также в веб-интерфейсе Tarantool DB на вкладке **TCF**.
Узнать больше: [Конфигурация кластера в веб-интерфейсе (Cartridge)](https://www.tarantool.io/docs/tcf/ru/references/cartridge_ui).

### Кластер B

Конфигурация кластера приведена в файле `./bootstrap-B/config.yml`:

```yaml
cluster_federation:
  cluster_1: cluster_b
  cluster_2: cluster_a

  replication_user: replicator
  replication_password: SuPPerSECreT_PAssw0rd

  status_ttl: 4
  enable_system_check: true
  failover_timeout: 20
  health_check_delay: 3
  max_suspect_counts: 3

  initial_status: passive

  dml_users:
    - db_user
```

Полный список опций конфигурации кластера приведен в разделе
[Конфигурация кластера в YAML (Cartridge)](https://www.tarantool.io/docs/tcf/ru/references/cartridge-yaml) в документации TCF.

Настроить кластер можно также в веб-интерфейсе Tarantool DB на вкладке **TCF**.
Узнать больше: [Конфигурация кластера в веб-интерфейсе (Cartridge)](https://www.tarantool.io/docs/tcf/ru/references/cartridge_ui).

### Репликация из A в B

Конфигурация для репликации из A в B приведена в файле `./config_repl_AB.yaml`:
```yaml
gateway:
  grpc_server:
    host: 0.0.0.0
    port: 10080
  replica_type: anonymous
  max_cpu: 2
  log_level: debug
  log_type: plain # plain/json
  log_path: gateway_AB.log,stdout
  report_interval: 10

  stream_instances:
    - uri: tarantool-storage-A-1-1:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd
    - uri: tarantool-storage-A-1-2:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd
    - uri: tarantool-storage-A-2-1:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd
    - uri: tarantool-storage-A-2-2:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd

destination:
  gateways:
    - host: localhost
      port: 10080

  # size of every channel for replicaset events. Zero will make it unbuffered
  buffer_size: 10000
  log_type: plain # plain/json
  log_level: debug
  log_path: destination_AB.log,stdout
  report_interval: 10

  vshard_routers:
    hosts:
      - "tarantool-router-B:3301"
    user: replicator
    password: SuPPerSECreT_PAssw0rd

  # Optional parameters
  start_retry_delay: 200 #  milliseconds
  max_retry_delay: 1500 # milliseconds
  retry_attempts: 10 # milliseconds

  max_cpu: 2
```

Полный список опций конфигурации для репликатора приведен в разделе
[Конфигурация репликаторов данных](https://www.tarantool.io/docs/tcf/ru/references/reference_replicators) в документации TCF.

### Репликация из B в A

Конфигурация для репликации из B в A приведена в файле `./config_repl_BA.yaml`:

```yaml
gateway:
  grpc_server:
    host: 0.0.0.0
    port: 10180
  replica_type: anonymous
  max_cpu: 2
  log_level: debug
  log_type: plain # plain/json
  log_path: gateway_BA.log,stdout

  stream_instances:
    - uri: tarantool-storage-B-1-1:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd
    - uri: tarantool-storage-B-1-2:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd
    - uri: tarantool-storage-B-2-1:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd
    - uri: tarantool-storage-B-2-2:3301
      user: replicator
      password: SuPPerSECreT_PAssw0rd

destination:
  gateways:
    - host: localhost
      port: 10180

  # size of every channel for replicaset events. Zero will make it unbuffered
  buffer_size: 10000
  log_type: plain # plain/json
  log_level: debug
  log_path: destination_BA.log,stdout

  vshard_routers:
    hosts:
      - "tarantool-router-A:3301"
    user: replicator
    password: SuPPerSECreT_PAssw0rd

  # Optional parameters
  start_retry_delay: 200 #  milliseconds
  max_retry_delay: 1500 # milliseconds
  retry_attempts: 10 # milliseconds

  max_cpu: 2
```

Полный список опций конфигурации для репликатора приведен в разделе
[Конфигурация репликаторов данных](https://www.tarantool.io/docs/tcf/ru/references/reference_replicators) в документации TCF.

## Отключение стенда

Чтобы отключить стенд, выполните следующие команды:

```shell
docker compose -f docker-compose-replicator.yml down
docker compose -f docker-compose-clusters.yml down
docker compose -f docker-compose-etcd.yml down
```
