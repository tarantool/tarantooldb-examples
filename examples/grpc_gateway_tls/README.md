# TLS для gRPC Gateway

Пример предназначен для сборки Tarantool DB 3.4.0 с поддержкой TLS между gRPC Gateway и хранилищами.

В этом руководстве описано, как настроить TLS для gRPC Gateway,
выполнять защищённые запросы и проверять сертификаты шлюза и хранилищ.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Выполнение запросов](#выполнение-запросов)
* [Проверка сертификатов](#проверка-сертификатов)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB версии 3.4.0 или выше с поддержкой TLS между шлюзом и хранилищами;
* приложение Docker Compose, оболочка Bash и утилита `make`;
* утилита OpenSSL для создания сертификатов;
* утилита `grpcurl` для выполнения запросов;
* утилита `curl` для проверки готовности шлюза;
* исходные файлы примера `grpc_gateway_tls`.

Для этого стенда нужен образ с поддержкой `config.vshard.tls` из актуальной
ветки `release-3x/grpc-worker-core`, доступный под локальным тегом
`tarantooldb:3x-latest`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `grpc_gateway_tls` расположен в директории `examples/grpc_gateway_tls`.
> * Отдельный архив [grpc_gateway_tls.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgrpc_gateway_tls&filename=grpc_gateway_tls), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 9443;
* 9181.

Перейдите в директорию примера `grpc_gateway_tls`:

```shell
cd examples/grpc_gateway_tls
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:

* 1 роутера Tarantool DB версии 3.4.0 или выше с поддержкой TLS между шлюзом и хранилищами;
* 2 хранилищ Tarantool DB в отдельных наборах реплик;
* 1 экземпляра gRPC Gateway;
* 1 узла etcd.

После запуска должны работать все контейнеры, кроме
[init_host](../up_with_docker_compose/README.md#контейнер-init_host).
Этот контейнер настраивает шардирование и применяет миграции, после чего удаляется.

| Интерфейс | Адрес |
| --- | --- |
| gRPC шлюза с TLS | `localhost:9443` |
| Проверка готовности шлюза | `http://localhost:9181/ready` |

## Определение конфигурации

Топология, пользователи и [технологические роли](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/model/roles) кластера заданы в конфигурационном файле `cluster/config.yml`.
Миграции из `cluster/migrations/scenario` создают спейс `books`
с полями `id`, `bucket_id`, `title` и `author` и добавляют шесть книг.

Команда `make start` создаёт учебный центр сертификации (CA) и сертификаты
сроком действия 30 дней в каталоге `_local/`.
Каталоги с сертификатами подключаются к контейнерам только для чтения.

> [!NOTE]
> Созданные сертификаты предназначены для примера. Не используйте их в рабочей среде.

Клиент подключается к шлюзу по TLS и проверяет его сертификат.
Между шлюзом и хранилищами используется mTLS: обе стороны проверяют
сертификаты друг друга.

Конфигурация шлюза находится в файле `cluster/grpc-gateway-1.yml`.
При запуске она публикуется в хранилище конфигурации etcd:

```yaml
config:
  server:
    tls_cert_file: /gateway/gateway.crt
    tls_key_file: /gateway/gateway.key
  vshard:
    tls:
      enabled: true
      ca_file: /client/ca.crt
      cert_file: /client/client.crt
      key_file: /client/client.key
```

Секция `config.server` задаёт сертификат и ключ gRPC-сервера. В `config.vshard.tls` параметр `ca_file`
задаёт доверенный CA хранилищ, а `cert_file` и `key_file` — клиентский
сертификат и ключ для mTLS.

В файле `cluster/config.yml` для IPROTO каждого узла включён TLS.
Например, для хранилища `storage-1-a`:

```yaml
iproto:
  listen:
    - uri: storage-1-a:3301
      params:
        transport: ssl
        ssl_ca_file: /certs/ca.crt
        ssl_cert_file: /certs/storage.crt
        ssl_key_file: /certs/storage.key
```

Параметр `ssl_ca_file` включает проверку клиентских сертификатов на стороне Tarantool.
Сертификат хранилищ содержит DNS-имена `router-1`, `storage-1-a` и
`storage-2-a`. Сертификат шлюза содержит `localhost`, `127.0.0.1` и
`grpc-gateway-1`. При изменении адресов эти имена нужно включить в SAN
новых сертификатов: доверенного CA недостаточно, имя сервера тоже проверяется.

## Выполнение запросов

Все дальнейшие команды выполняются на локальном компьютере
из директории примера. Посмотрите список сервисов через gRPC reflection:

```shell
grpcurl -cacert _local/ca/ca.crt localhost:9443 list
```

Прочитайте карточку книги «Dune»:

```shell
grpcurl -cacert _local/ca/ca.crt \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9443 tdb.crud.v1.Crud/Get
```

Ответ:

```json
{
  "record": {
    "fields": {
      "author": {
        "stringValue": "Frank Herbert"
      },
      "id": {
        "intValue": "1"
      },
      "title": {
        "stringValue": "Dune"
      }
    }
  }
}
```

Получите первые три книги:

```shell
grpcurl -cacert _local/ca/ca.crt \
  -d '{"space":"books","options":{"limit":3}}' \
  localhost:9443 tdb.crud.v1.Crud/Select
```

Для следующей страницы передайте полученный `nextCursor` в `options.cursor`.
Значения `space` и `conditions` должны оставаться прежними.

Проверьте готовность шлюза и его соединений с хранилищами:

```shell
curl --fail http://localhost:9181/ready
```

## Проверка сертификатов

Выполните запрос без указания CA:

```shell
grpcurl -max-time 5 localhost:9443 list
```

Запрос завершится ошибкой `certificate signed by unknown authority`,
поскольку сертификат шлюза подписан CA примера.

Теперь укажите доверенный CA, но передайте неверное имя сервера:

```shell
grpcurl -max-time 5 -cacert _local/ca/ca.crt \
  -authority wrong.example localhost:9443 list
```

Запрос завершится ошибкой: имя `wrong.example` отсутствует в сертификате шлюза.

## Остановка стенда

Чтобы остановить стенд, выполните в директории примера следующую команду:

```shell
make stop
```

Команда `make stop` удаляет контейнеры и сеть примера вместе с данными кластера.
При следующем запуске `make start` исходные данные создаются заново.

> [!NOTE]
> Каталог `_local/` с сертификатами сохраняется на локальном компьютере.
> При следующем запуске используются те же сертификаты.
