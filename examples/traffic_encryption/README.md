# Шифрование трафика в TarantoolDB

В TarantoolDB имеется возможность шифрования трафика по IPROTO при запросах со стороны клиента и
при репликации.

В данном примере будет продемонстрированно как включить шифрование на стороне кластера TarantoolDB, а также создание шифрованных соединений из коннекторов на Go и Python.

Для запуска примера необходимы:
- docker-compose
- [docker образ TarantoolDB](../../INSTALL.md)
- go версии выше 1.13
- python3

Документация по шифрованию трафика в tarantool доступна [здесь](https://www.tarantool.io/en/doc/latest/enterprise/security/#enterprise-iproto-encryption). 

Задать параметры для SSL шифрования можно через переменные окружения:

- TARANTOOL_TRANSPORT - указывается значение SSL
- TARANTOOL_SSL_SERVER_CA_FILE - путь до корневого сертификата сервера
- TARANTOOL_SSL_SERVER_CERT_FILE - путь до сертификата сервер
- TARANTOOL_SSL_SERVER_KEY_FILE - путь до закрытого ключа сервера
- TARANTOOL_SSL_CLIENT_CA_FILE - путь до корневого сертификата клиента
- TARANTOOL_SSL_CLIENT_CERT_FILE - путь до сертфиката клиента
- TARANTOOL_SSL_CLIENT_KEY_FILE - путь до закрытого ключа клиента
- TARANTOOL_SSL_SERVER_PASSWORD - пароль для ключа сервера
- TARANTOOL_SSL_CLIENT_PASSWORD - пароль для ключа клиента

Для работы с SSL в tarantool необходимы сертификаты. Каждому инстансу необходим сертификат как для сервера, так и для клиента т.к. каждому инстансу нужно уметь подключаться ко всем остальным инстансам. Инстанс TarantoolDB при использовании SSL является как "сервером" так и "клиентом" по отношению к другим инстансам. Поэтому необходимо всегда передавать серверные так и клиентские аргументы для инстанса в кластере TarantoolDB.

Сертификаты находятся в директории [boostrap](./bootstrap/) и должны быть доступны для каждого инстанса. Сертификаты сгенерированы скриптом [gen.sh](./bootstrap/gen.sh).

Представленный в примере вариант набора сертификатов не единственный, можно использовать и другую схему. Например без паролей для ключей, тогда не нужно указывать `TARANTOOL_SSL_SERVER_PASSWORD` и `TARANTOOL_SSL_CLIENT_PASSWORD` или с самоподписанный сертификатами, тогда не нужно передавать `TARANTOOL_SSL_SERVER_CA_FILE`, `TARANTOOL_SSL_CLIENT_CA_FILE`.

Для ключей сервера и клиента заданы пароль 12345/54321 соответственно.

Переменные окружения для инстанса в примере:

```yaml
environment:
    - TARANTOOL_ADVERTISE_URI=tarantool-router:3301
    - TARANTOOL_TRANSPORT=SSL
    - TARANTOOL_SSL_SERVER_CA_FILE=/bootstrap/ca-cert.pem
    - TARA`NTOOL_SSL_SERVER_CERT_FILE=/bootstrap/server-cert.pem
    - TARANTOOL_SSL_SERVER_KEY_FILE=/bootstrap/server-key.pem
    - TARANTOOL_SSL_CLIENT_CA_FILE=/bootstrap/ca-cert.pem
    - TARANTOOL_SSL_CLIENT_CERT_FILE=/bootstrap/client-cert.pem
    - TARANTOOL_SSL_CLIENT_KEY_FILE=/bootstrap/client-key.pem
    - TARANTOOL_SSL_SERVER_PASSWORD=12345
    - TARANTOOL_SSL_CLIENT_PASSWORD=54321
```

## Запуск примера и подключение через tt

Выполняем `docker-compose up` и должидаемся поднятия кластера.

Теперь попробуем через `tt` как обычно подключиться к инстансу.

`tt connect admin:secret-cluster-cookie@localhost:3300`

В ответ получим:

```bash
• Connecting to the instance...
⨯ failed to run interactive console: failed to create new console: failed to connect: failed to get protocol: failed to read Tarantool greeting: read tcp [::1]:60894->[::1]:3300: i/o timeout
```

Теперь попробуем с указанием клиентских сертификатов:

``tt connect admin:secret-cluster-cookie@localhost:3300   --sslkeyfile ./bootstrap/client-key.pem --sslcertfile ./bootstrap/client-cert.pem``

В `Enter PEM pass phrase` вводим пароль для ключа клиента: `54321`.

В результате нам удастся подключиться:

```bash
   • Connecting to the instance...
Enter PEM pass phrase:
   • Connected to admin:secret-cluster-cookie@localhost:3300

admin:secret-cluster-cookie@localhost:3300>
```

## Подключение к инстансу через go коннектор

Рассмотрим пример подключения к инстансу TarantoolDB через [go-connector](https://github.com/tarantool/go-tarantool/).
Пример расположен [здесь](./go/main.go).

Поднимем кластер  `docker-compose up`, а затем запускаем пример `cd go && go run main.go`.

Код подключения выглядит так:

```go
dialer := tarantool.OpenSslDialer{
    Address:     "localhost:3300",
    User:        "admin",
    Password:    "secret-cluster-cookie",
    SslKeyFile:  "../bootstrap/client-key.pem",
    SslCertFile: "../bootstrap/client-cert.pem",
    SslCaFile:   "../bootstrap/ca-cert.pem",
    SslPassword: "54321",
}

opts := tarantool.Opts{}

conn, err := tarantool.Connect(ctx, dialer, opts)
if err != nil {
    fmt.Println(err)
    return
}
```

Опции аналогичны тем, что передавались для `tt`.

## Подключение к инстансу через python коннектор

Рассмотрим пример подключения к инстансу TarantoolDB через [python-connector](https://github.com/tarantool/go-tarantool/).
Пример расположен [здесь](./python/connect.py).

Для запуска примера необходимо установить коннектор. Выполните следующие команды:

1. `cd python` - заходим в директорию с примером
2. `./bootstrap.sh` - устанавливаем зависимости
3. `python connect.py` - запускаем пример. 

Пример выполнения:

```bash
(venv) python connect.py 
- '2.11.2-0-g94f8b6aad-r609-gc64'
```

Код аналогичен подключению через tt и go-connector.

```python
con = tarantool.Connection(
    'localhost',
    3300,
    user="admin",
    password="secret-cluster-cookie",
    transport='ssl',
    ssl_key_file='../bootstrap/client-key.pem',
    ssl_cert_file='../bootstrap/client-cert.pem',
    ssl_ca_file='../bootstrap/ca-cert.pem',
    ssl_password='54321',
    connection_timeout=0.5,
    socket_timeout=0.5,
)
```

