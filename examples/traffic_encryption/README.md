# Шифрование трафика

Tarantool DB позволяет шифровать трафик по IPROTO при запросах от клиента и при репликации.

В этом руководстве описано, как включить шифрование на стороне кластера Tarantool DB,
а также создать шифрованные соединения из коннекторов на Go и Python.

Документацию по шифрованию трафика можно найти в [документации Tarantool Enterprise](https://www.tarantool.io/ru/doc/latest/concepts/configuration/configuration_connections/#securing-connections-with-ssl).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Настройка SSL-шифрования](#настройка-ssl-шифрования)
* [Используемые файлы](#используемые-файлы)
* [Подключение через tt CLI](#подключение-через-tt-cli)
* [Подключение через Go-коннектор](#подключение-через-go-коннектор)
* [Подключение через Python-коннектор](#подключение-через-python-коннектор)
* [Подключение через коннектор net.box](#подключение-через-коннектор-netbox)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install_tt);
* Go версии 1.13 или выше;
* python3;
* файлы сертификатов. Чтобы сгенерировать их, выполните команду `certs/gen.sh`;
* исходные файлы примера `traffic_encryption`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `traffic_encryption` расположен в директории `examples/traffic_encryption`.
>  * Отдельный архив [traffic_encryption.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Ftraffic_encryption&filename=traffic_encryption), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301—3303
* 3310, 3311
* 8081

Порты 3310 и 3311 необходимы для корректного подключения между экземплярами через SSL в [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

Перейдите в папку с примером `traffic_encryption` и запустите стенд:

```shell
cd examples/traffic_encryption
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
   - 1 роутер;
   - 1 набор реплик на 2 хранилища;
   - 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM);
- кластера etcd из 3 узлов;
- клиентских приложений для проверки подключения.

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

## Настройка SSL-шифрования

Для работы с SSL в Tarantool используются SSL-сертификаты.
Экземпляр Tarantool DB здесь — это одновременно и сервер, и клиент по отношению к другим экземплярам.
Чтобы любой экземпляр мог подключаться ко всем остальным экземплярам, для каждого экземпляра требуется как сертификат
сервера, так и сертификат клиента.
Это означает, что для экземпляра кластера всегда нужно передавать как серверные, так и клиентские аргументы.

В примере `traffic_encryption` сертификаты находятся в директории `./certs/` и
должны быть доступны для каждого экземпляра.
Сертификаты генерируются с помощью скрипта `./certs/gen.sh`.

В примере заданы параметры SSL-шифрования для экземпляра с помощью переменных окружения:

```yaml
- TT_CLI_SSLKEYFILE=/tmp/certs/client-key.pem
- TT_CLI_SSLCERTFILE=/tmp/certs/client-cert.pem
```

Здесь:

- `TT_CLI_SSLKEYFILE` — путь к закрытому ключу клиента.
- `TT_CLI_SSLCERTFILE` — путь к сертификату клиента;

Эти переменные окружения необходимы для корректной работы конфигурации при использовании Tarantool из клиентских приложений.

## Используемые файлы

Для запуска и настройки кластера используются файлы из папки ``traffic_encryption``:

* `certs/`
  * `gen.sh` — скрипт генерации локального набора сертификатов для стенда;
* `cluster/` — директория c файлами для запуска кластера Tarantool DB:
  * `migrations/scenario` — директория, содержащая файлы с описанием миграций;
  * `config.yml` — конфигурация и топология кластера;
  * `docker-compose.yml` — описание узлов кластера Tarantool DB;
* `go/` — директория с файлами для создания подключения через Go-коннектор;
* `python/` — директория с файлами для создания подключения через Python-коннектор;
* `tools/` — директория с файлами для запуска кластера etcd и средств мониторинга:
  * `docker-compose.yml` — описание узлов кластера etcd и средств мониторинга;
  * `tcm.yml` — конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

## Подключение через tt CLI

Попробуйте подключиться к экземпляру, используя команду `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

Ответ будет выглядеть так:

```bash
• Connecting to the instance...
⨯ failed to run interactive console: failed to create new console: failed to connect: failed to get protocol: failed to read Tarantool greeting: read tcp [::1]:62950->[::1]:3301: i/o timeout
```

Подключитесь к узлу снова, используя клиентские сертификаты:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301 \
  --sslkeyfile ./certs/client-key.pem \
  --sslcertfile ./certs/client-cert.pem
```

При успешном подключении ответ будет выглядеть так:

```bash
   • Connecting to the instance...
Enter PEM pass phrase:
   • Connected to localhost:3301

localhost:3301>
```

Для примера можно получить имя экземпляра:
```lua
box.info().name
```

## Подключение через Go-коннектор

В этом разделе описано подключение к экземпляру Tarantool DB через [Go-коннектор](https://github.com/tarantool/go-tarantool/).
Пример расположен в директории `./go/` примера `traffic_encryption`.

Для запуска выполните `make go`

Go-клиент подключится к узлу через коннектор и запросит текущую
версию платформы Tarantool. Ответ может выглядеть так:
```
Tarantool 3.2.0 (Binary) 2404fdc5-4438-485a-b2e1-18fae889b95c
```

Код подключения выглядит так:

```go
dialer := tarantool.OpenSslDialer{
	Address:     "tarantool-router-msk:3301",
	User:        "admin",
	Password:    "secret-cluster-cookie",
	SslKeyFile:  "./certs/client-key.pem",
	SslCertFile: "./certs/client-cert.pem",
	SslCaFile:   "./certs/ca-cert.pem",
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

Для запуска примера выполните `make python`.

Результат может выглядеть так:
```bash
- '3.2.0-0-g19607a903'
```

Код подключения выглядит так:

```python
con = tarantool.Connection(
    'tarantool-router-msk',
    3301,
    user="admin",
    password="secret-cluster-cookie",
    transport='ssl',
    ssl_key_file='certs/client-key.pem',
    ssl_cert_file='certs/client-cert.pem',
    ssl_ca_file='certs/ca-cert.pem',
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
В открывшемся окне перейдите на вкладку **Terminal -> Direct**.

## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
