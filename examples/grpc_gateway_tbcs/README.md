# Хранение конфигурации gRPC Gateway в TBCS

Пример предназначен для сборки Tarantool DB 3.4.0 с поддержкой TBCS в gRPC Gateway.

В этом руководстве описано, как хранить конфигурацию шлюзов и топологию
vshard в хранилище конфигурации Tarantool DB (TBCS), выполнять gRPC-запросы
и обновлять конфигурацию. Состояние и метрики доступны в веб-интерфейсе TCM.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Выбор групп хранилищ](#выбор-групп-хранилищ)
* [Выполнение запросов](#выполнение-запросов)
* [Изменение конфигурации](#изменение-конфигурации)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB версии 3.4.0 или выше с поддержкой TBCS в gRPC Gateway;
* приложение Docker Compose, оболочка Bash и утилита `make`;
* утилита `grpcurl` для выполнения запросов;
* утилита `curl` для проверки готовности шлюзов;
* исходные файлы примера `grpc_gateway_tbcs`.

В Compose-файле используется локальный тег образа `tarantooldb:3x-latest`.
Старые сборки gRPC Gateway, читающие только `TDB_WORKER_CONFIG_ETCD_*`,
для этого примера не подходят.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `grpc_gateway_tbcs` расположен в директории `examples/grpc_gateway_tbcs`.
> * Отдельный архив [grpc_gateway_tbcs.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgrpc_gateway_tbcs&filename=grpc_gateway_tbcs), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301;
* 8081;
* 9081–9082;
* 9091–9092.

Перейдите в директорию примера `grpc_gateway_tbcs`:

```shell
cd examples/grpc_gateway_tbcs
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:

* кластера Tarantool DB: 1 роутер и 2 набора реплик по 2 хранилища;
* 2 экземпляров gRPC Gateway;
* 3 узлов TBCS с автоматическим выбором лидера (`replication.failover: election`);
* 1 узла Tarantool Cluster Manager (TCM).

etcd в этом примере не используется. Команда `make start` публикует топологию
и конфигурации шлюзов в TBCS, выполняет начальную настройку шардирования
и применяет миграции, затем запускает шлюзы.

После запуска должны работать все контейнеры, кроме
[init_host](../up_with_docker_compose/README.md#контейнер-init_host).
Этот контейнер настраивает шардирование и применяет миграции, после чего удаляется.

Откройте веб-интерфейс TCM по адресу [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

* **Username**: `admin`;
* **Password**: `secret`.

Выберите кластер **gRPC TBCS example** и откройте вкладку **Stateboard**.
Шлюзы отображаются как `grpc-gateway-1` и `grpc-gateway-2`.

| Интерфейс | Адрес |
| --- | --- |
| gRPC первого шлюза | `localhost:9091` |
| gRPC второго шлюза | `localhost:9092` |
| Метрики первого шлюза | `http://localhost:9081/metrics` |
| Метрики второго шлюза | `http://localhost:9082/metrics` |
| Роутер (iproto) | `localhost:3301` |

## Определение конфигурации

Топология, пользователи и [технологические роли](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/model/roles) кластера заданы в конфигурационном файле `cluster/config.yml`.
Параметры узлов TBCS находятся в `cluster/config-storage.yml`,
конфигурации шлюзов — в `cluster/grpc-gateway-1.yml` и `cluster/grpc-gateway-2.yml`.

Миграции из `cluster/migrations/scenario` создают спейс `books` с полями
`id`, `bucket_id`, `title` и `author` и добавляют 1006 записей.
Ключ шардирования спейса `books` — это поле `id`, значение `bucket_id` вычисляет шлюз.

Подключение каждого шлюза к TBCS задаётся переменными окружения
в `cluster/docker-compose.yml`. Например, для первого шлюза:

```yaml
TDB_WORKER_NAME: grpc-gateway-1
TDB_WORKER_HOST_NAME: grpc-gateway-1
TDB_WORKER_CONFIG_STORAGE_PREFIX: /tdb-workers/grpc-tbcs-example
TDB_WORKER_CONFIG_STORAGE_ENDPOINTS: >-
  [{"uri":"tarantool-config-storage-1:3301","login":"client","password":"secret"},
   {"uri":"tarantool-config-storage-2:3301","login":"client","password":"secret"},
   {"uri":"tarantool-config-storage-3:3301","login":"client","password":"secret"}]
```

Параметр `uri` задаёт адрес IPROTO без префикса `http://`.
У всех узлов используются одинаковые учётные данные.
Переменные `TDB_WORKER_CONFIG_ETCD_*` в этом режиме не задаются.

Документ конфигурации первого шлюза хранится по ключу:

```text
/tdb-workers/grpc-tbcs-example/instances/grpc-gateway-1/grpc-gateway-1
```

Команда `tt cluster worker publish` сама добавляет `instances` в ключ.
Топология публикуется командой `tt cluster publish` по ключу `/tdb/config/all`.
Этот полный ключ указан в параметре `config.vshard.tarantool_cluster_prefix`.
Подключение к TBCS для чтения топологии наследуется из окружения шлюза;
дублировать его в `config.tbcs` не нужно.

Секция `config.log` задаёт журнал событий, а параметр
`config.roles.httpd.instrumentation.listen` — адрес служебного HTTP-сервера.
Секция `instrumentation` содержит адреса для TCM.

> [!NOTE]
> Соединения с TBCS в этом стенде не зашифрованы. Для защищённого подключения
> нужна сборка gRPC-worker с тегом `go_storage_ssl` и OpenSSL;
> обычная сборка без этого тега TLS для TBCS не поддерживает.

## Выбор групп хранилищ

Топология содержит отдельные группы `storage-1` и `storage-2`, общей группы
`storages` нет. Первый шлюз выбирает экземпляры по наследуемой роли
`sharding.roles: [storage]`. Второй явно выбирает обе группы:

```yaml
config:
  vshard:
    storages_groups: [storage-1, storage-2]
    tarantool_cluster_prefix: /tdb/config/all
```

Для выбора одной группы задайте `storages_groups: [storage-1]`.
Явный список имеет приоритет над выбором по ролям. Если указанной группы
нет в топологии, шлюз завершит запуск с ошибкой. Без явного списка
отсутствие экземпляров с ролью `storage` также приводит к ошибке запуска.

## Выполнение запросов

Все дальнейшие команды выполняются на локальном компьютере
из директории примера. Дождитесь готовности обоих шлюзов:

```shell
curl -fsS http://localhost:9081/ready
curl -fsS http://localhost:9082/ready
```

Прочитайте одну и ту же книгу через оба шлюза:

```shell
for port in 9091 9092; do
    grpcurl -plaintext -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
        localhost:$port tdb.crud.v1.Crud/Get
done
```

В обоих ответах должна быть книга «Dune». Остальные CRUD-запросы
и постраничная выборка приведены в [основном примере](../grpc_gateway/README.md#выполнение-crud-запросов).
В этом стенде такие же данные и адреса шлюзов.

## Изменение конфигурации

Добавьте `timeout: 3s` в секцию `config.vshard` файла
`cluster/grpc-gateway-1.yml`. Опубликуйте конфигурации:

```shell
make publish-workers
```

Шлюз получает событие из TBCS, перечитывает документ и применяет изменения
без перезапуска. Чтобы просмотреть сообщения о применении конфигурации, выполните:

```shell
make logs-gateway
```

Для выхода из просмотра журнала нажмите `Ctrl + C`.

После смены лидера TBCS соединение и подписка на изменения восстанавливаются.
Чтобы повторить публикацию при выключенном первом узле TBCS,
в команде `get_config_master.sh` в `Makefile` укажите работающий узел.

> [!NOTE]
> Изменения журнала аудита (`config.audit_log`) применяются без перезапуска.
> Изменение журнала событий (`config.log`) или подключения к хранилищу
> конфигурации требует перезапуска шлюза.

Топология vshard загружается при создании клиента. После изменения состава
кластера в TBCS перезапустите шлюзы: изменение топологии само по себе не заменяет
клиент работающего шлюза.

> [!NOTE]
> Операция `Select` не фиксирует общий снимок данных. При переносе бакетов
> между страницами возможны дубликаты и пропуски.

## Остановка стенда

Чтобы остановить стенд, выполните в директории примера следующую команду:

```shell
make stop
```

Команда `make stop` удаляет контейнеры и сеть примера, включая данные TBCS
и книг. При следующем запуске `make start` конфигурации и исходные данные создаются заново.
