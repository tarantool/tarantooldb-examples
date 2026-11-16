# Вход в gRPC Gateway через LDAP

Пример доступен с версии Tarantool DB 3.4.0.

В этом руководстве описано, как запустить LDAP-обработчик (*worker*) вместе с Tarantool DB,
войти в gRPC Gateway с паролем из LDAP и задать права доступа по группам.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Определение конфигурации](#определение-конфигурации)
* [Вход и выполнение запросов](#вход-и-выполнение-запросов)
* [Проверка отказов](#проверка-отказов)
* [Изменение прав доступа](#изменение-прав-доступа)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* Docker Compose, GNU Make, Bash и OpenSSL;
* утилиты `grpcurl` и `jq`;
* исходные файлы примера `grpc_gateway_ldap`;
* доступ к registry для загрузки образов OpenLDAP и etcd.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
>
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример расположен в директории `examples/grpc_gateway_ldap`.
> * Отдельный архив [grpc_gateway_ldap.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgrpc_gateway_ldap&filename=grpc_gateway_ldap), скачанный из этого репозитория.

## Запуск стенда

Освободите порты 3301, 8081, 9081–9082 и 9091–9092. Перейдите в директорию примера:

```shell
cd examples/grpc_gateway_ldap
make start
```

Стенд состоит из:

* кластера TDB: 1 роутер и 2 набора реплик по 2 хранилища;
* 2 экземпляров gRPC Gateway;
* LDAP-обработчика и сервера OpenLDAP;
* etcd;
* веб-интерфейса Tarantool Cluster Manager (TCM).

Контейнер `init_host` настраивает шардирование и применяет миграции, после чего
удаляется. Миграции создают спейс `books` с шестью книгами, включая «Dune».

Команда `make start` создаёт:

- учебный CA;
- TLS-сертификаты;
- общий ключ подписи пользовательских токенов.

Они находятся в директории `_local/`, которая исключена из Git. При повторном запуске существующие ключи
и сертификаты сохраняются. Дескриптор `_local/api.protoset` собирается из
proto-файлов каталога `proto/` через `grpcurl`, Go и `protoc` не требуются.

TCM доступен по адресу [http://localhost:8081](http://localhost:8081).
Войдите как `admin` с паролем `secret` и выберите кластер **gRPC LDAP example**.

> [!WARNING]
> Пароли в примере учебные. Не используйте их и созданный CA-сертификат в рабочей среде.
> OpenLDAP и API LDAP-обработчика доступны только внутри сети Docker Compose.
> Соединения клиента со шлюзом, шлюза с LDAP-обработчиком и LDAP-обработчика с OpenLDAP
> защищены TLS. Соединения с etcd и TDB в этом локальном стенде не зашифрованы.

## Определение конфигурации

Файл `cluster/config.yml` задаёт топологию и служебных пользователей TDB.
На хранилищах включена [технологическая роль](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/model/roles) `app.roles.tdb_gateway`.

Пользователь `alice` с паролем `alice-pass` и группа `readers` создаются в
OpenLDAP из файла `cluster/bootstrap.ldif`. Это отдельный каталог пользователей,
LDAP-обработчик не создаёт их сам. Настройки подключения к LDAP находятся в
файле `cluster/ldap-worker.yml`: адрес сервера, учётная запись для поиска,
базовый DN и шаблоны поиска пользователей и групп.

Gateway отправляет логин и пароль в HTTPS API LDAP-обработчика. Обработчик проверяет
их через OpenLDAP и возвращает группы пользователя. Gateway сопоставляет
группы с правами и выдаёт подписанный пользовательский токен.

Конфигурация Gateway задаётся в файлах `cluster/grpc-gateway-1.yml` и
`cluster/grpc-gateway-2.yml`. Основные параметры в секции `config.auth` приведены ниже:

```yaml
session_ttl: 5m
token_audience: grpc-ldap-example
mapping:
  cn=readers,ou=groups,dc=example,dc=com:
    Get: [books]
    Select: [books]
```

Секция конфигурации `mapping` сопоставляет полный DN группы LDAP с разрешёнными gRPC-методами и
спейсами. Группа `readers` может читать книги, используя операции `Get` и `Select`.
Группа не имеет доступа к другим спейсам и разрешения на выполнение остальных операций.

Оба шлюза используют одинаковые ключ подписи, `token_audience` и настройки прав.
Это означает, что токен, выданный одним шлюзом, принимается и вторым.

В примере шлюз проверяет сертификат LDAP-обработчика по `auth.worker_ca_file`.
Чтобы LDAP-обработчик также проверял шлюз (mTLS), задайте на обработчике
`config.roles.httpd.ldap.ssl_ca_file` с CA клиентских сертификатов. На обоих шлюзах
укажите `auth.worker_cert_file` и `auth.worker_key_file` с клиентским сертификатом
(назначение `clientAuth`) и его закрытым ключом.

## Вход и выполнение запросов

Все команды выполняются из директории примера. Войдите через первый шлюз:

```shell
umask 077
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -d '{"login":"alice","password":"alice-pass"}' \
  localhost:9091 tdb.auth.v1.Auth/Login > _local/session.json
TOKEN=$(jq -er '.token' _local/session.json)
```

Ответ содержит поля `token` и `expiresAtUnix` (момент истечения срока действия токена в Unix-секундах).
Reflection отключён: `grpcurl` использует локальный дескриптор API.

Прочитайте книгу через второй шлюз с полученным токеном:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -H "authorization: Bearer $TOKEN" \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9092 tdb.crud.v1.Crud/Get
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
        "stringValue": "Dune"
      },
      "author": {
        "stringValue": "Frank Herbert"
      }
    }
  }
}
```

С тем же токеном запросите каталог книг:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -H "authorization: Bearer $TOKEN" \
  -d '{"space":"books","options":{"limit":10}}' \
  localhost:9091 tdb.crud.v1.Crud/Select | jq '.records | length'
```

Результат равен `6`. После истечения пяти минут запросы с этим токеном возвращают
`Unauthenticated`. Чтобы получить новый токен, повторите вход.

> [!WARNING]
> Немедленного отзыва токена нет. Изменение пароля или группы пользователя в LDAP
> не отзывает уже выданный токен, он действует до истечения срока.

## Проверка отказов

Неверный пароль:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -d '{"login":"alice","password":"wrong"}' \
  localhost:9091 tdb.auth.v1.Auth/Login
```

Неизвестный пользователь:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -d '{"login":"nobody","password":"alice-pass"}' \
  localhost:9091 tdb.auth.v1.Auth/Login
```

Оба запроса возвращают код `Unauthenticated`.

Повреждённый токен:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -H "authorization: Bearer ${TOKEN}x" \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9092 tdb.crud.v1.Crud/Get
```

Запрос также возвращает код `Unauthenticated`. Запрос без заголовка `authorization` завершается
тем же кодом.

Попытка удалить книгу с действующим токеном:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -H "authorization: Bearer $TOKEN" \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]}}' \
  localhost:9092 tdb.crud.v1.Crud/Delete
```

В результате возвращается код `PermissionDenied`: вход выполнен, но права на удаление нет.
Книга остаётся в каталоге. Чтение другого спейса также вернёт код `PermissionDenied`.

## Изменение прав доступа

Разрешите группе `readers` менять карточки книг. В **обоих** файлах
`cluster/grpc-gateway-1.yml` и `cluster/grpc-gateway-2.yml` в секции `mapping` добавьте `Update`:

```yaml
mapping:
  cn=readers,ou=groups,dc=example,dc=com:
    Get: [books]
    Select: [books]
    Update: [books]
```

Опубликуйте конфигурации и пересоздайте обработчики:

```shell
make restart-workers
```

Команда сохраняет данные TDB, LDAP и etcd.

Войдите заново, чтобы обновить переменную `TOKEN`:

```shell
umask 077
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -d '{"login":"alice","password":"alice-pass"}' \
  localhost:9091 tdb.auth.v1.Auth/Login > _local/session.json
TOKEN=$(jq -er '.token' _local/session.json)
```

Затем выполните команду ниже:

```shell
grpcurl -cacert _local/ca/ca.crt -protoset _local/api.protoset \
  -H "authorization: Bearer $TOKEN" \
  -d '{"space":"books","key":{"parts":[{"uintValue":"1"}]},"operations":[{"field":"title","operator":"PATCH_OPERATOR_SET","value":{"stringValue":"Dune (revised edition)"}}]}' \
  localhost:9092 tdb.crud.v1.Crud/Update
```

Ответ содержит книгу с заголовком `Dune (revised edition)`. До добавления права
этот запрос завершался бы `PermissionDenied`. Чтобы запретить обновления,
удалите `Update` из обоих файлов и снова выполните команду `make restart-workers`.

Пользователей и членство в группах можно менять в файле `cluster/bootstrap.ldif`.
Этот файл применяется при создании OpenLDAP. Для повторной загрузки начальных
данных выполните `make stop`, затем `make start`: данные всего стенда будут
созданы заново.

## Остановка стенда

```shell
make stop
```

> [!WARNING]
> Команда удаляет контейнеры и сеть примера вместе с данными кластера и LDAP.
> Каталог `_local/` с ключами, сертификатами и сохранённым токеном остаётся на хосте.
> Учебные сертификаты действуют 30 дней. После их истечения остановите стенд,
> удалите `_local/` и запустите пример заново для создания новых сертификатов.
