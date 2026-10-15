# Работа с кластером через gRPC Gateway

В этом руководстве описано, как запустить gRPC-интерфейс Tarantool DB
и выполнять CRUD-запросы. Конфигурация шлюзов хранится в etcd,
состояние и метрики доступны в TCM.

> [!NOTE]
> Пример доступен с версии Tarantool DB 3.4.0.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Выполнение CRUD-запросов](#выполнение-crud-запросов)
* [Постраничная выборка](#постраничная-выборка)
* [Просмотр состояния и метрик](#просмотр-состояния-и-метрик)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose и утилита `make`;
* утилита `grpcurl` для выполнения запросов;
* утилита `curl` для просмотра метрик шлюзов;
* исходные файлы примера `grpc_gateway`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `grpc_gateway` расположен в директории `examples/grpc_gateway`.
> * Отдельный архив [grpc_gateway.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgrpc_gateway&filename=grpc_gateway), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301;
* 8081;
* 9081–9082;
* 9091–9092.

Перейдите в директорию примера `grpc_gateway`:

```shell
cd examples/grpc_gateway
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

Выберите кластер **gRPC example** и откройте вкладку **Stateboard**.
Узлы, предоставляющие gRPC-интерфейс, отображаются как `grpc-gateway-1` и `grpc-gateway-2`.

| Интерфейс | Адрес |
| --- | --- |
| gRPC первого шлюза | `localhost:9091` |
| gRPC второго шлюза | `localhost:9092` |
| Метрики первого шлюза | `http://localhost:9081/metrics` |
| Метрики второго шлюза | `http://localhost:9082/metrics` |
| Роутер (iproto) | `localhost:3301` |

В запросах ниже используется первый шлюз. Для обращения ко второму
замените `localhost:9091` на `localhost:9092`: оба работают с одним кластером.

## Определение конфигурации

Топология, пользователи и роли кластера заданы в файле `cluster/config.yml`.
В примере используется ручной выбор лидеров (`replication.failover: manual`).
Роутер используется для начальной настройки шардирования и применения миграций.
На хранилищах включена роль `app.roles.tdb_gateway`, которая выполняет
запросы шлюзов через vshard.

В файлах `cluster/grpc-gateway-1.yml` и `cluster/grpc-gateway-2.yml`
секция `instrumentation` задаёт служебный HTTP-интерфейс для TCM
(состояние, метрики), а секция `config` - параметры gRPC, логирования и vshard.
Ключ шардирования спейса `books` - поле `id`.
Шлюз использует топологию vshard для выбора хранилища.

При запуске применяются миграции из директории `cluster/migrations/scenario`.
Они создают каталог книг — спейс `books` с полями `id`, `bucket_id`, `title`
и `author` — и добавляют шесть книг. Поле `id` задаёт идентификатор книги,
`title` — название, `author` — автора. Индекс `title` нужен для выборки
книг по названию с постраничным выводом.
Значение `bucket_id` вычисляет шлюз; клиенту передавать его не нужно.

> [!NOTE]
> В примере включён gRPC reflection: утилита `grpcurl` получает описание API
> из запущенного шлюза, поэтому для выполнения запросов не требуются локальные proto-файлы.

> [!NOTE]
> После изменения адреса gRPC, уровня логирования или состава кластера
> необходимо перезапустить шлюзы.

## Выполнение CRUD-запросов

Посмотреть доступные сервисы можно с помощью команды:

```shell
grpcurl -plaintext localhost:9091 list
```

Посмотреть описание команд CRUD API можно так:

```shell
grpcurl -plaintext localhost:9091 describe service.tdb.crud.v1.Crud
```

Proto-контракты можно получить из запущенного шлюза через gRPC reflection.
Следующая команда сохранит определение CRUD API и все его зависимости
в каталог `proto`:

```shell
grpcurl -plaintext -proto-out-dir proto localhost:9091 describe service.tdb.crud.v1.Crud
```

Определение сервиса будет в `proto/service/tdb/crud/v1/service.proto`,
форматы запросов и ответов - в соседних файлах, общие параметры -
в `proto/service/tdb/shared/v1/options.proto`.

Посмотреть содержимое спейса можно в TCM: откройте вкладку **Tuples**
и выберите `books`. Начальных записей меньше десяти, поэтому они помещаются
на одной странице.
Ниже приведены ответы при последовательном выполнении команд на стенде
с исходными данными.

> [!NOTE]
> В ответах `Select` значение `nextCursor` может отличаться от приведённого ниже.
> Это непрозрачный курсор: для следующей страницы используйте значение
> из собственного ответа без изменений.

Прочитать карточку книги «Dune»:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[1]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Get
```

Ответ:

```json
{
  "record": {
    "author": "Frank Herbert",
    "id": 1,
    "title": "Dune"
  }
}
```

Добавить в каталог книгу «A Wizard of Earthsea» с `id=100`:

> [!NOTE]
> Повторный `Insert` того же ключа вернёт ошибку.
> Для замены существующей записи используйте `Replace`.

```shell
grpcurl -plaintext -d '{"space":"books","record":{"id":100,"title":"A Wizard of Earthsea","author":"Ursula Le Guin"}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Insert
```

Ответ:

```json
{
  "record": {
    "author": "Ursula Le Guin",
    "id": 100,
    "title": "A Wizard of Earthsea"
  }
}
```

Заменить карточку целиком, указав иллюстрированное издание:

```shell
grpcurl -plaintext -d '{"space":"books","record":{"id":100,"title":"A Wizard of Earthsea: Illustrated Edition","author":"Ursula Le Guin"}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Replace
```

Ответ:

```json
{
  "record": {
    "author": "Ursula Le Guin",
    "id": 100,
    "title": "A Wizard of Earthsea: Illustrated Edition"
  }
}
```

Уточнить имя автора, изменив только поле `author`:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[100]},"operations":[{"field":"author","operator":"PATCH_OPERATOR_SET","value":"Ursula K. Le Guin"}]}' \
  localhost:9091 service.tdb.crud.v1.Crud/Update
```

Ответ:

```json
{
  "record": {
    "author": "Ursula K. Le Guin",
    "id": 100,
    "title": "A Wizard of Earthsea: Illustrated Edition"
  }
}
```

Выбрать запись по ключу шардирования - запрос попадёт на один набор реплик:

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"id","operator":"COMPARE_OPERATOR_EQ","value":100}],"options":{"limit":1}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Select
```

Ответ:

```json
{
  "records": [
    {
      "author": "Ursula K. Le Guin",
      "id": 100,
      "title": "A Wizard of Earthsea: Illustrated Edition"
    }
  ],
  "nextCursor": "g6Zyb3V0ZWSBpWFmdGVygaJpZNBkomZwsDk1ZjU1YTA2Mzg4NDBkNDehdgE="
}
```

Удалить добавленную карточку из каталога:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[100]}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Delete
```

Ответ:

```json
{
  "deleted": true,
  "record": {
    "author": "Ursula K. Le Guin",
    "id": 100,
    "title": "A Wizard of Earthsea: Illustrated Edition"
  }
}
```

После удаления `Get` по ключу `100` вернёт gRPC-ошибку `NotFound`.

## Постраничная выборка

Выборка по `title` обращается ко всем наборам реплик, поскольку условие не содержит
полного ключа шардирования. Gateway объединяет записи в порядке индекса `title`.

Выберем книги по алфавиту, начиная с «Dune», по три на странице.

Первая страница:

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":"Dune"}],"options":{"limit":3}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Select
```

Ответ:

```json
{
  "records": [
    {
      "author": "Frank Herbert",
      "id": 1,
      "title": "Dune"
    },
    {
      "author": "Ray Bradbury",
      "id": 2,
      "title": "Fahrenheit 451"
    },
    {
      "author": "Isaac Asimov",
      "id": 3,
      "title": "Foundation"
    }
  ],
  "nextCursor": "g6tyZXBsaWNhc2V0c4Kpc3RvcmFnZS0xgaVhZnRlcoKldGl0bGWuRmFocmVuaGVpdCA0NTGiaWTQAqlzdG9yYWdlLTKCpWFmdGVygqJpZNADpXRpdGxlqkZvdW5kYXRpb26kZG9uZcOiZnCwODlhZmVhZDUzNjFkODJjNKF2AQ=="
}
```

Передайте `nextCursor` из ответа в поле `options.cursor` следующего запроса,
сохранив остальные параметры:

> [!NOTE]
> Значение курсора в примере иллюстративное. Вместо `<nextCursor из предыдущего ответа>`
> подставьте `nextCursor` из собственного ответа целиком, без изменений.

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":"Dune"}],"options":{"limit":3,"cursor":"<nextCursor из предыдущего ответа>"}}' \
  localhost:9091 service.tdb.crud.v1.Crud/Select
```

Ответ:

```json
{
  "records": [
    {
      "author": "Stanislaw Lem",
      "id": 4,
      "title": "Solaris"
    },
    {
      "author": "J. R. R. Tolkien",
      "id": 5,
      "title": "The Hobbit"
    },
    {
      "author": "Andy Weir",
      "id": 6,
      "title": "The Martian"
    }
  ],
  "nextCursor": "g6tyZXBsaWNhc2V0c4Kpc3RvcmFnZS0xgaVhZnRlcoKiaWTQBqV0aXRsZatUaGUgTWFydGlhbqlzdG9yYWdlLTKCpWFmdGVygqV0aXRsZapGb3VuZGF0aW9uomlk0AOkZG9uZcOiZnCwODlhZmVhZDUzNjFkODJjNKF2AQ=="
}
```

Пустой или отсутствующий `nextCursor` означает, что выборка завершена.

## Просмотр состояния и метрик

Чтобы просмотреть метрики каждого шлюза, выполните следующие команды:

```shell
curl -fsS http://localhost:9081/metrics | grep '^grpc_gateway_'
curl -fsS http://localhost:9082/metrics | grep '^grpc_gateway_'
```

Метрики включают количество запросов, коды ответов, ошибки и задержки по каждому методу.

Чтобы просмотреть состояние контейнеров, выполните команду:

```shell
make ps
```

Чтобы просмотреть логи шлюзов, выполните команду:

```shell
make logs-gateway
```

Для выхода из просмотра логов нажмите `Ctrl + C`.

## Остановка стенда

Чтобы остановить стенд, выполните в директории примера следующую команду:

```shell
make stop
```

> [!WARNING]
> Команда `make stop` удаляет контейнеры и сеть примера вместе с данными стенда.
> При следующем запуске `make start` исходные данные создаются заново.
