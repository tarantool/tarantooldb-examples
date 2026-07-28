# Шифрование трафика

В этом примере показано, как настроить шифрование трафика для распределённой системы, состоящей из следующих компонентов:
- клиентские приложения;
- узлы кластера Tarantool DB;
- веб-интерфейс Tarantool Cluster Manager (TCM);
- etcd (используется для хранения конфигурации кластера и TCM);
- Prometheus.

Шифруются следующие соединения:
- между узлами кластера Tarantool DB;
- между клиентами и узлами Tarantool DB;
- между TCM и узлами Tarantool DB;
- между TCM и etcd (backend store);
- между узлами Tarantool DB и etcd (хранилище конфигурации кластера);
- между пользователем и веб-интерфейсом TCM (HTTPS);
- между узлами Tarantool DB и Prometheus (экспорт метрик по HTTPS).

Руководство также демонстрирует, как подключиться к защищённому кластеру с помощью клиентских коннекторов на Go и Python.

Подробную информацию по настройке шифрования трафика можно найти в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/platform/connections_and_auth/connections/#securing-connections-with-ssl).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Настройка SSL-шифрования](#настройка-ssl-шифрования)
* [Подключение через tt CLI](#подключение-через-tt-cli)
* [Подключение через Go-коннектор](#подключение-через-go-коннектор)
* [Подключение через Python-коннектор](#подключение-через-python-коннектор)
* [Подключение через коннектор net.box](#подключение-через-коннектор-netbox)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt);
* Go версии 1.13 или выше;
* python3;
* файлы сертификатов. Чтобы сгенерировать их, выполните команду `certs/gen.sh`;
* исходные файлы примера `traffic_encryption`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `traffic_encryption` расположен в директории `examples/traffic_encryption`.
>  * Отдельный архив [traffic_encryption.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Ftraffic_encryption&filename=traffic_encryption), скачанный из этого репозитория.

## Используемые файлы

Для запуска и настройки кластера используются файлы из папки `traffic_encryption`:

* `certs/`
  * `gen.sh` — скрипт генерации локального набора сертификатов;
* `cluster/` — директория c файлами для запуска кластера Tarantool DB:
  * `migrations/scenario` — директория, содержащая файлы с описанием миграций;
  * `config.yml` — конфигурация и топология кластера;
  * `docker-compose.yml` — описание узлов кластера Tarantool DB;
* `go/` — директория с файлами для создания подключения через Go-коннектор;
* `python/` — директория с файлами для создания подключения через Python-коннектор;
* `tools/` — директория с файлами для запуска кластера etcd и средств мониторинга:
  * `grafana/` — директория, содержащая настройки для ведения мониторинга;
  * `prometheus/` — директория, содержащая настройки Prometheus для сбора и передачи метрик в Grafana;
  * `docker-compose.yml` — описание узлов кластера etcd и средств мониторинга;
  * `tcm.yml` — конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3000
* 3301–3303
* 8081
* 9090

Перейдите в папку с примером `traffic_encryption` и запустите стенд:

```shell
cd examples/traffic_encryption
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
   - 1 роутер;
   - 1 набор реплик на 2 хранилища;
   - 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
- кластера etcd из 3 узлов;
- клиентских приложений для проверки подключения;
- средств мониторинга — [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера доступны следующие пользовательские интерфейсы:
* [https://localhost:8081](https://localhost:8081) — защищённый веб-интерфейс TCM;
* [http://localhost:3000](http://localhost:3000) — веб-интерфейс Grafana.

Для входа в TCM откройте в браузере адрес [https://localhost:8081](https://localhost:8081) (браузер может предупредить о самоподписанном сертификате).

Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

## Настройка SSL-шифрования

Для работы с SSL в Tarantool DB используются SSL-сертификаты.
Экземпляры Tarantool DB используют сертификат сервера для взаимодействия друг с другом и клиентскими соединениями. При этом внешние компоненты, подключающиеся к Tarantool DB (например, утилита tt CLI или веб-интерфейс TCM), используют клиентские сертификаты, чтобы пройти аутентификацию.

Скрипт `./certs/gen.sh` генерирует все необходимые сертификаты с использованием единого корневого центра сертификации (CA):
- для **Tarantool DB** — серверные и клиентские сертификаты, а также сертификат для HTTPS-сервера экспорта метрик;
- для **etcd** — серверные и клиентские сертификаты, а также сертификат для peer-взаимодействия узлов в кластере etcd;
- для **TCM** — серверный сертификат для HTTPS.

В разделах ниже описано, как настраивается шифрование для каждого из этих компонентов.

### Настройка etcd

Параметры узлов etcd настраиваются в файле конфигурации `tools/docker-compose.yml`.
Здесь указаны корневой CA, а также ключи и сертификаты для серверных и peer-взаимодействий:

```yaml
etcd1:
  <<: *etcd-base
  command: >
    etcd --name etcd1
    --data-dir /etcd-data
    --listen-client-urls https://0.0.0.0:2379
    --advertise-client-urls https://etcd1:2379
    --listen-peer-urls https://0.0.0.0:2380
    --initial-advertise-peer-urls https://etcd1:2380
    --initial-cluster etcd1=https://etcd1:2380,etcd2=https://etcd2:2380,etcd3=https://etcd3:2380
    --initial-cluster-token my-etcd-cluster
    --initial-cluster-state new
    --client-cert-auth
    --trusted-ca-file /certs/ca/root-ca.pem
    --cert-file /certs/etcd/server.pem
    --key-file /certs/etcd/server-key.pem
    --peer-client-cert-auth
    --peer-trusted-ca-file /certs/ca/root-ca.pem
    --peer-cert-file /certs/etcd/peer.pem
    --peer-key-file /certs/etcd/peer-key.pem
  ports:
    - "2379:2379"
```

### Настройка Tarantool DB

Параметры SSL для каждого экземпляра Tarantool DB задаются в файле конфигурации кластера `cluster/config.yml`:

```yaml
params: &ssl_params
  transport: 'ssl'
  ssl_ca_file: '/certs/ca/root-ca.pem'
  ssl_cert_file: '/certs/tarantool/server.pem'
  ssl_key_file: '/certs/tarantool/server-key.pem'
```

Список разрешённых наборов шифров (cipher suites) для SSL-соединения можно задать с помощью параметра `params.ssl_ciphers`, перечислив их через двоеточие:

```yaml
params:
  ssl_ciphers: 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'
```

Подробная информация о поддерживаемых значениях параметра `params.ssl_ciphers` приведена в [документации Tarantool](https://tarantool.io/ru/doc/latest/reference/configuration/configuration_reference/#confval-uri-.params.ssl_ciphers).

Также в `cluster/docker-compose.yml` для каждого экземпляра через переменные окружения задаются параметры защищенного
подключения к etcd, в котором хранится конфигурация кластера:

```yaml
TT_CONFIG_ETCD_ENDPOINTS: https://etcd1:2379,https://etcd2:2379,https://etcd3:2379
TT_CONFIG_ETCD_PREFIX: /tdb
TT_CONFIG_ETCD_HTTP_REQUEST_TIMEOUT: 3
TT_CONFIG_ETCD_SSL_CA_FILE: /certs/ca/root-ca.pem
TT_CONFIG_ETCD_SSL_SSL_CERT: /certs/etcd/client.pem
TT_CONFIG_ETCD_SSL_SSL_KEY: /certs/etcd/client-key.pem
```

Если используется централизованное хранилище конфигурации на основе Tarantool (*Tarantool-based configuration storage*, далее — TBCS), защищенное подключение к нему настраивается через
поле `params` в переменной окружения `TT_CONFIG_STORAGE_ENDPOINTS`.
Подробная информация доступна в [документации Tarantool](https://tarantool.io/ru/doc/latest/reference/configuration/configuration_reference/#config-storage).

Для экспорта метрик по SSL в формате Prometheus роль `roles.metrics-export` задается на всех экземплярах Tarantool DB:

```yaml
roles_cfg:
  roles.metrics-export:
    http:
    - listen: 8081
      ssl_cert_file: /certs/tarantool/metrics.pem
      ssl_key_file: /certs/tarantool/metrics-key.pem
      endpoints:
      - format: prometheus
        path: /metrics
```

### Настройка TCM

Настройки шифрования для TCM задаются в файле конфигурации `tools/tcm.yml`.

* HTTPS для веб-интерфейса:

```yaml
http:
    host: 0.0.0.0
    port: 8081
    tls:
      enabled: true
      cert-file: /certs/tcm/server.pem
      key-file: /certs/tcm/server-key.pem
```

Если требуется ограничить наборы используемых шифров, перечислите их в виде массива с помощью параметра `http.tls.cipher-suites`:

```yaml
http:
  tls:
    cipher-suites:
    - TLS_AES_256_GCM_SHA384
    - TLS_AES_128_GCM_SHA256
    - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
    - TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
```

Информацию о поддерживаемых значениях наборов шифров для веб-интерфейса можно найти в [документации TCM](https://tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-http.tls.cipher-suites).

* Подключение к etcd с данными TCM (backend store):

```yaml
storage:
  provider: etcd
  etcd:
      prefix: /tcm
      endpoints:
          - https://etcd1:2379
          - https://etcd2:2379
          - https://etcd3:2379
      tls:
        enabled: true
        trusted-ca-file: /certs/ca/root-ca.pem
        cert-file: /certs/etcd/client.pem
        key-file: /certs/etcd/client-key.pem
```

Здесь также можно задать набор используемых шифров — он указывается в виде массива в параметре [storage.etcd.tls.cipher-suites](https://www.tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-storage.etcd.tls.cipher-suites).

* Подключение к etcd с конфигурацией кластера:

```yaml
storage-connection:
  provider: etcd
  etcd-connection:
    prefix: /tdb
    endpoints:
      - https://etcd1:2379
      - https://etcd2:2379
      - https://etcd3:2379
    tls:
      enabled: true
      trusted-ca-file: /certs/ca/root-ca.pem
      cert-file: /certs/etcd/client.pem
      key-file: /certs/etcd/client-key.pem
```

Здесь также можно задать набор используемых шифров — он указывается в виде массива в параметре [initial-settings.clusters.<cluster>.storage-connection.etcd-connection.tls.cipher-suites](https://www.tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-initial-settings.clusters.-cluster-.storage-connection.etcd-connection.tls.cipher-suites).

* Подключение к узлам Tarantool:

```yaml
tarantool-connection:
  username: "admin"
  password: "secret-cluster-cookie"
  ssl:
    enabled: true
    ca-file: /certs/ca/root-ca.pem
    cert-file: /certs/tarantool/client.pem
    key-file: /certs/tarantool/client-key.pem
```

Список наборов шифров для подключения к узлам Tarantool можно задать с помощью параметра [initial-settings.clusters.<cluster>.storage-connection.tarantool-connection.ssl.ciphers](https://www.tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-initial-settings.clusters.-cluster-.storage-connection.tarantool-connection.ssl.ciphers). Наборы шифров перечисляются через двоеточие аналогично параметру `params.ssl_ciphers` конфигурации кластера Tarantool DB.

Подробную информацию о настройке TCM можно найти в [документации Tarantool](https://tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration).

### Настройка клиента

Ключ и сертификат клиента для команды `tt migrations` можно задать в параметрах `--tarantool-sslkeyfile` и
`--tarantool-sslcertfile`.
Для команд `tt replicaset` и `tt connect` эти параметры имеют названия `--sslkeyfile` и `--sslcertfile`.

## Подключение через tt CLI

Попробуйте подключиться к экземпляру, используя команду `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

Ответ будет выглядеть так:

```bash
• Connecting to the instance...
⨯ failed to run interactive console: failed to create new console: failed to connect: failed to get protocol: failed to read Tarantool greeting: read tcp 127.0.0.1:50634->127.0.0.1:3301: i/o timeout
```

Подключитесь к узлу снова, используя клиентские сертификаты:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301 \
  --sslkeyfile ./certs/tarantool/client-key.pem \
  --sslcertfile ./certs/tarantool/client.pem
```

При успешном подключении ответ будет выглядеть так:

```bash
   • Connecting to the instance...
   • Connected to localhost:3301

localhost:3301>
```

Для примера можно получить имя экземпляра:

```lua
box.info.name
```

## Подключение через Go-коннектор

В этом разделе описано подключение к экземпляру Tarantool DB через [Go-коннектор](https://github.com/tarantool/go-tarantool/).
Пример расположен в директории `./go/` примера `traffic_encryption`.

Для запуска выполните команду `make go`.

Go-клиент подключится к узлу через коннектор и запросит текущую
версию платформы Tarantool. Ответ может выглядеть так:
```
Tarantool 3.4.1 (Binary) 28274879-0539-4c12-a225-57ef4d1736cb
```

Код подключения выглядит так:

```go
dialer := tarantool.OpenSslDialer{
    Address:     "tarantool-router-msk:3301",
    User:        "admin",
    Password:    "secret-cluster-cookie",
    SslKeyFile:  "./certs/tarantool/client-key.pem",
    SslCertFile: "./certs/tarantool/client.pem",
    SslCaFile:   "./certs/ca/root-ca.pem",
    SslPassword: "54321",
}

opts := tarantool.Opts{}

conn, err := tarantool.Connect(ctx, dialer, opts)
if err != nil {
    fmt.Println(err)
    return
}
```

Опции здесь аналогичны опциям, которые передавались для `tt`.

## Подключение через Python-коннектор

В разделе описано подключение к экземпляру Tarantool DB через [Python-коннектор](https://github.com/tarantool/tarantool-python).
Пример расположен в директории `./python/` примера `traffic_encryption`.

Для запуска примера выполните команду `make python`.

Результат может выглядеть так:
```bash
- '3.4.1-0-g096322fad'
```

Код подключения выглядит так:

```python
con = tarantool.Connection(
    'tarantool-router-msk',
    3301,
    user="admin",
    password="secret-cluster-cookie",
    transport='ssl',
    ssl_key_file='certs/tarantool/client-key.pem',
    ssl_cert_file='certs/tarantool/client.pem',
    ssl_ca_file='certs/ca/root-ca.pem',
    ssl_password='54321',
    connection_timeout=0.5,
    socket_timeout=0.5,
)
```

## Подключение через коннектор net.box

Tarantool позволяет создавать пользовательские соединения с помощью модуля `net.box`.
Чтобы показать, как работает этот модуль по SSL, вместе с миграциями определена
функция `get_name_by_uri`. Функция создаёт соединение с экземпляром кластера и
получает его имя:
```lua
box.schema.func.call('get_name_by_uri', 'admin:secret-cluster-cookie@tarantool-storage-1-spb:3301')
```

Функция возвращает имя экземпляра: `storage-1-spb`.

> [!NOTE]
> На запуск кластера может уйти несколько десятков секунд, поэтому
> миграции появятся не сразу.

Отправлять команды можно также через веб-интерфейс TCM.
Для этого откройте в TCM вкладку **Stateboard** и выберите в наборе реплик `router-msk` узел `router-msk`.
В открывшемся окне перейдите на вкладку **Terminal** (**TT Connect**).

## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
