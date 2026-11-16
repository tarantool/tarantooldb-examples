# Работа с кластером через gRPC Gateway

Пример доступен с версии Tarantool DB 3.4.0.

В этом руководстве описано, как запустить gRPC-интерфейс Tarantool DB
и выполнять CRUD-запросы. Конфигурация шлюзов хранится в etcd,
состояние и метрики доступны в веб-интерфейсе TCM.
Вариант с хранением конфигурации в TBCS приведён в [отдельном примере](../grpc_gateway_tbcs/README.md).

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

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB версии 3.4.0 или выше;
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

Топология, пользователи и [технологические роли](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/model/roles) кластера заданы в конфигурационном файле `cluster/config.yml`.
В примере:

- задан ручной выбор лидеров (`replication.failover: manual`);
- роутер используется для начальной настройки шардирования и применения миграций;
- на хранилищах включена технологическая роль `app.roles.tdb_gateway`, которая выполняет
  запросы шлюзов через модуль шардирования vshard.

В файлах конфигурации `cluster/grpc-gateway-1.yml` и `cluster/grpc-gateway-2.yml`:

- секция `instrumentation` описывает служебный HTTP-интерфейс для TCM;
- параметр `config.roles.httpd.instrumentation.listen` задаёт адрес прослушивания этого интерфейса;
- секция `config.log` задаёт журнал событий, а `config.audit_log` — журнал аудита;
- секции `config.server` и `config.vshard` определяют параметры gRPC и vshard.

Ключ шардирования спейса `books` — это поле `id`.
Шлюз использует топологию vshard для выбора хранилища. Без явного фильтра
он выбирает экземпляры с наследуемой ролью `storage`. Для явного выбора групп
задаётся `config.vshard.storages_groups: [storage-1, storage-2]`. Одну группу
укажите списком из одного элемента: `config.vshard.storages_groups: [storage-1]`.
Если список не задан и экземпляров с ролью `storage` нет, шлюз завершит запуск с ошибкой.

При запуске применяются миграции из директории `cluster/migrations/scenario`.
Первая миграция (`001_books.lua`) создаёт каталог книг: спейс `books` с полями `id`, `bucket_id`, `title`
и `author`. Миграция `002_books.lua` добавляет шесть книг с идентификаторами
от 1 до 6. Миграция `003_book_copies.lua` создаёт ещё 1000 экземпляров этих
книг с идентификаторами от 1000 до 1999. Всего в исходном каталоге 1006 записей;
идентификатор `100` остаётся свободным для CRUD-запросов ниже.

Поле `id` задаёт идентификатор экземпляра, `title` — название книги,
`author` — автора. Разные экземпляры одного произведения имеют одинаковое
название. Индекс `title` включает поля `title` и `id`, поэтому при совпадающих
названиях выборка продолжается по идентификатору экземпляра.
Значение `bucket_id` вычисляет шлюз, клиенту передавать его не нужно.

> [!NOTE]
> В примере включён gRPC reflection: утилита `grpcurl` получает описание API
> из запущенного шлюза, поэтому для выполнения запросов не требуются локальные proto-файлы.
>
> Изменения журнала аудита и параметров vshard применяются без перезапуска.
> Изменение журнала событий, адреса gRPC или подключения к хранилищу
> конфигурации требует перезапуска шлюзов.

## Выполнение CRUD-запросов

Посмотреть доступные сервисы можно с помощью команды ниже:

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

Посмотреть содержимое спейса можно в TCM. Для этого откройте вкладку **Tuples**
и выберите спейс `books`. Для просмотра 1006 исходных записей используйте
переход между страницами.
Ниже приведены ответы при последовательном выполнении команд на стенде
с исходными данными.

> [!NOTE]
> Значение `nextCursor` в ответах `Select` может отличаться от приведённого ниже.
> Это непрозрачный курсор: для следующей страницы используйте значение
> из собственного ответа без изменений.

