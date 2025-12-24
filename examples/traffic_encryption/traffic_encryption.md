(admin_guide-traffic_encryption)=
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

* [](admin_guide-traffic_encryption-prereq)
* [](admin_guide-traffic_encryption-files)
* [](admin_guide-traffic_encryption-start_example)
* [](admin_guide-traffic_encryption-ssl_setup)
* [](admin_guide-traffic_encryption-tt)
* [](admin_guide-traffic_encryption-go)
* [](admin_guide-traffic_encryption-python)
* [](admin_guide-traffic_encryption-netbox)
* [](admin_guide-traffic_encryption-stop_example)

(admin_guide-traffic_encryption-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* Go версии 1.13 или выше;
* python3;
* файлы сертификатов. Чтобы сгенерировать их, выполните команду `certs/gen.sh`;
* исходные файлы примера `traffic_encryption`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `traffic_encryption` расположен в таком архиве в директории `./doc/examples/traffic_encryption/`.

  * Отдельный архив [traffic_encryption.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/traffic_encryption/traffic_encryption.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-traffic_encryption-files)=
## Используемые файлы

Для запуска и настройки кластера используются файлы из папки `traffic_encryption`:

* `certs/`
  * `gen.sh` -- скрипт генерации локального набора сертификатов;
* `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  * `migrations/scenario` -- директория, содержащая файлы с описанием миграций; 
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;  
* `go/` -- директория с файлами для создания подключения через Go-коннектор;
* `python/` -- директория с файлами для создания подключения через Python-коннектор;
* `tools/` -- директория с файлами для запуска кластера etcd и средств мониторинга:
  * `grafana/` -- директория, содержащая настройки для ведения мониторинга;
  * `prometheus/` -- директория, содержащая настройки Prometheus для сбора и передачи метрик в Grafana;
  * `docker-compose.yml` -- описание узлов кластера etcd и средств мониторинга;
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

(admin_guide-traffic_encryption-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3000
* 3301--3303
* 8081
* 9090

Перейдите в папку с примером `traffic_encryption` и запустите стенд:

```shell
cd ./doc/examples/traffic_encryption/
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
   - 1 роутер;
   - 1 набор реплик на 2 хранилища;
   - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов;
- клиентских приложений для проверки подключения;
- средств мониторинга -- [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера доступны следующие пользовательские интерфейсы:
* [https://localhost:8081](https://localhost:8081) -- защищённый веб-интерфейс TCM;
* [http://localhost:3000](http://localhost:3000) -- веб-интерфейс Grafana.

Для входа в TCM откройте в браузере адрес [https://localhost:8081](https://localhost:8081) (браузер может предупредить о самоподписанном сертификате).  

Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

(admin_guide-traffic_encryption-ssl_setup)=
## Настройка SSL-шифрования

Для работы с SSL в Tarantool DB используются SSL-сертификаты.
Экземпляры Tarantool DB используют сертификат сервера для взаимодействия друг с другом и клиентскими соединениями. При этом внешние компоненты, подключающиеся к Tarantool DB (например, утилита tt CLI или веб-интерфейс TCM), используют клиентские сертификаты, чтобы пройти аутентификацию.

Скрипт `./certs/gen.sh` генерирует все необходимые сертификаты с использованием единого корневого центра сертификации (CA):
- для **Tarantool DB** -- серверные и клиентские сертификаты, а также сертификат для HTTPS-сервера экспорта метрик;
- для **etcd** -- серверные и клиентские сертификаты, а также сертификат для peer-взаимодействия узлов в кластере etcd;
- для **TCM** -- серверный сертификат для HTTPS.

В разделах ниже описано, как настраивается шифрование для каждого из этих компонентов.


(admin_guide-traffic_encryption-ssl_setup-etcd)=
### Настройка etcd

Параметры узлов etcd настраиваются в файле конфигурации `tools/docker-compose.yml`.
Здесь указаны корневой CA, а также ключи и сертификаты для серверных и peer-взаимодействий:

```{literalinclude} tools/docker-compose.yml
:start-at: etcd1
:end-at: 2379:2379
:language: yaml
:dedent:
```

(admin_guide-traffic_encryption-ssl_setup-tdb)=
### Настройка Tarantool DB

Параметры SSL для каждого экземпляра Tarantool DB задаются в файле конфигурации кластера `cluster/config.yml`: 

```{literalinclude} cluster/config.yml
:start-after: tarantool-router-msk:3301
:end-before: advertise
:language: yaml
:dedent:
```

Список разрешённых наборов шифров (cipher suites) для SSL-соединения можно задать с помощью параметра `params.ssl_ciphers`, перечислив их через двоеточие:

```yaml
params:
  ssl_ciphers: 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'
```

Подробная информация о поддерживаемых значениях параметра `params.ssl_ciphers` приведена в [документации Tarantool](https://tarantool.io/ru/doc/latest/reference/configuration/configuration_reference/#confval-uri-.params.ssl_ciphers). 

Также в `cluster/docker-compose.yml` для каждого экземпляра через переменные окружения задаются параметры защищенного
подключения к etcd, в котором хранится конфигурация кластера:

```{literalinclude} cluster/docker-compose.yml
:start-at: TT_CONFIG_ETCD_ENDPOINTS
:end-before: services
:language: yaml
:dedent:
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

(admin_guide-traffic_encryption-ssl_setup-tcm)=
### Настройка TCM

Настройки шифрования для TCM задаются в файле конфигурации `tools/tcm.yml`.

* HTTPS для веб-интерфейса:

```{literalinclude} tools/tcm.yml
:start-at: http
:end-before: storage
:language: yaml
:dedent:
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

```{literalinclude} tools/tcm.yml
:start-at: storage
:end-before: security
:language: yaml
:dedent:
```

Здесь также можно задать набор используемых шифров -- он указывается в виде массива в параметре [storage.etcd.tls.cipher-suites](https://www.tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-storage.etcd.tls.cipher-suites).

* Подключение к etcd с конфигурацией кластера:

```{literalinclude} tools/tcm.yml
:start-at: storage-connection
:end-before: tarantool-connection
:language: yaml
:dedent:
```

Здесь также можно задать набор используемых шифров -- он указывается в виде массива в параметре [initial-settings.clusters.<cluster>.storage-connection.etcd-connection.tls.cipher-suites](https://www.tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-initial-settings.clusters.-cluster-.storage-connection.etcd-connection.tls.cipher-suites).

* Подключение к узлам Tarantool:

```{literalinclude} tools/tcm.yml
:start-at: tarantool-connection
:end-at: client-key.pem
:language: yaml
:dedent:
```

Список наборов шифров для подключения к узлам Tarantool можно задать с помощью параметра [initial-settings.clusters.<cluster>.storage-connection.tarantool-connection.ssl.ciphers](https://www.tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration_reference/#confval-initial-settings.clusters.-cluster-.storage-connection.tarantool-connection.ssl.ciphers). Наборы шифров перечисляются через двоеточие аналогично параметру `params.ssl_ciphers` конфигурации кластера Tarantool DB.

Подробную информацию о настройке TCM можно найти в [документации Tarantool](https://tarantool.io/ru/doc/latest/tooling/tcm/tcm_configuration).

(admin_guide-traffic_encryption-ssl_setup-client)=
### Настройка клиента

Ключ и сертификат клиента для команды `tt migrations` можно задать в параметрах `--tarantool-sslkeyfile` и
`--tarantool-sslcertfile`.
Для команд `tt replicaset` и `tt connect` эти параметры имеют названия `--sslkeyfile` и `--sslcertfile`.

(admin_guide-traffic_encryption-tt)=
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

(admin_guide-traffic_encryption-go)=
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

```{literalinclude} go/main.go
:start-at: dialer :=
:end-before: fmt.Println(conn.Greeting.Version)
:language: go
:dedent:
```

Опции здесь аналогичны опциям, которые передавались для `tt`.

(admin_guide-traffic_encryption-python)=
## Подключение через Python-коннектор

В разделе описано подключение к экземпляру Tarantool DB через [Python-коннектор](https://github.com/tarantool/tarantool-python).
Пример расположен в директории `./python/` примера `traffic_encryption`.

Для запуска примера выполните команду `make python`.

Результат может выглядеть так:
```bash 
- '3.4.1-0-g096322fad'
```

Код подключения выглядит так:

```{literalinclude} python/connect.py
:start-at: con = tarantool.Connection(
:end-before: print(con.eval
:language: python
:dedent:
```

(admin_guide-traffic_encryption-netbox)=
## Подключение через коннектор net.box

Tarantool позволяет создавать пользовательские соединения с помощью модуля `net.box`.
Чтобы показать, как работает этот модуль по SSL, вместе с миграциями определена
функция `get_name_by_uri`. Функция создаёт соединение с экземпляром кластера и
получает его имя:
```lua
box.schema.func.call('get_name_by_uri', 'admin:secret-cluster-cookie@tarantool-storage-1-spb:3301')
```

Функция возвращает имя экземпляра: `storage-1-spb`.

```{note}
На запуск кластера может уйти несколько десятков секунд, поэтому
миграции появятся не сразу.
```

Отправлять команды можно также через веб-интерфейс TCM.
Для этого откройте в TCM вкладку **Stateboard** и выберите в наборе реплик `router-msk` узел `router-msk`.
В открывшемся окне перейдите на вкладку **Terminal** (**TT Connect**).

(admin_guide-traffic_encryption-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
