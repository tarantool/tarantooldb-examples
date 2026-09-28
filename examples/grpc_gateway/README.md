# Работа с кластером через gRPC Gateway

Доступно с версии Tarantool DB 3.4.0.

В этом примере показано, как запустить gRPC Gateway в качестве узла-обработчика
Tarantool DB и выполнять CRUD-запросы через gRPC.
Конфигурация обработчика хранится в etcd, состояние и метрики доступны в TCM.

Шлюз принимает запросы по gRPC и использует топологию vshard для выбора хранилища.
Роутер используется для начального запуска шардирования и миграций.
На хранилищах включена роль `app.roles.tdb_gateway`, необходимая для `Select`
и постраничной выборки.

## Пререквизиты

Для выполнения примера требуются:

- установленный Docker-образ Tarantool DB;
- Docker Compose и `make`;
- `grpcurl` для выполнения запросов;
- `curl` для просмотра состояния и метрик обработчика.

`grpcurl` получает контракты через включённый в примере gRPC reflection.

## Запуск стенда

Перейдите в каталог примера и запустите стенд:

```shell
cd examples/grpc_gateway
make start
```

Стенд состоит из одного etcd, TCM, одного роутера, двух наборов реплик
по два хранилища и одного gRPC-обработчика. Для компактного примера используется
ручной выбор лидеров (`replication.failover: manual`).

`make start` публикует конфигурацию кластера и обработчика в etcd, запускает
экземпляры Tarantool DB, выполняет bootstrap vshard и миграции, затем запускает
шлюз. В спейсе `test_kv` уже есть 15 записей с `id` от 1 до 15.

| Интерфейс | Адрес |
| --- | --- |
| gRPC | `localhost:9091` |
| Состояние worker | `http://localhost:9081/alive` |
| Версия и информация | `http://localhost:9081/info` |
| Метрики | `http://localhost:9081/metrics` |
| TCM | `http://localhost:8081` |
| Роутер (iproto) | `localhost:3301` |

Порты опубликованы на loopback. В TCM войдите как `admin` с паролем `secret`
и выберите кластер **gRPC example**. Префикс обработчиков уже настроен;
worker `grpc-gateway` должен отображаться в списке узлов-обработчиков.

## Используемые файлы

- `cluster/config.yml` — топология, пользователи и технологические роли кластера;
- `cluster/docker-compose.yml` — экземпляры TDB, контейнер миграций и worker;
- `cluster/migrations/scenario/` — создание спейса и начальных данных;
- `tools/docker-compose.yml` и `tools/tcm.yml` — запуск etcd и настройка TCM;
- `workers/grpc-gateway.yml` — конфигурация обработчика для публикации в etcd;
- `Makefile` — команды управления стендом.

## Конфигурация обработчика

Worker запускается бинарником из поставки TDB. Его переменные окружения:

```yaml
TDB_WORKER_NAME: grpc-gateway
TDB_WORKER_HOST_NAME: grpc-gateway
TDB_WORKER_CONFIG_ETCD_ENDPOINTS: http://etcd:2379
TDB_WORKER_CONFIG_ETCD_PREFIX: /tdb-workers/grpc-example
```

Конфигурация хранится в etcd по ключу:

```text
/tdb-workers/grpc-example/instances/grpc-gateway/grpc-gateway
```

В файле `workers/grpc-gateway.yml` секция `instrumentation` задаёт служебный
HTTP-интерфейс для TCM, а секция `config` — параметры gRPC, логирования и vshard.
`config.vshard.tarantool_cluster_prefix` указывает на `/tdb/config/all`, где
опубликована топология TDB. Ключ шардирования `test_kv` — поле `id`.
При `native_ops: true` операции `Get`, `Insert`, `Replace`, `Update` и `Delete`
выполняются напрямую по iproto. `Select` и пагинация по-прежнему используют
роль `app.roles.tdb_gateway`.

Этот режим рассчитан на неизменное распределение бакетов, как в данном примере.
Если предполагается ребалансировка или перенос бакетов, используйте `native_ops: false`.

Посмотреть опубликованную конфигурацию:

```shell
make show-worker-config
```

После изменения файла повторно опубликовать её:

```shell
make publish-worker-config
```

Worker следит за конфигурацией в etcd. Изменение адреса gRPC или уровня логов
требует перезапуска процесса; изменение состава кластера также требует
перезапуска gateway.

## Выполнение CRUD-запросов

Посмотреть доступные сервисы и описание CRUD API:

```shell
grpcurl -plaintext localhost:9091 list
grpcurl -plaintext localhost:9091 describe service.tdb.crud.v1.Crud
```

Миграция создаёт спейс `test_kv` с полями `id`, `bucket_id`, `name` и `payload`.
`bucket_id` вычисляет gateway; клиенту передавать его не нужно.
Ниже приведены ответы при последовательном выполнении команд на стенде
с исходными данными.

Получить подготовленную запись:

```shell
grpcurl -plaintext -d '{"space":"test_kv","key":{"parts":[1]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Get
```

Пример ответа:

```json
{
  "record": {
    "id": 1,
    "name": "seed-demo-row-01",
    "payload": {
      "source": "grpc-example"
    }
  }
}
```

Создать запись с `id=100`. Повторный `Insert` того же ключа вернёт ошибку;
для повторяемой записи используйте `Replace`:

```shell
grpcurl -plaintext -d '{"space":"test_kv","record":{"id":100,"name":"alice","payload":{"source":"example"}}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Insert
```

