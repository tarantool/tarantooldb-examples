# Шифрование трафика

Tarantool DB позволяет шифровать трафик по IPROTO при запросах от клиента и при репликации.

В этом руководстве описано, как включить шифрование на стороне кластера Tarantool DB,
а также создать шифрованные соединения из коннекторов на Go и Python.

Документацию по шифрованию трафика можно найти в [документации Tarantool Enterprise](https://www.tarantool.io/ru/doc/2.11/enterprise/security/#enterprise-iproto-encryption).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Настройка SSL-шифрования](#настройка-ssl-шифрования)
* [Подключение к узлу с помощью клиентских сертификатов](#подключение-к-узлу-с-помощью-клиентских-сертификатов)
* [Подключение через Go-коннектор](#подключение-через-go-коннектор)
* [Подключение через Python-коннектор](#подключение-через-python-коннектор)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* Go версии 1.13 или выше;
* python3;
* исходные файлы примера `traffic_encryption`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `traffic_encryption` расположен в директории `examples/traffic_encryption`.
>  * Отдельный архив [traffic_encryption.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Ftraffic_encryption&filename=traffic_encryption), скачанный из этого репозитория.

## Настройка SSL-шифрования

Для работы с SSL в Tarantool используются SSL-сертификаты.
Экземпляр Tarantool DB здесь — это одновременно и сервер, и клиент по отношению к другим экземплярам.
Чтобы любой экземпляр мог подключаться ко всем остальным экземплярам, для каждого экземпляра требуется как сертификат
сервера, так и сертификат клиента.
Это означает, что для экземпляра кластера всегда нужно передавать как серверные, так и клиентские аргументы.

В примере `traffic_encryption` сертификаты генерируются с помощью скрипта `./certs/gen.sh`. Сгенерированные сертификаты находятся в директории `./certs/` и
должны быть доступны для каждого экземпляра.


В примере заданы параметры SSL-шифрования для экземпляра с помощью переменных окружения:

```yaml
environment:
  - TARANTOOL_ADVERTISE_URI=tarantool-router:3301
  - TARANTOOL_ALIAS=router-1
  - TARANTOOL_TRANSPORT=SSL
  - TARANTOOL_SSL_SERVER_CA_FILE=/certs/ca-cert.pem
  - TARANTOOL_SSL_SERVER_CERT_FILE=/certs/server-cert.pem
  - TARANTOOL_SSL_SERVER_KEY_FILE=/certs/server-key.pem
  - TARANTOOL_SSL_CLIENT_CA_FILE=/certs/ca-cert.pem
  - TARANTOOL_SSL_CLIENT_CERT_FILE=/certs/client-cert.pem
  - TARANTOOL_SSL_CLIENT_KEY_FILE=/certs/client-key.pem
```

Здесь:

* `TARANTOOL_ADVERTISE_URI` — адрес и порт, на котором узел доступен в кластере;
* `TARANTOOL_TRANSPORT` — значение SSL;
* `TARANTOOL_SSL_SERVER_CA_FILE` — путь к корневому сертификату сервера;
* `TARANTOOL_SSL_SERVER_CERT_FILE` — путь к сертификату сервера;
* `TARANTOOL_SSL_SERVER_KEY_FILE` — путь к закрытому ключу сервера;
* `TARANTOOL_SSL_CLIENT_CA_FILE` — путь к корневому сертификату клиента;
* `TARANTOOL_SSL_CLIENT_CERT_FILE` — путь к сертификату клиента;
* `TARANTOOL_SSL_CLIENT_KEY_FILE` — путь к закрытому ключу клиента.

## Подключение к узлу с помощью клиентских сертификатов

Перейдите в папку с примером `traffic_encryption`, сгенерируйте сертификаты, а затем запустите стенд:

```shell
cd examples/traffic_encryption
cd certs && ./gen.sh
cd .. && docker compose up -d
```

Попытайтесь подключиться к экземпляру, используя команду `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Ответ будет выглядеть так:

```shell
• Connecting to the instance...
⨯ failed to run interactive console: failed to create new console: failed to connect: failed to get protocol: failed to read Tarantool greeting: read tcp [::1]:62950->[::1]:3300: i/o timeout
```

Подключитесь к узлу снова, используя клиентские сертификаты:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300   --sslkeyfile ./certs/client-key.pem --sslcertfile ./certs/client-cert.pem
```

При успешном подключении ответ будет выглядеть так:

```shell
   • Connecting to the instance...
   • Connected to localhost:3300

localhost:3300> 
```


## Подключение через Go-коннектор

В этом разделе описано подключение к экземпляру Tarantool DB через [Go-коннектор](https://github.com/tarantool/go-tarantool/).
Пример расположен в директории `./go/` примера `traffic_encryption`.

Для запуска выполните из папки примера следующие команды:
```shell
docker build -t traffic-encryption-go -f go/Dockerfile ./go
docker run -t --rm -v "$(pwd)/certs:/traffic_encryption/go/certs" --network traffic_encryption_tarantooldb_network traffic-encryption-go
```

Go-клиент подключится к узлу через коннектор с шифрованием и запросит текущую
версию платформы Tarantool. Ответ может выглядеть так:
```shell
Tarantool 2.11.6 (Binary) 67c35ab2-c334-49b6-a7a4-f617c81bccaa
```

Код подключения выглядит так:

```go
dialer := tarantool.OpenSslDialer{
	Address:     "tarantool-router:3301",
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

Перейдите в директорию с примером Python-коннектора:

```shell
cd python
```

Установите зависимости:

```shell
./bootstrap.sh
```

Запустите пример:

```shell
source venv/bin/activate
python connect.py
```

Пример выполнения:

```shell
(venv) python connect.py 
- '2.11.6-0-ga5fc633b2'
```

Код подключения выглядит так:

```python
con = tarantool.Connection(
    'localhost',
    3300,
    user="admin",
    password="secret-cluster-cookie",
    transport='ssl',
    ssl_key_file='../certs/client-key.pem',
    ssl_cert_file='../certs/client-cert.pem',
    ssl_ca_file='../certs/ca-cert.pem',
    connection_timeout=0.5,
    socket_timeout=0.5,
)
```
