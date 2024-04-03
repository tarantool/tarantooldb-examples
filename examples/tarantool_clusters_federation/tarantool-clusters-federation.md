(admin_guide-tcf)=
# Использование Tarantool Clusters Federation

[Tarantool Clusters Federation](https://www.tarantool.io/en/clustersfederation/) позволяет выполнять репликацию
шардированных данных между двумя независимыми кластерами Tarantool DB.

Для работы Tarantool Clusters Federation необходимы:

* активный кластер Tarantool DB -- с него идет чтение реплицируемых данных;
* пассивный кластер Tarantool DB -- на него идет запись реплицируемых данных;
* [etcd](https://etcd.io/) -- для восстановления после сбоя (failover) кластеров Tarantool DB;
* репликатор Tarantool Clusters Federation -- бинарные файлы `tcf-destination` и `tcf-gateway`.

В примере показано, как запустить кластеры Tarantool DB в Docker в связке с Tarantool Clusters Federation
и настроить работу репликатора между кластерами.
Полный пример с исходным кодом находится в директории [./doc/examples/tarantool_clusters_federation/](https://github.com/tarantool/tarantooldb/tree/master/doc/examples/tarantool_cluster_federation).

Содержание:

* [](admin_guide-tcf-start_example)
* [](admin_guide-tcf-replication)
* [](admin_guide-tcf-config)
  - [](admin_guide-tcf-config-a)
  - [](admin_guide-tcf-config-b)
  - [](admin_guide-tcf-config-b-to-a)
  - [](admin_guide-tcf-config-a-to-b)
* [](admin_guide-tcf-stop_example)

(admin_guide-tcf-start_example)=
## Запуск стенда

Перейдите в директорию с примером:

```shell
cd ./doc/examples/tarantool_clusters_federation/
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

```
tarantool_cluster_federation-etcd1-1  | 2024-04-02 12:37:41.475318 I | etcdserver/api: enabled capabilities for version 3.4
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

(admin_guide-tcf-replication)=
## Репликация

Подключитесь к роутеру-А, используя команду `tt connect`:

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

(admin_guide-tcf-config)=
## Файлы конфигурации Tarantool Clusters Federation

Файлы конфигурации Tarantool Clusters Federation расположены в директории примера [tarantool_clusters_federation](https://github.com/tarantool/tarantooldb/tree/master/doc/examples/tarantool_cluster_federation).

(admin_guide-tcf-config-a)=
### Кластер A

Конфигурация кластера приведена в файле [./bootstrap-A/config.yml](https://github.com/tarantool/tarantooldb/blob/master/doc/examples/tarantool_cluster_federation/bootstrap-A/config.yml):

```{literalinclude} bootstrap-A/config.yml
:start-at: cluster_federation
:end-at: db_user
:language: yaml
:dedent:
```

(admin_guide-tcf-config-b)=
### Кластер B

Конфигурация кластера приведена в файле [./bootstrap-B/config.yml](https://github.com/tarantool/tarantooldb/blob/master/doc/examples/tarantool_cluster_federation/bootstrap-B/config.yml):

```{literalinclude} bootstrap-B/config.yml
:start-at: cluster_federation
:end-at: db_user
:language: yaml
:dedent:
```

(admin_guide-tcf-config-a-to-b)=
### Репликация из A в B

Конфигурация для репликации из A в B приведена в файле [./config_repl_AB.yaml](https://github.com/tarantool/tarantooldb/blob/master/doc/examples/tarantool_cluster_federation/config_repl_AB.yaml):

```{literalinclude} config_repl_AB.yaml
:language: yaml
:dedent:
```

(admin_guide-tcf-config-b-to-a)=
### Репликация из B в A

Конфигурация для репликации из B в A приведена в файле [./config_repl_BA.yaml](https://github.com/tarantool/tarantooldb/blob/master/doc/examples/tarantool_cluster_federation/config_repl_BA.yaml):

```{literalinclude} config_repl_BA.yaml
:language: yaml
:dedent:
```
(admin_guide-tcf-stop_example)=
## Отключение стенда

Чтобы отключить стенд, выполните следующие команды:

```shell
docker compose -f docker-compose-replicator.yml down
docker compose -f docker-compose-clusters.yml down
docker compose -f docker-compose-etcd.yml down
```