Прочитайте карточку книги `Dune`:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9091 tdb.crud.v1.Crud/Get
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

Теперь добавьте в каталог книгу «A Wizard of Earthsea» с идентификатором `id=100`:

```shell
grpcurl -plaintext -d '{"space":"books","record":{"fields":{"id":{"uintValue":"100"},"title":{"stringValue":"A Wizard of Earthsea"},"author":{"stringValue":"Ursula Le Guin"}}}}' \
  localhost:9091 tdb.crud.v1.Crud/Insert
```

Ответ:

```json
{
  "record": {
    "fields": {
      "author": {
        "stringValue": "Ursula Le Guin"
      },
      "id": {
        "intValue": "100"
      },
      "title": {
        "stringValue": "A Wizard of Earthsea"
      }
    }
  }
}
```

> [!NOTE]
> Повторная вставка (`Insert`) того же ключа вернёт ошибку.
> Для замены существующей записи используйте операцию `Replace`.

Теперь замените описание книги целиком, указав иллюстрированное издание:

```shell
grpcurl -plaintext -d '{"space":"books","record":{"fields":{"id":{"uintValue":"100"},"title":{"stringValue":"A Wizard of Earthsea: Illustrated Edition"},"author":{"stringValue":"Ursula Le Guin"}}}}' \
  localhost:9091 tdb.crud.v1.Crud/Replace
```

Ответ:

```json
{
  "record": {
    "fields": {
      "author": {
        "stringValue": "Ursula Le Guin"
      },
      "id": {
        "intValue": "100"
      },
      "title": {
        "stringValue": "A Wizard of Earthsea: Illustrated Edition"
      }
    }
  }
}
```

Уточните имя автора, изменив только поле `author`:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[{"uintValue":"100"}]},"operations":[{"field":"author","operator":"PATCH_OPERATOR_SET","value":{"stringValue":"Ursula K. Le Guin"}}]}' \
  localhost:9091 tdb.crud.v1.Crud/Update
```

Ответ:

```json
{
  "record": {
    "fields": {
      "author": {
        "stringValue": "Ursula K. Le Guin"
      },
      "id": {
        "intValue": "100"
      },
      "title": {
        "stringValue": "A Wizard of Earthsea: Illustrated Edition"
      }
    }
  }
}
```

Выберите запись по ключу шардирования. Такой запрос попадёт на один набор реплик:

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"id","operator":"COMPARE_OPERATOR_EQ","value":{"uintValue":"100"}}],"options":{"limit":1}}' \
  localhost:9091 tdb.crud.v1.Crud/Select
```

Ответ:

```json
{
  "records": [
    {
      "fields": {
        "author": {
          "stringValue": "Ursula K. Le Guin"
        },
        "id": {
          "intValue": "100"
        },
        "title": {
          "stringValue": "A Wizard of Earthsea: Illustrated Edition"
        }
      }
    }
  ],
  "nextCursor": "g6Zyb3V0ZWSBpWFmdGVygaJpZNBkomZwsDk1ZjU1YTA2Mzg4NDBkNDehdgE="
}
```

Удалите добавленную карточку из каталога:

```shell
grpcurl -plaintext -d '{"space":"books","key":{"parts":[{"uintValue":"100"}]}}' \
  localhost:9091 tdb.crud.v1.Crud/Delete
```

Ответ:

```json
{
  "deleted": true,
  "record": {
    "fields": {
      "author": {
        "stringValue": "Ursula K. Le Guin"
      },
      "id": {
        "intValue": "100"
      },
      "title": {
        "stringValue": "A Wizard of Earthsea: Illustrated Edition"
      }
    }
  }
}
```

После удаления запрос `Get` по ключу `100` вернёт gRPC-ошибку `NotFound`.

## Постраничная выборка

Выборка по заголовку книги (полю `title`) обращается ко всем наборам реплик, поскольку условие не содержит
полного ключа шардирования. Gateway объединяет записи в порядке индекса `title`.

