# Аутентификация через LDAP

Доступно с версии TDB 3.4.0.

В этом руководстве показано, как настроить аутентификацию клиентов Tarantool DB
в LDAP-каталогах (OpenLDAP и Active Directory) с помощью технологической роли
`app.roles.tdb_ldap_auth` и LDAP-обработчика, а затем подключиться к кластеру
из Go с помощью библиотеки `go-tarantool`.

Все соединения в примере зашифрованы: клиент ↔ роутер и роутер ↔ LDAP-обработчик
работают через SSL/TLS с двусторонней аутентификацией (mTLS), а LDAP-обработчики
обращаются к каталогам по LDAPS с проверкой сертификата каталога.

> [!IMPORTANT]
> Пример упрощает настройку ради наглядности и не подходит в текущем виде для промышленной эксплуатации:
> пароли и DN сервисных аккаунтов лежат в конфигурационных файлах примера.
>
> Настройка SSL-соединения между узлами кластера (репликация, sharding)
> и etcd показана в примере
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
* [Резервный обработчик](#резервный-обработчик)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker)
  Tarantool DB версии 3.4.0 или выше (в примере используется образ
  `tarantooldb:3.4.0`; роль `app.roles.tdb_ldap_auth`
  и бинарный файл LDAP-обработчика входят в образ);
* Docker-образы `osixia/openldap:1.5.0`, `smblds/smblds:latest` и
  `quay.io/coreos/etcd:v3.5.15`;
* приложение Docker Compose;
* утилита `openssl` (генерация сертификатов);
* компилятор Go;
* заголовки и библиотеки OpenSSL 3.x для cgo-сборки `go-tlsdialer`
  (`libssl-dev` в Debian/Ubuntu, `openssl-devel` в RHEL-семействе,
  `openssl@3` в Homebrew на macOS);
* свободные порты 2379 и 3301.

> [!IMPORTANT]
> `go-tlsdialer` v1.0.2 зависит от `go-openssl` v1.2.1, который не собирается
> с OpenSSL 4.x. В macOS с Homebrew по умолчанию устанавливается OpenSSL 4.x.
> Установите `openssl@3` (`brew install openssl@3`) и передайте пути к нему
> при запуске приложения:
>
> ```shell
> CGO_CFLAGS="-I$(brew --prefix openssl@3)/include" \
> CGO_LDFLAGS="-L$(brew --prefix openssl@3)/lib" \
> go -C ./go run main.go
> ```

> [!NOTE]
> Есть два способа получить исходные файлы примера:
> * Репозиторий [tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `ldap_auth` расположен в директории `examples/ldap_auth`.
> * Отдельный архив [ldap_auth.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fldap_auth&filename=ldap_auth), скачанный из этого репозитория.

## Используемые файлы

* `certs/gen.sh` — генерация CA, серверных сертификатов LDAP-обработчиков,
  роутера и каталогов (LDAPS), клиентского сертификата (mTLS клиент ↔ роутер
  и роутер ↔ обработчик);
* `tools/docker-compose.yml` — etcd из одного узла для хранения конфигураций кластера
  и обработчиков, а также одноразовый сервис `tt-tools` для публикации
  кластерной конфигурации;
* `ldap/docker-compose.yml` — каталоги OpenLDAP и Active Directory (оба
  каталога принимают LDAPS-соединения на порту 636);
* `ldap/openldap/bootstrap.ldif` — пользователь `alice` и группа `readers`;
* `ldap/ad/entrypoint.d/01-users.sh` — пользователь `bob` и группа
  `tdb-writers` (создаются `samba-tool` при старте контейнера AD);
* `ldap/ad/entrypoint.d/02-tls.sh` — подключение серверного сертификата
  AD для LDAPS (Samba требует права 0600 у ключа, поэтому сертификаты
  копируются внутрь контейнера);
* `workers/openldap-worker.yml`, `workers/openldap-worker-2.yml`,
  `workers/ad-worker.yml` — конфигурации LDAP-обработчиков, которые публикуются
  в etcd командой `tt cluster worker publish`;
* `workers/docker-compose.yml` — три узла LDAP-обработчика: основной и резервный экземпляры для
  каталога OpenLDAP, один узел для каталога AD;
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
* 3 узлов-обработчиков LDAP;
* двух каталогов (OpenLDAP, AD).

Запустите стенд:

```shell
make start
```

Команда `make start` публикует в etcd конфигурации кластера и LDAP-обработчиков
(команды `tt cluster publish` и `tt cluster worker publish`), запускает все слои
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

Каталог OpenLDAP при первом старте генерирует параметры Диффи — Хеллмана для LDAPS,
это занимает до ~1–2 минут. До окончания генерации LDAPS-порт каталога ещё не слушается
и авторизация пользователя `alice` будет отклоняться.

## Как это работает

Аутентификация работает по следующей схеме:

```
Go-клиент
   │  iproto SSL (mTLS): user = ldap:{login}, auth_type = pap-sha256
   ▼
роутер TDB (роль app.roles.tdb_ldap_auth)
   │  HTTPS (mTLS) POST /authenticate
   ├──► ldap-worker-openldap:9081 ──ldaps──► OpenLDAP (openldap:636)
   └──► ldap-worker-ad:9082      ──ldaps──► Active Directory (ad:636, smblds)
```

Здесь:

1. Клиент подключается к роутеру с именем пользователя `ldap:{login}`
   (префикс `ldap:` — признак LDAP-аккаунта, `{login}` — логин в LDAP) через метод
   аутентификации `auth_type = pap-sha256`
   по SSL-соединению (mTLS: слушатель роутера требует клиентский сертификат).
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
  каталога с фейловером по недоступности. В примере два каталога: у OpenLDAP
  основной и резервный обработчики, у AD — один;
* `worker_ca_file` — CA, с помощью которого проверяется TLS-сертификат обработчика
  (`certs/ca/root-ca.pem`);
* `worker_client_cert_file` / `worker_client_key_file` — клиентский
  сертификат и ключ, которые роутер предъявляет LDAP-обработчикам (mTLS:
  обработчики с опцией `ssl_ca_file` отклоняют соединения без клиентского сертификата);
* `mapping` — сопоставление LDAP-групп (DN) с правами. Группа `readers` из каталога OpenLDAP даёт
  право на чтение спейса `orders`, группа `tdb-writers` из каталога AD — право на чтение и запись в этот спейс. Группы, которых нет в этой опции, игнорируются. Если у пользователя
  не осталось сопоставленных групп, вход отклоняется.

Слушатель iproto-роутера работает через SSL: транспорт и сертификаты задаются
в опциях `params` слушателя в файле конфигурации `cluster/config.yml` (`transport: ssl`,
`ssl_cert_file`/`ssl_key_file` — серверный сертификат роутера,
`ssl_ca_file` — CA клиентских сертификатов, т.е. mTLS). Клиентский
сертификат требуется на каждом соединении, его предъявляют Go-клиент
и утилиты `tt` при начальной инициализации кластера.

LDAP-обработчик представляет собой бинарный файл `bin/ldap-worker` из образа Tarantool DB. Каждый обработчик
обслуживает один каталог (в примере это `openldap` и `ad`) и проверяет
логин и пароль, выполняя аутентификацию в каталоге. Пресеты шаблонов поиска задаются
опцией `ldap.type` (`openldap`, `ad`).

Конфигурация обработчика хранится в etcd и публикуется командой
`tt cluster worker publish` — её вызывает одноразовый сервис `tt-tools`
при запуске `make start`. Например, конфигурация обработчика каталога AD
публикуется так (из директории `ldap_auth`):

```shell
docker compose -f tools/docker-compose.yml run --rm tt-tools \
    tt cluster worker publish http://etcd:2379/tdb-workers/tdb/127.0.0.1/ldap-worker-ad workers/ad-worker.yml --force
```

При успешной публикации команда ничего не выводит.

URI команды состоит из адреса etcd и пути `/prefix/host-name/worker-name`:
два последних сегмента — имя узла и имя обработчика, всё до них — базовый префикс.
Конфигурация записывается в etcd по ключу `/prefix/instances/host-name/worker-name`,
поэтому команда выше публикует файл `workers/ad-worker.yml` по ключу
`/tdb-workers/tdb/instances/127.0.0.1/ldap-worker-ad`. Обработчик читает свою
конфигурацию при старте по этому же ключу: имя узла (`127.0.0.1`) и имя обработчика
(`ldap-worker-ad`) задаются переменными окружения `TDB_WORKER_HOST_NAME` и
`TDB_WORKER_NAME` узла `ldap-worker-ad` в файле `workers/docker-compose.yml`,
а префикс (`/tdb-workers/tdb`) — переменной `TDB_WORKER_CONFIG_ETCD_PREFIX`.
Флаг `--force` перезаписывает уже опубликованную конфигурацию: без него повторный
запуск `make start` завершится ошибкой `worker configuration already exists`.

Посмотреть опубликованную конфигурацию можно командой `tt cluster worker show`
(для удаления используется `tt cluster worker delete`):

```shell
docker compose -f tools/docker-compose.yml run --rm tt-tools \
    tt cluster worker show http://etcd:2379/tdb-workers/tdb/127.0.0.1/ldap-worker-ad
```

Вывод:

```text
type: nontarantool

instrumentation:
  url: https://ldap-worker-ad:9082
  metrics_url: /metrics
  metrics_format: prometheus
  liveness_url: /alive
  info_url: /info
  binary: ./bin/ldap-worker

config:
  roles.httpd:
    instrumentation:
      listen: ldap-worker-ad:9082
    ldap:
      listen: ldap-worker-ad:9082
      ssl_cert_file: /certs/worker/server.pem
      ssl_key_file: /certs/worker/server-key.pem
      # CA клиентских сертификатов — включает mTLS: без клиентского
      # сертификата (роутера) соединение отклоняется
      ssl_ca_file: /certs/ca/root-ca.pem
  ldap:
    type: ad                       # пресет: (|(sAMAccountName={0})(userPrincipalName={0})), группы — memberOf
    endpoints:
      - ad:636                     # LDAPS-порт каталога
    query-user: CN=Administrator,CN=Users,DC=samdom,DC=example,DC=com
    query-password: Passw0rd!
    base-dn: DC=samdom,DC=example,DC=com
    tls:
      enabled: true                # ldaps://
      # CA примера: им проверяется сертификат каталога (certs/ad/server.pem,
      # подключается скриптом ldap/ad/entrypoint.d/02-tls.sh).
      # Имя сервера в сертификате — хост из endpoint (ad)
      ca-file: /certs/ca/root-ca.pem
```

Команда выводит конфигурацию в том виде, в котором она хранится в etcd,
без переформатирования.

Соединения обработчиков с каталогами работают по LDAPS: порт 636 в `ldap.endpoints`
и секция `ldap.tls` в конфигурации обработчика. Опция `tls.enabled: true` включает
`ldaps://`, `tls.ca-file` задает CA для проверки сертификата каталога — используется
CA примера (`certs/ca/root-ca.pem`), им же подписаны сертификаты каталогов из
`certs/openldap/` и `certs/ad/`. Имя сервера в сертификате каталога сверяется
с хостом из `ldap.endpoints` (SAN сертификатов — `openldap` и `ad`).

Серверный сертификат OpenLDAP монтируется в контейнер каталога напрямую
(`../certs/openldap` в `ldap/docker-compose.yml`), а у AD на базе Samba сертификат
подключается скриптом `ldap/ad/entrypoint.d/02-tls.sh`: Samba требует, чтобы
приватный ключ принадлежал root и имел права 0600 (защита от CVE-2013-4476),
поэтому сертификаты копируются внутрь контейнера. Клиентские сертификаты
обработчики каталогам не предъявляют.

Проверить сертификат каталога по CA примера можно изнутри сети стенда
(имя сервера сверяется по хосту из адреса):

```shell
docker run --rm --network tarantooldb_network -v "$PWD/certs:/certs:ro" \
  --entrypoint sh osixia/openldap:1.5.0 \
  -c 'openssl s_client -connect ad:636 -CAfile /certs/ca/root-ca.pem </dev/null'
```

Вывод должен содержать `Verify return code: 0 (ok)`.

## Запуск приложения

Откройте вторую вкладку терминала и перейдите в директорию `ldap_auth`:

```shell
cd examples/ldap_auth
```

Запустите Go-приложение:

```shell
go -C ./go run main.go
```

Программа выполняет три сценария:

1. Вход через пользователя `alice` (OpenLDAP, доступ только на чтение). Операция `crud.select` по спейсу `orders`
   выполняется успешно, запись через `crud.insert` отклоняется ACL;
2. Вход через пользователя `bob` (AD, доступ на чтение и запись). Запись данных через `crud.insert` и выборка методом `crud.select` выполняются успешно;
3. Попытка входа с неверным паролем, которая отклоняется на этапе подключения.

Если при запуске не переданы аргументы, выполняются все сценарии. Запустить конкретный сценарий можно,
передав в команду при запуске название сценария (`alice`, `bob` или `wrong-password`):

```shell
go -C ./go run main.go alice
```

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
> При каждом подключении `go-tarantool` печатает служебную строку вида
> `tarantool: connection ... got unexpected request ID (2) in response (probably
> cancelled request)` — это известная особенность рукопожатия pap-sha256
> в библиотеке `go-tarantool` (см. `connectLDAP` в `main.go`). На работу
> примера эта особенность не влияет.

## Резервный обработчик

Внутри одной группы `worker_directories` можно перечислить несколько обработчиков
одного каталога. Если обработчик становится недоступен (например, из-за ошибки
сети, истечения времени ожидания или ответа `5xx`), роль переключается на
следующий адрес группы. Ответ `401` окончателен внутри каталога, резервный
обработчик при этом не запрашивается.

В примере у каталога OpenLDAP два обработчика: основной
`ldap-worker-openldap:9081` и резервный `ldap-worker-openldap-2:9083`.
Оба узла обращаются к одному каталогу `openldap:636` (LDAPS). Время ожидания выполнения
одного запроса аутентификации ограничено значением опции
`worker_request_timeout: 2` (секунды) в файле `cluster/config.yml`, поэтому
зависший обработчик не блокирует клиента дольше двух секунд.

Проверьте аутентификацию через резервный экземпляр обработчика. Из директории
`ldap_auth` остановите основной обработчик:

```shell
docker compose -f workers/docker-compose.yml stop ldap-worker-openldap
```

Запустите сценарий `alice` с аутентификацией в OpenLDAP:

```shell
go -C ./go run main.go alice
```

Вход выполняется через резервный обработчик, сценарий выполняется без изменений:

```text
--- alice (OpenLDAP, группа readers: orders [read]) ---
tarantool: connection 127.0.0.1:3301 got unexpected request ID (2) in response (probably cancelled request)
alice: crud.select выполнен успешно, строк в спейсе orders: ...
alice: crud.insert отклонён, как и ожидалось: ...
```

Число строк и текст ошибки доступа могут отличаться. В ответе также содержится служебная строка
подключения, описанная в примечании выше.

Повторно запустите основной узел-обработчик:

```shell
docker compose -f workers/docker-compose.yml start ldap-worker-openldap
```

## Остановка стенда

Для остановки стенда выполните команду ниже:

```shell
make stop
```
