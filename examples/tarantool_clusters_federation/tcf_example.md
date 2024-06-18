(admin_guide-tcf-example)=
# Запуск кластеров Tarantool DB с TCF и настройка репликатора

В этом руководстве показано, как запустить два независимых кластера Tarantool DB в Docker в связке с [Tarantool Clusters Federation](https://www.tarantool.io/ru/clustersfederation/doc/latest/) (TCF)
и настроить работу репликатора между кластерами.

```{admonition} Примечание
:class: note

TCF поддерживает репликацию шардированных данных в спейсах с асинхронным режимом репликации.
Это означает, что передача [словарей](user_guide-dictionary) через TCF недоступна.
```

Для работы Tarantool Clusters Federation необходимы:

* активный кластер Tarantool DB -- с него идет чтение реплицируемых данных;
* пассивный кластер Tarantool DB -- на него идет запись реплицируемых данных;
* [etcd](https://etcd.io/) -- для восстановления после сбоя (failover) кластеров Tarantool DB;
* репликатор Tarantool Clusters Federation -- бинарные файлы `tcf-destination` и `tcf-gateway`.

Содержание:

* [](admin_guide-tcf-example-prereq)
* [](admin_guide-tcf-example-start_example)
* [](admin_guide-tcf-example-replication)
* [](admin_guide-tcf-example-config)
  - [](admin_guide-tcf-example-config-a)
  - [](admin_guide-tcf-example-config-b)
  - [](admin_guide-tcf-example-config-b-to-a)
  - [](admin_guide-tcf-example-config-a-to-b)
* [](admin_guide-tcf-example-stop_example)

(admin_guide-tcf-example-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `tarantool_clusters_federation`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `tarantool_clusters_federation` расположен в таком архиве в директории `./doc/examples/tarantool_clusters_federation/`.

  * Отдельный архив [tarantool_clusters_federation.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/tarantool_clusters_federation/tarantool_clusters_federation.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-tcf-example-start_example)=
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
Настройки TCF доступны в веб-интерфейсе Tarantool DB по адресу [http://localhost:8081](http://localhost:8081) на вкладке **TCF**.
Подробная информация о доступных [опциях конфигурации TCF](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_yaml/) и [настройке TCF через веб-интерфейс]() приведена в документации Tarantool Clusters Federation.

(admin_guide-tcf-example-replication)=
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

(admin_guide-tcf-example-config)=
## Файлы конфигурации Tarantool Clusters Federation

Файлы конфигурации Tarantool Clusters Federation расположены в корневой директории примера `tarantool_clusters_federation`.

(admin_guide-tcf-example-config-a)=
### Кластер A

Конфигурация кластера приведена в файле `./bootstrap-A/config.yml`:

```{literalinclude} bootstrap-A/config.yml
:start-at: cluster_federation
:end-at: db_user
:language: yaml
:dedent:
```

Полный список поддерживаемых опций конфигурации кластера приведен в разделе
[Конфигурация кластера в YAML (Cartridge)](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_yaml/) в документации TCF.

Настроить кластер можно также в веб-интерфейсе Tarantool DB на вкладке **TCF**.
Узнать больше: [Конфигурация кластера в веб-интерфейсе (Cartridge)](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_ui/).

(admin_guide-tcf-example-config-b)=
### Кластер B

Конфигурация кластера приведена в файле `./bootstrap-B/config.yml`:

```{literalinclude} bootstrap-B/config.yml
:start-at: cluster_federation
:end-at: db_user
:language: yaml
:dedent:
```

Полный список опций конфигурации кластера приведен в разделе
[Конфигурация кластера в YAML (Cartridge)](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_yaml/) в документации TCF.

Настроить кластер можно также в веб-интерфейсе Tarantool DB на вкладке **TCF**.
Узнать больше: [Конфигурация кластера в веб-интерфейсе (Cartridge)](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_ui/).

(admin_guide-tcf-example-config-a-to-b)=
### Репликация из A в B

Конфигурация для репликации из A в B приведена в файле `./config_repl_AB.yaml`:
```{literalinclude} config_repl_AB.yaml
:language: yaml
:dedent:
```

Полный список опций конфигурации для репликатора приведен в разделе
[Конфигурация репликаторов данных](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_replicator/) в документации TCF.

(admin_guide-tcf-example-config-b-to-a)=
### Репликация из B в A

Конфигурация для репликации из B в A приведена в файле `./config_repl_BA.yaml`:

```{literalinclude} config_repl_BA.yaml
:language: yaml
:dedent:
```

Полный список опций конфигурации для репликатора приведен в разделе
[Конфигурация репликаторов данных](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_replicator/) в документации TCF.

(admin_guide-tcf-example-stop_example)=
## Отключение стенда

Чтобы отключить стенд, выполните следующие команды:

```shell
docker compose -f docker-compose-replicator.yml down
docker compose -f docker-compose-clusters.yml down
docker compose -f docker-compose-etcd.yml down
```