Пример ответа:

```json
{
  "record": {
    "id": 100,
    "name": "alice",
    "payload": {
      "source": "example"
    }
  }
}
```

Заменить запись целиком:

```shell
grpcurl -plaintext -d '{"space":"test_kv","record":{"id":100,"name":"alice-replaced","payload":{"source":"example"}}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Replace
```

Пример ответа:

```json
{
  "record": {
    "id": 100,
    "name": "alice-replaced",
    "payload": {
      "source": "example"
    }
  }
}
```

Обновить имя:

```shell
grpcurl -plaintext -d '{"space":"test_kv","key":{"parts":[100]},"operations":[{"field":"name","operator":"PATCH_OPERATOR_SET","value":"bob"}]}' \
  localhost:9091 service.tdb.crud.v1.Crud/Update
```

Пример ответа:

```json
{
  "record": {
    "id": 100,
    "name": "bob",
    "payload": {
      "source": "example"
    }
  }
}
```

Выбрать запись по ключу шардирования — запрос попадёт на один набор реплик:

```shell
grpcurl -plaintext -d '{"space":"test_kv","conditions":[{"field":"id","operator":"COMPARE_OPERATOR_EQ","value":100}],"options":{"limit":1}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Select
```

Пример ответа:

```json
{
  "records": [
    {
      "id": 100,
      "name": "bob",
      "payload": {
        "source": "example"
      }
    }
  ],
  "nextCursor": "g6Zyb3V0ZWSBpWFmdGVygaJpZNBkomZwsDM3ZjY0Y2Q0ZmU3NDNmYzChdgE="
}
```

Удалить запись:

```shell
grpcurl -plaintext -d '{"space":"test_kv","key":{"parts":[100]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Delete
```

Пример ответа:

```json
{
  "deleted": true,
  "record": {
    "id": 100,
    "name": "bob",
    "payload": {
      "source": "example"
    }
  }
}
```

После удаления `Get` по ключу `100` вернёт gRPC-ошибку `NotFound`.

## Постраничная выборка

Выборка по `name` обращается ко всем наборам реплик, поскольку условие не содержит
полного ключа шардирования. Gateway объединяет записи в порядке индекса `name`.

Первая страница:

```shell
grpcurl -plaintext -d '{"space":"test_kv","conditions":[{"field":"name","operator":"COMPARE_OPERATOR_GTE","value":"seed-demo-row-01"}],"options":{"limit":3}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Select
```

Пример ответа:

```json
{
  "records": [
    {
      "id": 1,
      "name": "seed-demo-row-01",
      "payload": {
        "source": "grpc-example"
      }
    },
    {
      "id": 2,
      "name": "seed-demo-row-02",
      "payload": {
        "source": "grpc-example"
      }
    },
    {
      "id": 3,
      "name": "seed-demo-row-03",
      "payload": {
        "source": "grpc-example"
      }
    }
  ],
  "nextCursor": "g6tyZXBsaWNhc2V0c4Kpc3RvcmFnZS0xgaVhZnRlcoKiaWTQAqRuYW1lsHNlZWQtZGVtby1yb3ctMDKpc3RvcmFnZS0ygaVhZnRlcoKkbmFtZbBzZWVkLWRlbW8tcm93LTAzomlk0AOiZnCwNTk2MDVkOTE2MjlkMzllZqF2AQ=="
}
```

Передайте `nextCursor` из ответа в поле `options.cursor` следующего запроса,
сохранив остальные параметры. Значение курсора в примере иллюстративное:
подставляйте `nextCursor` из собственного ответа целиком, без изменений:

```shell
grpcurl -plaintext -d '{"space":"test_kv","conditions":[{"field":"name","operator":"COMPARE_OPERATOR_GTE","value":"seed-demo-row-01"}],"options":{"limit":3,"cursor":"<nextCursor из предыдущего ответа>"}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Select
```

Пример ответа:

```json
{
  "records": [
    {
      "id": 4,
      "name": "seed-demo-row-04",
      "payload": {
        "source": "grpc-example"
      }
    },
    {
      "id": 5,
      "name": "seed-demo-row-05",
      "payload": {
        "source": "grpc-example"
      }
    },
    {
      "id": 6,
      "name": "seed-demo-row-06",
      "payload": {
        "source": "grpc-example"
      }
    }
  ],
  "nextCursor": "g6tyZXBsaWNhc2V0c4Kpc3RvcmFnZS0xgaVhZnRlcoKkbmFtZbBzZWVkLWRlbW8tcm93LTA2omlk0Aapc3RvcmFnZS0ygaVhZnRlcoKkbmFtZbBzZWVkLWRlbW8tcm93LTAzomlk0AOiZnCwNTk2MDVkOTE2MjlkMzllZqF2AQ=="
}
```

Пустой или отсутствующий `nextCursor` означает, что выборка завершена.

## Мониторинг состояния и метрики

```shell
curl -fsS http://localhost:9081/alive
curl -fsS http://localhost:9081/info
curl -fsS http://localhost:9081/metrics | grep '^grpc_gateway_'
make ps
make logs-worker
```

Метрики включают количество запросов, коды ответов, ошибки и задержки по каждому
методу. Обычные логи worker доступны через Docker Compose.

## Остановка стенда

```shell
make stop
```

Команда удаляет контейнеры и сеть только этого примера. Данные находятся внутри
контейнеров; после остановки и нового `make start` исходные данные создаются заново.
