# Ротация логов gRPC Gateway

В этом руководстве описано, как сохранять обычный журнал и аудит gRPC Gateway
в локальные файлы и выполнять их ротацию без перезапуска шлюза.

> [!NOTE]
> Пример доступен с версии Tarantool DB 3.4.0.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Запись событий](#запись-событий)
* [Ротация логов](#ротация-логов)
* [Просмотр файлов после ротации](#просмотр-файлов-после-ротации)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose и утилита `make`;
* утилита `grpcurl` для выполнения запросов;
* утилита `jq` для просмотра и фильтрации JSON-событий;
* исходные файлы примера `grpc_gateway_log_rotation`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `grpc_gateway_log_rotation` расположен в директории `examples/grpc_gateway_log_rotation`.
> * Отдельный архив [grpc_gateway_log_rotation.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgrpc_gateway_log_rotation&filename=grpc_gateway_log_rotation), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301;
* 8081;
* 9081–9082;
* 9091–9092.

Перейдите в директорию примера `grpc_gateway_log_rotation`:

```shell
cd examples/grpc_gateway_log_rotation
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

Выберите кластер **gRPC log rotation example** и откройте вкладку **Stateboard**.
Шлюзы отображаются как `grpc-gateway-1` и `grpc-gateway-2`.

| Шлюз | Адрес gRPC | Каталог журналов на хосте |
| --- | --- | --- |
| `grpc-gateway-1` | `localhost:9091` | `logs/grpc-gateway-1/` |
| `grpc-gateway-2` | `localhost:9092` | `logs/grpc-gateway-2/` |

## Определение конфигурации

Топология, пользователи и роли кластера заданы в файле `cluster/config.yml`.
Миграции из `cluster/migrations/scenario` создают спейс `test_kv`
и заполняют его 8 записями. Чтобы посмотреть их в TCM, откройте вкладку
**Tuples** и выберите `test_kv`.

Настройки шлюзов находятся в `cluster/grpc-gateway-1.yml`
и `cluster/grpc-gateway-2.yml`. При запуске они публикуются в etcd.
В каждом файле настроены два отдельных журнала:

```yaml
config:
  log:
    level: debug
    format: json
    output: /var/log/tdb-gateway/gateway.log
  audit_log:
    enabled: true
    output: /var/log/tdb-gateway/audit.jsonl
```

Секция `log` задаёт уровень, формат и файл обычного журнала.
Уровень `debug` в этом примере позволяет увидеть успешные gRPC-запросы.
Секция `audit_log` включает аудит, который записывается в JSON независимо
от настроек обычного журнала.

Каждому шлюзу в `cluster/docker-compose.yml` подключён собственный каталог
с локального компьютера. Например, для первого шлюза:

```yaml
volumes:
  - ../logs/grpc-gateway-1:/var/log/tdb-gateway
```

Путь слева указан относительно Compose-файла в `cluster/`.
`make start` создаёт каталоги `logs/grpc-gateway-1` и `logs/grpc-gateway-2`
и запускает шлюзы с UID и GID текущего пользователя. Файлы доступны на хосте
без `sudo`; новый файл аудита создаётся с правами `0600`.

> [!NOTE]
> Подключается каталог, а не отдельные файлы: после переименования журнала
> шлюз должен создать новый файл в том же каталоге.

## Запись событий

Все дальнейшие команды выполняются на локальном компьютере
из директории примера. Выполните запрос к первому шлюзу:

```shell
grpcurl -plaintext -H 'request-id: rotation-before' \
  -d '{"space":"test_kv","key":{"parts":[1]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Get
```

Ответ:

```json
{
  "record": {
    "id": 1,
    "name": "seed-rotation-row-01",
    "payload": {
      "source": "grpc-log-rotation-example"
    }
  }
}
```

Найдите запрос в обычном журнале:

```shell
jq 'select(.request_id == "rotation-before") | {level, msg, request_id, code}' \
  logs/grpc-gateway-1/gateway.log
```

Вывод:

```json
{
  "level": "DEBUG",
  "msg": "gRPC request completed",
  "request_id": "rotation-before",
  "code": "OK"
}
```

Найдите тот же запрос в аудите:

```shell
jq 'select(.request_id == "rotation-before") | {request_id, result, code}' \
  logs/grpc-gateway-1/audit.jsonl
```

Вывод:

```json
{
  "request_id": "rotation-before",
  "result": "ok",
  "code": "OK"
}
```

## Ротация логов

Переименуйте оба журнала первого шлюза на локальном компьютере:

```shell
mv -i logs/grpc-gateway-1/gateway.log logs/grpc-gateway-1/gateway.log.1
mv -i logs/grpc-gateway-1/audit.jsonl logs/grpc-gateway-1/audit.jsonl.1
```

> [!NOTE]
> Если файлы с суффиксом `.1` уже существуют от предыдущего запуска примера,
> сохраните их под другим именем перед повторной ротацией.

До переоткрытия шлюз продолжает писать в переименованные файлы.
Отправьте сигнал `SIGUSR1` процессу шлюза:

```shell
docker compose -p tdb-grpc-log-rotation -f cluster/docker-compose.yml \
  kill -s SIGUSR1 grpc-gateway-1
```

Команда отправляет выбранный сигнал основному процессу контейнера.
Gateway переоткрывает обычный журнал и аудит, создавая новые файлы
`gateway.log` и `audit.jsonl`. Контейнер и шлюз продолжают работать.

Дождитесь сообщения о переоткрытии в новом обычном журнале:

```shell
tail -F logs/grpc-gateway-1/gateway.log
```

В выводе появится JSON-событие с полями:

```json
{
  "level": "INFO",
  "msg": "log files reopened"
}
```

Нажмите `Ctrl+C`, чтобы закончить просмотр. Остальные поля события,
например время, зависят от запуска.

> [!WARNING]
> Каталог должен оставаться доступным для записи пользователю Gateway.
> Если переоткрыть файл не удалось, шлюз продолжит писать в прежний файл,
> а ошибку можно увидеть командой `make logs-gateway`. Исправьте причину и отправьте
> `SIGUSR1` повторно.

## Просмотр файлов после ротации

Выполните ещё один запрос, указав новый идентификатор:

```shell
grpcurl -plaintext -H 'request-id: rotation-after' \
  -d '{"space":"test_kv","key":{"parts":[1]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Get
```

Ответ будет таким же, как до ротации. Посмотрите содержимое каталога:

```shell
ls logs/grpc-gateway-1/
```

Вывод:

```text
audit.jsonl  audit.jsonl.1  gateway.log  gateway.log.1
```

В переименованном аудите остался первый запрос:

```shell
jq -r 'select(.request_id | startswith("rotation-")) | .request_id' \
  logs/grpc-gateway-1/audit.jsonl.1
```

Вывод:

```text
rotation-before
```

В новом аудите записан второй запрос:

```shell
jq -r 'select(.request_id | startswith("rotation-")) | .request_id' \
  logs/grpc-gateway-1/audit.jsonl
```

Вывод:

```text
rotation-after
```

Проверьте распределение этих же запросов между файлами обычного журнала:

```shell
jq -r 'select(.request_id? == "rotation-before") | .request_id' \
  logs/grpc-gateway-1/gateway.log.1
jq -r 'select(.request_id? == "rotation-after") | .request_id' \
  logs/grpc-gateway-1/gateway.log
```

Вывод:

```text
rotation-before
rotation-after
```

Для второго шлюза ротация выполняется так же: переименуйте файлы
в `logs/grpc-gateway-2/` и отправьте сигнал контейнеру `grpc-gateway-2`.

> [!NOTE]
> Gateway только переоткрывает файлы по сигналу. Переименование, сжатие,
> срок хранения и удаление старых журналов на сервере можно настроить
> с помощью `logrotate`.

## Остановка стенда

Чтобы остановить стенд, выполните:

```shell
make stop
```

> [!WARNING]
> Команда `make stop` удаляет контейнеры и сеть примера вместе с данными кластера.
> При следующем запуске `make start` исходные данные создаются заново.

> [!NOTE]
> Каталог `logs/`, включая переименованные журналы, сохраняется
> на локальном компьютере. При следующем запуске шлюзы дописывают события
> в `gateway.log` и `audit.jsonl`.