Выберите экземпляры книг по алфавиту, начиная с «Dune», по три на странице.
При одинаковом названии экземпляры упорядочены по `id`. Первые страницы содержат
разные экземпляры «Dune»: это позволяет проверить продолжение выборки внутри
одного названия.

Первая страница:

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":{"stringValue":"Dune"}}],"options":{"limit":3}}' \
  localhost:9091 tdb.crud.v1.Crud/Select
```

Ответ (`nextCursor` показан условно):

```json
{
  "records": [
    {
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
    },
    {
      "fields": {
        "author": {
          "stringValue": "Frank Herbert"
        },
        "id": {
          "uintValue": "1000"
        },
        "title": {
          "stringValue": "Dune"
        }
      }
    },
    {
      "fields": {
        "author": {
          "stringValue": "Frank Herbert"
        },
        "id": {
          "uintValue": "1006"
        },
        "title": {
          "stringValue": "Dune"
        }
      }
    }
  ],
  "nextCursor": "<курсор продолжения из ответа>"
}
```

Передайте `nextCursor` из ответа в поле `options.cursor` следующего запроса,
сохранив значения `space` и `conditions`. Размер страницы `limit` можно менять между
запросами: например, после 30 записей запросить следующие 300 или 3.
В командах ниже оставим по три записи на странице:

> [!NOTE]
> Значение курсора в примере иллюстративное. Вместо `<nextCursor из предыдущего ответа>`
> подставьте `nextCursor` из собственного ответа целиком, без изменений.

```shell
grpcurl -plaintext -d '{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":{"stringValue":"Dune"}}],"options":{"limit":3,"cursor":"<nextCursor из предыдущего ответа>"}}' \
  localhost:9091 tdb.crud.v1.Crud/Select
```

Ответ (`nextCursor` показан условно):

```json
{
  "records": [
    {
      "fields": {
        "author": {
          "stringValue": "Frank Herbert"
        },
        "id": {
          "uintValue": "1012"
        },
        "title": {
          "stringValue": "Dune"
        }
      }
    },
    {
      "fields": {
        "author": {
          "stringValue": "Frank Herbert"
        },
        "id": {
          "uintValue": "1018"
        },
        "title": {
          "stringValue": "Dune"
        }
      }
    },
    {
      "fields": {
        "author": {
          "stringValue": "Frank Herbert"
        },
        "id": {
          "uintValue": "1024"
        },
        "title": {
          "stringValue": "Dune"
        }
      }
    }
  ],
  "nextCursor": "<курсор продолжения из ответа>"
}
```

Пустой или отсутствующий `nextCursor` означает, что выборка завершена.
Пагинация не фиксирует общий snapshot: при изменении данных или переносе
бакетов между страницами возможны дубликаты и пропуски.

### Обход всего каталога

Чтобы пройти всю выборку, увеличьте размер страницы до 100 и передавайте
полученный курсор в следующий запрос. Команды ниже выводят размер каждой
страницы и её первую и последнюю записи:

```shell
request='{"space":"books","conditions":[{"field":"title","operator":"COMPARE_OPERATOR_GTE","value":{"stringValue":"Dune"}}],"options":{"limit":100}}'

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
из 6 записей. Параметр `limit` ограничивает размер одной страницы. Для просмотра каждой
записи замените фильтр `jq` на:

```jq
.records[].fields | {id: (.id.uintValue // .id.intValue), title: .title.stringValue, author: .author.stringValue}
```

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

Чтобы просмотреть журнал событий шлюзов, выполните команду:

```shell
make logs-gateway
```

Для выхода из просмотра журнала нажмите `Ctrl + C`.

## Остановка стенда

Чтобы остановить стенд, выполните в директории примера следующую команду:

```shell
make stop
```

Команда `make stop` удаляет контейнеры и сеть примера вместе с данными стенда.
При следующем запуске `make start` исходные данные создаются заново.
