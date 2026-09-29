# Аудит запросов к gRPC Gateway

В этом руководстве описано, как настроить аудит gRPC-запросов Tarantool DB,
посмотреть события успешных и неуспешных операций и найти запрос по его идентификатору.

> [!NOTE]
> Пример доступен с версии Tarantool DB 3.4.0.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Выполнение запросов](#выполнение-запросов)
* [Просмотр аудита в stdout](#просмотр-аудита-в-stdout)
* [Просмотр аудита в файле](#просмотр-аудита-в-файле)
* [Изменение настроек аудита](#изменение-настроек-аудита)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
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
| `grpc-gateway-1` | `localhost:9091` | stdout контейнера |
| `grpc-gateway-2` | `localhost:9092` | `/var/log/tdb-gateway/audit.jsonl` внутри контейнера |

## Определение конфигурации

Топология, пользователи и роли кластера заданы в файле `cluster/config.yml`.
На хранилищах включена роль `app.roles.tdb_gateway`, которая выполняет
запросы шлюзов через vshard.

Конфигурации шлюзов находятся в файлах `cluster/grpc-gateway-1.yml`
и `cluster/grpc-gateway-2.yml`. При запуске они публикуются в etcd.
Аудит настраивается в секции `config.audit_log`.

Первый шлюз записывает события в stdout:

```yaml
config:
  audit_log:
    enabled: true
    output: stdout
```

Второй шлюз записывает события в файл:

```yaml
config:
  audit_log:
    enabled: true
    output: /var/log/tdb-gateway/audit.jsonl
```

Здесь:

* `enabled` включает аудит. По умолчанию аудит выключен;
* `output` задаёт место записи: `stdout`, `stderr` или путь к файлу.
  По умолчанию используется `stdout`.

Аудит работает независимо от уровня обычного лога `config.log.level`.
Каждое событие записывается отдельной JSON-строкой.
Каталог для файла подключён к контейнеру второго шлюза через Docker volume
`gateway_audit`, заданный в `cluster/docker-compose.yml`.

При запуске применяются миграции из директории `cluster/migrations/scenario`.
Они создают спейс `test_kv` с полями `id`, `bucket_id`, `name` и `payload`
и заполняют его 8 записями с `id` от 1 до 8.

> [!NOTE]
> В примере включён gRPC reflection: утилита `grpcurl` получает описание API
> из запущенного шлюза, поэтому локальные proto-файлы не требуются.

## Выполнение запросов

Вызовите первый шлюз и получите подготовленную запись.
Передайте идентификатор запроса в metadata `request-id`:

```shell
grpcurl -plaintext -H 'request-id: audit-get-1' \
  -d '{"space":"test_kv","key":{"parts":[1]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Get
```

Пример ответа:

```json
{
  "record": {
    "id": 1,
    "name": "seed-audit-row-01",
    "payload": {
      "source": "grpc-audit-example"
    }
  }
}
```

Теперь выполните запрос без ключа:

```shell
grpcurl -plaintext -H 'request-id: audit-invalid-get-1' \
  -d '{"space":"test_kv"}' \
  localhost:9091 service.tdb.crud.v1.Crud/Get
```

Запрос завершится ошибкой `InvalidArgument`. В журнал попадёт событие
с идентификатором `audit-invalid-get-1` и результатом `nok`.

## Просмотр аудита в stdout

Первый шлюз пишет события аудита в тот же поток, что и обычные логи.
Выберите события с полем `type: grpc.request`:

```shell
docker compose -p tdb-grpc-audit -f cluster/docker-compose.yml \
  logs --no-color --no-log-prefix grpc-gateway-1 \
  | jq -R 'fromjson? | select(.type == "grpc.request")'
```

Пример события успешного запроса:

```json
{
  "time": "2026-10-01T12:00:00Z",
  "level": "INFO",
  "msg": "gRPC request completed",
  "type": "grpc.request",
  "method": "/service.tdb.crud.v1.Crud/Get",
  "request_id": "audit-get-1",
  "remote": "172.18.0.1:52134",
  "result": "ok",
  "code": "OK",
  "duration_ms": 1.25,
  "space": "test_kv"
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

Найдите событие ошибочного запроса по его идентификатору:

```shell
docker compose -p tdb-grpc-audit -f cluster/docker-compose.yml \
  logs --no-color --no-log-prefix grpc-gateway-1 \
  | jq -R 'fromjson? | select(.type == "grpc.request" and .request_id == "audit-invalid-get-1")'
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
> Аудит фиксирует результат обработки запроса. Содержимое записей, ключи,
> ответы и текст ошибок в события не включаются.
> `request-id` передаётся клиентом и используется для сопоставления событий.

## Просмотр аудита в файле

Выполните запрос ко второму шлюзу:

```shell
grpcurl -plaintext -H 'request-id: audit-file-get-1' \
  -d '{"space":"test_kv","key":{"parts":[1]}}' \
  localhost:9092 service.tdb.crud.v1.Crud/Get
```

Ответ будет таким же, как у первого шлюза. Посмотрите файл аудита:

```shell
docker compose -p tdb-grpc-audit -f cluster/docker-compose.yml \
  exec -T grpc-gateway-2 cat /var/log/tdb-gateway/audit.jsonl | jq .
```

В нём будет событие с `request_id: audit-file-get-1`, `result: ok`
и `code: OK`.

Для сохранения журнала на локальном компьютере выполните:

```shell
docker compose -p tdb-grpc-audit -f cluster/docker-compose.yml \
  exec -T grpc-gateway-2 cat /var/log/tdb-gateway/audit.jsonl > audit.jsonl
```

Файл в контейнере открывается на добавление и создаётся с правами `0600`.
Каталог для него должен существовать и быть доступен пользователю Gateway;
в этом примере каталог создаёт Docker при подключении volume.

## Изменение настроек аудита

Чтобы изменить настройки первого шлюза, отредактируйте секцию
`config.audit_log` в файле `cluster/grpc-gateway-1.yml`, затем опубликуйте
обновлённую конфигурацию в etcd:

```shell
docker compose -p tdb-grpc-audit -f cluster/docker-compose.yml \
  exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
  /tdb-workers/grpc-audit-example/instances/grpc-gateway-1/grpc-gateway-1 \
  < cluster/grpc-gateway-1.yml
```

Gateway применит настройки без перезапуска. Например, значение `enabled: false`
отключит запись новых событий.

> [!WARNING]
> Если при включённом аудите невозможно открыть файл, шлюз не запустится.
> При неудачной смене пути в работающем шлюзе обновление конфигурации
> будет отклонено, а прежние настройки останутся активными.

## Остановка стенда

Чтобы остановить стенд, выполните в директории примера следующую команду:

```shell
make stop
```

> [!WARNING]
> Команда `make stop` удаляет контейнеры и сеть примера вместе с данными кластера.
> При следующем запуске `make start` исходные данные создаются заново.

> [!NOTE]
> Docker volume с файлом аудита сохраняется после остановки стенда.
> При следующем запуске события будут дописываться в тот же файл.
