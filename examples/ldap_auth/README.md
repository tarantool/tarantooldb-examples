# Аутентификация через LDAP

Доступно с версии TDB 3.4.0.

В этом руководстве показано, как настроить аутентификацию клиентов Tarantool DB
в LDAP-каталогах (OpenLDAP и Active Directory) с помощью технологической роли
`app.roles.tdb_ldap_auth` и LDAP-обработчика, а затем подключиться к кластеру
из Go с помощью библиотеки `go-tarantool`.

> [!IMPORTANT]
> Пример упрощает настройку ради наглядности и не подходит для продуктивного
> использования без изменений:
> * `pap-sha256` передаёт пароль в пакете `AUTH` открытым текстом, поэтому
>   слушатель роутера обязан работать через SSL — в примере, для простоты,
>   используется обычный TCP-порт 3301;
> * соединения LDAP-обработчиков с каталогами не шифруются (`tls.enabled: false`,
>   `INSECURE_LDAP=true` у AD);
> * пароли и DN сервисных аккаунтов лежат в конфигурационных файлах примера.
>
> Как настроить SSL-соединения, показано в примере
> [traffic_encryption](../traffic_encryption/README.md).

В стенде два LDAP-каталога:

| Каталог | Пользователь | Группа | Права на спейс `orders` |
|---|---|---|---|
| OpenLDAP | `alice` / `alice-pass` | `cn=readers,ou=groups,dc=example,dc=com` | чтение |
| Active Directory (smblds) | `bob` / `BobPassw0rd!` | `CN=tdb-writers,CN=Users,DC=samdom,DC=example,DC=com` | чтение и запись |

