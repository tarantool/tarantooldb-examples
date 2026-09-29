# Работа с gRPC-интерфейсом Tarantool DB из Go

В этом руководстве описано, как сохранить proto-контракты из gRPC Gateway,
сгенерировать по ним Go-код и использовать его в клиентском приложении.
Приложение создаёт, читает, изменяет и удаляет записи в собственном кластере Tarantool DB.

> [!NOTE]
> Пример доступен с версии Tarantool DB 3.4.0.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Сохранение proto-контрактов](#сохранение-proto-контрактов)
* [Генерация Go-кода](#генерация-go-кода)
* [Запуск приложения](#запуск-приложения)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose и утилита `make`;
* Go версии 1.24 или выше;
* компилятор [Protocol Buffers (`protoc`)](https://protobuf.dev/installation/);
* утилита `grpcurl` для сохранения контрактов;
* исходные файлы примера `go_grpc`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `go_grpc` расположен в директории `examples/go_grpc`.
> * Отдельный архив [go_grpc.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgo_grpc&filename=go_grpc), скачанный из этого репозитория.

> [!NOTE]
> Компилятор `protoc` устанавливается отдельно от Go-плагинов `protoc-gen-go`
> и `protoc-gen-go-grpc`. Перед генерацией кода он должен быть доступен через `PATH`.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301;
* 8081;
* 9081–9082;
* 9091–9092.

Перейдите в директорию примера `go_grpc`:

```shell
cd examples/go_grpc
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

Выберите кластер **Go gRPC example** и откройте вкладку **Stateboard**.
Узлы, предоставляющие gRPC-интерфейс, отображаются как `grpc-gateway-1` и `grpc-gateway-2`.

| Интерфейс | Адрес |
| --- | --- |
| gRPC первого шлюза | `localhost:9091` |
| gRPC второго шлюза | `localhost:9092` |
| Метрики первого шлюза | `http://localhost:9081/metrics` |
| Метрики второго шлюза | `http://localhost:9082/metrics` |
| Роутер (iproto) | `localhost:3301` |

## Определение конфигурации

Топология, пользователи и роли кластера заданы в файле `cluster/config.yml`.
Параметры шлюзов находятся в файлах `cluster/grpc-gateway-1.yml`
и `cluster/grpc-gateway-2.yml`. В обоих файлах указаны следующие параметры:

```yaml
config:
  server:
    grpc_addr: 0.0.0.0:9090
    enable_reflection: true
  vshard:
    spaces:
      books:
        sharding_key: [id]
```

Здесь:

* `grpc_addr` — адрес gRPC-интерфейса внутри контейнера;
* `enable_reflection` — включает получение proto-контрактов из запущенного шлюза;
* `sharding_key` — поля ключа шардирования спейса `books`.

При запуске применяется миграция `cluster/migrations/scenario/001_books.lua`.
Она создаёт пустой спейс `books` с полями `id`, `bucket_id`, `title` и `author`.
Ключ шардирования — `id`; значение `bucket_id` вычисляет шлюз.
В веб-интерфейсе TCM откройте вкладку **Tuples** и выберите спейс `books`.

## Сохранение proto-контрактов

Перейдите из директории примера в директорию клиентского приложения:

```shell
cd go
```

Сохраните описание CRUD API и все его зависимости из запущенного шлюза:

```shell
grpcurl -plaintext -proto-out-dir proto localhost:9091 describe service.tdb.crud.v1.Crud
```

Файлы появятся в директории `proto`:

* `service/tdb/crud/v1/service.proto` — сервис CRUD и его методы;
* остальные файлы в `service/tdb/crud/v1/` — сообщения запросов и ответов;
* `service/tdb/shared/v1/options.proto` — параметры выполнения запросов;
* `google/protobuf/struct.proto` — стандартные типы для представления записей.

> [!NOTE]
> Reflection используется только для получения схем. Сгенерированный Go-клиент
> работает без reflection. Директории `go/proto` и `go/gen` исключены из Git.

## Генерация Go-кода

В директории `go` установите плагины для `protoc`:

```shell
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.11
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
export PATH="$(go env GOPATH)/bin:$PATH"
```

Запустите генерацию:

```shell
bash generate.sh
```

В директории `gen` появятся Go-типы сообщений и gRPC-клиент `CrudClient`.
Скрипт использует параметры `M` компилятора, чтобы сопоставить пути proto-файлов
с пакетами локального модуля `example.com/tdb-go-grpc`. Это переопределяет
`go_package` из экспортированных контрактов: Go-код генерируется внутри примера.

> [!NOTE]
> Если меняете имя модуля, обновите `go.mod`, переменную `module` в `generate.sh`
> и импорты в `main.go`.

Подробнее о плагинах и параметрах генерации:
[Go quick start](https://grpc.io/docs/languages/go/quickstart/) и
[Go Generated Code Guide](https://protobuf.dev/reference/go/go-generated/).

## Запуск приложения

В директории `go` запустите Go-приложение:

```shell
go run .
```

Приложение подключается к `localhost:9091` и выполняет `Insert`, `Get`,
`Replace`, `Update`, `Select` и `Delete` для записи с `id=1` в спейсе `books`.

Вывод после окончания работы приложения выглядит так:

```text
Insert: First edition
Get: First edition
Replace: Second edition
Update: Revised edition
Select: 1 record(s)
Delete: true
```

> [!NOTE]
> После успешного выполнения запись удаляется, поэтому приложение можно запустить
> повторно. Если запись `id=1` уже существует, `Insert` завершится ошибкой;
> приложение не будет заменять существующие данные.

Для обращения ко второму шлюзу:

```shell
go run . -addr localhost:9092
```

В `main.go` подключение создаётся через `grpc.NewClient`, а методы вызываются
через сгенерированный `pb.NewCrudClient`. Формат записей в контракте задан
как `google.protobuf.Struct`, поэтому поля книги передаются через `structpb`.
Каждая ошибка RPC возвращается вызывающему коду с названием операции.

> [!NOTE]
> После изменения контрактов снова сохраните proto из используемой версии шлюза
> и выполните `bash generate.sh`.

## Остановка стенда

Чтобы остановить стенд, вернитесь из директории `go` в директорию примера
и выполните команду `make stop`:

```shell
cd ..
make stop
```

> [!WARNING]
> Команда `make stop` удаляет контейнеры и сеть примера вместе с данными стенда.
> Сохранённые proto-файлы и сгенерированный Go-код остаются локально.
