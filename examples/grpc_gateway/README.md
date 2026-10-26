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
* утилита `jq` для обработки страниц выборки;
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
секция `instrumentation` задаёт логирование и служебный HTTP-интерфейс
для TCM (состояние, метрики), а секция `config` — параметры gRPC и vshard.
Ключ шардирования спейса `books` - поле `id`.
Шлюз использует топологию vshard для выбора хранилища.

При запуске применяются миграции из директории `cluster/migrations/scenario`.
Они создают каталог книг — спейс `books` с полями `id`, `bucket_id`, `title`
и `author`. Миграция `002_books.lua` добавляет шесть книг с идентификаторами
от 1 до 6. Миграция `003_book_copies.lua` создаёт ещё 1000 экземпляров этих
книг с идентификаторами от 1000 до 1999. Всего в исходном каталоге 1006 записей;
идентификатор `100` остаётся свободным для CRUD-запросов ниже.

Поле `id` задаёт идентификатор экземпляра, `title` — название книги,
`author` — автора. Разные экземпляры одного произведения имеют одинаковое
название. Индекс `title` включает поля `title` и `id`, поэтому при совпадающих
названиях выборка продолжается по идентификатору экземпляра.
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
grpcurl -plaintext localhost:9091 describe tdb.crud.v1.Crud
```

Proto-контракты можно получить из запущенного шлюза через gRPC reflection.
Следующая команда сохранит определение CRUD API и все его зависимости
в каталог `proto`:

```shell
grpcurl -plaintext -proto-out-dir proto localhost:9091 describe tdb.crud.v1.Crud
```

Определение сервиса будет в `proto/tdb/crud/v1/service.proto`,
форматы запросов и ответов - в соседних файлах, общие параметры -
в `proto/tdb/shared/v1/options.proto`.

Посмотреть содержимое спейса можно в TCM: откройте вкладку **Tuples**
и выберите `books`. Для просмотра 1006 исходных записей используйте
переход между страницами.
Ниже приведены ответы при последовательном выполнении команд на стенде
с исходными данными.

> [!NOTE]
> В ответах `Select` значение `nextCursor` может отличаться от приведённого ниже.
> Это непрозрачный курсор: для следующей страницы используйте значение
> из собственного ответа без изменений.

Прочитать карточку книги «Dune»:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[1]}}' \
  localhost:9091 tdb.crud.v1.Crud/Get
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
  localhost:9091 tdb.crud.v1.Crud/Insert
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
  localhost:9091 tdb.crud.v1.Crud/Replace
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
  localhost:9091 tdb.crud.v1.Crud/Update
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
  localhost:9091 tdb.crud.v1.Crud/Select
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
  localhost:9091 tdb.crud.v1.Crud/Delete
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

Выберем экземпляры книг по алфавиту, начиная с «Dune», по три на странице.
При одинаковом названии экземпляры упорядочены по `id`. Первые страницы содержат
разные экземпляры «Dune»: это позволяет проверить продолжение выборки внутри
одного названия.

Первая страница:

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":"Dune"}],"options":{"limit":3}}' \
  localhost:9091 tdb.crud.v1.Crud/Select
```

Ответ (`nextCursor` показан условно):

```json
{
  "records": [
    {
      "author": "Frank Herbert",
      "id": 1,
      "title": "Dune"
    },
    {
      "author": "Frank Herbert",
      "id": 1000,
      "title": "Dune"
    },
    {
      "author": "Frank Herbert",
      "id": 1006,
      "title": "Dune"
    }
  ],
  "nextCursor": "<курсор продолжения из ответа>"
}
```

Передайте `nextCursor` из ответа в поле `options.cursor` следующего запроса,
сохранив `space` и `conditions`. Размер страницы `limit` можно менять между
запросами: например, после 30 записей запросить следующие 300 или 3.
В командах ниже оставим по три записи на странице:

> [!NOTE]
> Значение курсора в примере иллюстративное. Вместо `<nextCursor из предыдущего ответа>`
> подставьте `nextCursor` из собственного ответа целиком, без изменений.

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":"Dune"}],"options":{"limit":3,"cursor":"<nextCursor из предыдущего ответа>"}}' \
  localhost:9091 tdb.crud.v1.Crud/Select
```

Ответ (`nextCursor` показан условно):

```json
{
  "records": [
    {
      "author": "Frank Herbert",
      "id": 1012,
      "title": "Dune"
    },
    {
      "author": "Frank Herbert",
      "id": 1018,
      "title": "Dune"
    },
    {
      "author": "Frank Herbert",
      "id": 1024,
      "title": "Dune"
    }
  ],
  "nextCursor": "<курсор продолжения из ответа>"
}
```

Пустой или отсутствующий `nextCursor` означает, что выборка завершена.

### Обход всего каталога

Чтобы пройти всю выборку, увеличьте размер страницы до 100 и передавайте
полученный курсор в следующий запрос. Команды ниже выводят размер каждой
страницы и её первую и последнюю записи:

```shell
request='{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":"Dune"}],"options":{"limit":100}}'

while :; do
    response=$(grpcurl -plaintext -d "$request" \
        localhost:9091 tdb.crud.v1.Crud/Select) || break
    printf '%s\n' "$response" | jq '{count: (.records | length), first: .records[0], last: .records[-1]}'
    cursor=$(printf '%s\n' "$response" | jq -r '.nextCursor // empty')
    [ -n "$cursor" ] || break
    request=$(jq -cn --argjson request "$request" --arg cursor "$cursor" \
        '$request | .options.cursor = $cursor')
done
```

На исходных данных получится 11 страниц: десять по 100 записей и последняя
из 6 записей. `limit` ограничивает размер одной страницы. Для просмотра каждой
записи замените фильтр `jq` на `.records[] | {id, title, author}`.

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