Содержание:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Как это работает](#как-это-работает)
* [Запуск приложения](#запуск-приложения)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker)
  Tarantool DB версии 3.4.0 или выше (в примере используется образ
  `tarantooldb:3.4.0-rc1-28-g5b1491c5`; роль `app.roles.tdb_ldap_auth`
  и бинарник LDAP-обработчика входят в образ);
* Docker-образы `osixia/openldap:1.5.0`, `smblds/smblds:latest` и
  `quay.io/coreos/etcd:v3.5.15`;
* приложение Docker Compose;
* утилита `openssl` (генерация сертификатов);
* компилятор Go;
* свободные порты 2379 и 3301.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
> * Репозиторий [tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `ldap_auth` расположен в директории `examples/ldap_auth`.
> * Отдельный архив [ldap_auth.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fldap_auth&filename=ldap_auth), скачанный из этого репозитория.

## Используемые файлы

* `certs/gen.sh` — генерация CA и сертификата LDAP-обработчиков;
* `tools/docker-compose.yml` — etcd из одного узла для хранения конфигураций кластера
  и обработчиков, а также одноразовый сервис `tt-tools` для публикации
  кластерной конфигурации;
* `ldap/docker-compose.yml` — каталоги OpenLDAP и Active Directory;
* `ldap/openldap/bootstrap.ldif` — пользователь `alice` и группа `readers`;
* `ldap/ad/entrypoint.d/01-users.sh` — пользователь `bob` и группа
  `tdb-writers` (создаются `samba-tool` при старте контейнера AD);
* `workers/openldap-worker.yml`, `workers/ad-worker.yml` — конфигурации
  LDAP-обработчиков, которые публикуются в etcd;
* `workers/docker-compose.yml` — два LDAP-обработчика (по одному на каталог);
* `cluster/config.yml` — конфигурация кластера: служебный пользователь
  `tdb_ldap_auth` и технологическая роль `app.roles.tdb_ldap_auth` с параметрами `worker_directories`
  и `mapping`;
* `cluster/migrations/scenario/001_init.lua` — шардированный спейс `orders`;
* `cluster/docker-compose.yml` — роутер, хранилище и задача начальной
  инициализации;
* `go/main.go` — Go-клиент с аутентификацией `pap-sha256`.

## Запуск стенда

Перейдите в директорию примера `ldap_auth`:

```shell
cd examples/ldap_auth
```

Стенд состоит из:

* кластера Tarantool DB (1 роутер с ролью `app.roles.tdb_ldap_auth`,
  1 экземпляр хранилища);
* кластера etcd из 1 узла;
* 2 узлов-обработчиков LDAP;
* двух каталогов (OpenLDAP, AD).

Запустите стенд:

```shell
make start
```

Команда `make start` публикует в etcd конфигурации кластера (`tt cluster
publish`) и LDAP-обработчиков (`etcdctl put`), запускает все слои
стенда, а затем выполняет начальную инициализацию кластера через команду `tt replicaset vshard
bootstrap` и применяет миграции. Проверить успешное завершение инициализации можно
в логах:

```shell
docker compose -f cluster/docker-compose.yml logs init_host | tail -1
```

Вывод:

```text
Initialize has completed successfully.
```

Первичная настройка службы каталогов AD (smblds) завершается через ~30–60 секунд после старта стенда.
До окончания настройки авторизация пользователя `bob` будет отклоняться.

## Как это работает

Аутентификация работает по следующей схеме:

```
Go-клиент
   │  iproto: user = ldap:{login}, auth_type = pap-sha256
   ▼
роутер TDB (роль app.roles.tdb_ldap_auth)
   │  HTTPS POST /authenticate
   ├──► ldap-worker-openldap:9081 ──► OpenLDAP (openldap:389)
   └──► ldap-worker-ad:9082      ──► Active Directory (ad:389, smblds)
```

Здесь:

1. Клиент подключается к роутеру с именем пользователя `ldap:{login}`
   (префикс `ldap:` — признак LDAP-аккаунта, `{login}` — логин в LDAP) через метод
   аутентификации `auth_type = pap-sha256`.
2. Технологическая роль `app.roles.tdb_ldap_auth` перехватывает запрос `IPROTO_AUTH` и вызывает
   LDAP-обработчик, который опрашивает все каталоги из параметра `worker_directories`.
   Если один и тот же логин найден в двух каталогах, возвращается ошибка конфигурации.
3. Обработчик проверяет логин и пароль, выполняя аутентификацию в каталоге, и возвращает DN
   пользователя и его группы.
4. Роль строит права сессии из секции `mapping` (LDAP-группа → права на
   ресурсы TDB), переключает сессию на служебного пользователя
   `tdb_ldap_auth` и применяет список контроля доступа (ACL) через модуль `tdb_acl`.
5. Дальнейшие вызовы методов `crud.*` клиентом проверяются по правам сессии.

Конфигурация технологической роли `app.roles.tdb_ldap_auth` задаётся в примере в файле `cluster/config.yml`, в
секции `roles_cfg`:

* `worker_directories` — каталоги LDAP; в группе — адреса обработчиков одного
  каталога. В примере два каталога, по одному обработчику в каждом;
* `worker_ca_file` — CA, с помощью которого проверяется TLS-сертификат обработчика
  (`certs/ca/root-ca.pem`);
* `mapping` — сопоставление LDAP-групп (DN) с правами. Группа `readers` из каталога OpenLDAP даёт
  право на чтение спейса `orders`, группа `tdb-writers` из каталога AD — право на чтение и запись в этот спейс. Группы, которых нет в этой опции, игнорируются. Если у пользователя
  не осталось сопоставленных групп, вход отклоняется.

LDAP-обработчик представляет собой бинарный файл `bin/ldap-worker` из образа Tarantool DB. Каждый обработчик
обслуживает один каталог (в примере это `openldap` и `ad`) и проверяет
логин и пароль, выполняя аутентификацию в каталоге. Пресеты шаблонов поиска задаются
опцией `ldap.type` (`openldap`, `ad`). Конфигурации обработчиков хранятся в etcd и
публикуются с помощью команды `make start`.

## Запуск приложения

Откройте вторую вкладку терминала и перейдите в директорию `ldap_auth/go`:

```shell
cd examples/ldap_auth/go
```

Запустите Go-приложение:

```shell
go run -tags go_tarantool_ssl_disable main.go
```

Программа выполняет три сценария:

1. Вход через пользователя `alice` (OpenLDAP, доступ только на чтение). Операция `crud.select` по спейсу `orders`
   выполняется успешно, запись через `crud.insert` отклоняется ACL;
2. Вход через пользователя `bob` (AD, доступ на чтение и запись). Запись данных через `crud.insert` и выборка методом `crud.select` выполняются успешно;
3. Попытка входа с неверным паролем, которая отклоняется на этапе подключения.

Ответ для сценариев выглядит так:

```text
--- alice (OpenLDAP, группа readers: orders [read]) ---
tarantool: connection 127.0.0.1:3301 got unexpected request ID (2) in response (probably cancelled request)
alice: crud.select выполнен успешно, строк в спейсе orders: 0
alice: crud.insert отклонён, как и ожидалось: ...

--- bob (AD, группа tdb-writers: orders [read, write]) ---
tarantool: connection 127.0.0.1:3301 got unexpected request ID (2) in response (probably cancelled request)
bob: crud.insert выполнен успешно
bob: crud.select выполнен успешно, строк в спейсе orders: 1

--- alice с неверным паролем ---
подключение отклонено, как и ожидалось: ...
```

Число строк в выводе `crud.select` зависит от количества запусков программы, поскольку `bob` при каждом запуске добавляет новый заказ.

> [!NOTE]
> При каждом подключении go-tarantool печатает служебную строку вида
> `tarantool: connection ... got unexpected request ID (2) in response (probably
> cancelled request)` — это известная особенность рукопожатия pap-sha256 через
> композитный dialer (см. `connectLDAP` в `main.go`), на работу примера она
> не влияет.

## Остановка стенда

Для остановки стенда выполните команду ниже:

```shell
make stop
```
