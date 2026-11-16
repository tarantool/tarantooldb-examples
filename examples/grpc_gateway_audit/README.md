# Настройка журнала аудита для запросов к gRPC Gateway

Пример доступен с версии Tarantool DB 3.4.0.

В этом руководстве описано, как настроить журнал аудита gRPC-запросов Tarantool DB,
посмотреть события успешных и неуспешных операций и найти запрос по его идентификатору.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Выполнение запросов](#выполнение-запросов)
* [Просмотр журнала аудита](#просмотр-журнала-аудита)
* [Поиск событий](#поиск-событий)
* [Изменение настроек журнала аудита](#изменение-настроек-журнала-аудита)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB версии 3.4.0 или выше;
* приложение Docker Compose и утилита `make`;
* утилита `grpcurl` для выполнения запросов;
* утилита `jq` для просмотра и фильтрации JSON-событий;
* исходные файлы примера `grpc_gateway_audit`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `grpc_gateway_audit` расположен в директории `examples/grpc_gateway_audit`.
> * Отдельный архив [grpc_gateway_audit.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgrpc_gateway_audit&filename=grpc_gateway_audit), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301;
* 8081;
* 9081–9082;
* 9091–9092.

Перейдите в директорию примера `grpc_gateway_audit`:

```shell
cd examples/grpc_gateway_audit
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:

* кластера Tarantool DB:
  * 1 роутер;
  * 2 набора реплик по 2 хранилища;
* 2 экземпляров gRPC Gateway;
* 1 узла etcd;
* 1 узла [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме
[init_host](../up_with_docker_compose/README.md#контейнер-init_host).
Этот контейнер настраивает шардирование и применяет миграции, после чего удаляется.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

* **Username**: `admin`
* **Password**: `secret`

Выберите кластер **gRPC audit example** и откройте вкладку **Stateboard**.
Шлюзы отображаются как `grpc-gateway-1` и `grpc-gateway-2`.

| Шлюз | Адрес gRPC | Место записи аудита |
| --- | --- | --- |
| `grpc-gateway-1` | `localhost:9091` | `logs/grpc-gateway-1/audit.jsonl` на хосте |
| `grpc-gateway-2` | `localhost:9092` | `logs/grpc-gateway-2/audit.jsonl` на хосте |

## Определение конфигурации

Топология, пользователи и [технологические роли](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/model/roles) кластера заданы в конфигурационном файле `cluster/config.yml`.
На хранилищах включена технологическая роль `app.roles.tdb_gateway`, которая выполняет
запросы шлюзов через модуль шардирования vshard.

Конфигурации шлюзов находятся в файлах `cluster/grpc-gateway-1.yml`
и `cluster/grpc-gateway-2.yml`. При запуске они публикуются в хранилище конфигурации etcd.
Аудит настраивается в секции конфигурации `config.audit_log`.

Каждый шлюз записывает события в файл:

```yaml
config:
  audit_log:
    to: file
    file: /var/log/tdb-gateway/audit.jsonl
    format: json
```

Здесь:

* `to: file` — включить журнал аудита; `to: devnull` — отключить его (значение по умолчанию);
* `file` — задать путь к файлу журнала аудита;
* `format: json` — задать формат событий.

Журнал аудита работает независимо от уровня журнала событий `config.log.level`.
Каждое событие записывается отдельной JSON-строкой.
В файле `cluster/docker-compose.yml` к каждому шлюзу подключён отдельный каталог
с локального компьютера:

```yaml
volumes:
  - ../logs/grpc-gateway-1:/var/log/tdb-gateway
```

Путь слева указан относительно Compose-файла в `cluster/`. Файл
`/var/log/tdb-gateway/audit.jsonl` первого шлюза доступен на хосте как
`logs/grpc-gateway-1/audit.jsonl`. Для второго шлюза используется
`logs/grpc-gateway-2`.

Команда `make start` создаёт каталоги и передаёт значения UID и GID текущего пользователя
в контейнеры шлюзов. Поэтому файлы журнала аудита, созданные с правами `0600`,
можно читать на хосте без `sudo`. Файлы открываются на добавление.

При запуске применяются миграции из директории `cluster/migrations/scenario`.
Они создают каталог книг — спейс `books` с полями `id`, `bucket_id`, `title`
и `author`, а затем добавляют одну книгу: «The Hobbit» Дж. Р. Р. Толкина.
Пример показывает журнал аудита чтения её карточки и запроса с пропущенным ключом.
Чтобы посмотреть книгу в TCM, откройте вкладку **Tuples** и выберите спейс `books`.

> [!NOTE]
> В примере включён gRPC reflection: утилита `grpcurl` получает описание API
> из запущенного шлюза, поэтому локальные proto-файлы не требуются.

## Выполнение запросов

Вызовите первый шлюз и прочитайте карточку книги «The Hobbit».
Передайте идентификатор запроса в метаданные `request-id`:

```shell
grpcurl -plaintext -H 'request-id: audit-get-1' \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9091 tdb.crud.v1.Crud/Get
```

Ответ:

```json
{
  "record": {
    "fields": {
      "id": {
        "intValue": "1"
      },
      "title": {
        "stringValue": "The Hobbit"
      },
      "author": {
        "stringValue": "J. R. R. Tolkien"
      }
    }
  }
}
```

Теперь выполните запрос без ключа:

```shell
grpcurl -plaintext -H 'request-id: audit-invalid-get-1' \
  -d '{"space":"books"}' \
  localhost:9091 tdb.crud.v1.Crud/Get
```

Запрос завершится ошибкой `InvalidArgument`. В журнал аудита попадёт событие
с идентификатором `audit-invalid-get-1` и результатом `nok`.

## Просмотр журнала аудита

Все команды просмотра и поиска выполняются на локальном компьютере
из директории примера. Посмотрите события первого шлюза:

```shell
jq . logs/grpc-gateway-1/audit.jsonl
```

Пример события успешного запроса:

```json
{
  "time": "2026-10-01T12:00:00Z",
  "level": "INFO",
  "msg": "gRPC request completed",
  "type": "grpc.request",
  "method": "/tdb.crud.v1.Crud/Get",
  "request_id": "audit-get-1",
  "remote": "172.18.0.1:52134",
  "result": "ok",
  "code": "OK",
  "duration_ms": 1.25,
  "space": "books"
}
```

Время события, адрес клиента и длительность запроса будут отличаться.

| Поле | Значение |
| --- | --- |
| `time` | Время завершения обработки запроса |
| `level` | `INFO` при успехе, `WARN` при ошибке |
| `method` | Полное имя gRPC-метода |
| `request_id` | Переданный идентификатор запроса, либо `unknown`, если он не задан |
| `remote` | Адрес и порт подключённого клиента |
| `result` | `ok` при успехе, `nok` при ошибке |
| `code` | Код gRPC |
| `duration_ms` | Время обработки запроса в миллисекундах до записи события аудита |
| `space` | Имя спейса для CRUD-запроса |

## Поиск событий

Найдите событие ошибочного запроса по его идентификатору:

```shell
jq 'select(.request_id == "audit-invalid-get-1") | {level, request_id, result, code}' \
  logs/grpc-gateway-1/audit.jsonl
```

В событии будут следующие значения:

```json
{
  "level": "WARN",
  "request_id": "audit-invalid-get-1",
  "result": "nok",
  "code": "InvalidArgument"
}
```

> [!NOTE]
> Журнал аудита фиксирует результат обработки запроса. Содержимое записей, ключи,
> ответы и текст ошибок в события не включаются.
> Параметр `request-id` передаётся клиентом и используется для сопоставления событий.

Для текстового поиска используйте `grep`, а для фильтрации по полям — `jq`:

```shell
grep -F 'audit-get-1' logs/grpc-gateway-1/audit.jsonl | jq .
jq 'select(.result == "nok")' logs/grpc-gateway-*/audit.jsonl
```

`grep` ищет совпадение в строке целиком. Для точного поиска по идентификатору
используйте `select(.request_id == "...")`.

Выполните запрос ко второму шлюзу:

```shell
grpcurl -plaintext -H 'request-id: audit-file-get-1' \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9092 tdb.crud.v1.Crud/Get
```

Ответ будет таким же, как у первого шлюза. Найдите событие в локальном файле:

```shell
jq 'select(.request_id == "audit-file-get-1") | {request_id, result, code}' \
  logs/grpc-gateway-2/audit.jsonl
```

Вывод:

```json
{
  "request_id": "audit-file-get-1",
  "result": "ok",
  "code": "OK"
}
```

## Изменение настроек журнала аудита

Чтобы изменить настройки первого шлюза, отредактируйте секцию
`config.audit_log` в файле `cluster/grpc-gateway-1.yml`, затем опубликуйте
обновлённую конфигурацию в etcd:

```shell
docker compose -p tdb-grpc-audit -f cluster/docker-compose.yml \
  exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
  /tdb-workers/grpc-audit-example/instances/grpc-gateway-1/grpc-gateway-1 \
  < cluster/grpc-gateway-1.yml
```

Gateway применит настройки без перезапуска. Например, значение `to: devnull`
отключит запись новых событий.

> [!WARNING]
> Если при включённом журнале аудита невозможно открыть файл, шлюз не запустится.
> При неудачной смене пути в работающем шлюзе обновление конфигурации
> будет отклонено, а прежние настройки останутся активными.

## Остановка стенда

Чтобы остановить стенд, выполните в директории примера следующую команду:

```shell
make stop
```

Команда `make stop` удаляет контейнеры и сеть примера вместе с данными кластера.
При следующем запуске `make start` исходные данные создаются заново.

> [!NOTE]
> Каталог `logs/` с файлами журнала аудита сохраняется на локальном компьютере.
> При следующем запуске события будут дописываться в те же файлы.
