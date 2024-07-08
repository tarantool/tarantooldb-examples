# Шифрование трафика

Tarantool DB позволяет шифровать трафик по IPROTO при запросах от клиента и при репликации.

В этом руководстве описано, как включить шифрование на стороне кластера Tarantool DB,
а также создать шифрованные соединения из коннекторов на Go и Python.

Документацию по шифрованию трафика можно найти в [документации Tarantool Enterprise](https://www.tarantool.io/ru/doc/2.11/enterprise/security/#enterprise-iproto-encryption). 

Руководство включает следующие шаги:

* [](admin_guide-traffic_encryption-prereq)
* [](admin_guide-traffic_encryption-ssl_setup)
* [](admin_guide-traffic_encryption-connect)
* [](admin_guide-traffic_encryption-go)
* [](admin_guide-traffic_encryption-python)

(admin_guide-traffic_encryption-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install.md) Tarantool DB;
* приложение Docker compose;
* утилита [TT CLI](install-install_tt);
* Go версии 1.13 или выше;
* python3;
* исходные файлы примера `traffic_encryption`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `traffic_encryption` расположен в таком архиве в директории `./doc/examples/traffic_encryption/`.

  * Отдельный архив [traffic_encryption.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/traffic_encryption/traffic_encryption.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-traffic_encryption-ssl_setup)=
## Настройка SSL-шифрования

Для работы с SSL в Tarantool используются SSL-сертификаты.
Экземпляр Tarantool DB здесь -- это одновременно и сервер, и клиент по отношению к другим экземплярам.
Чтобы любой экземпляр мог подключаться ко всем остальным экземплярам, для каждого экземпляра требуется как сертификат
сервера, так и сертификат клиента.
Это означает, что для экземпляра кластера всегда нужно передавать как серверные, так и клиентские аргументы.

В примере `traffic_encryption` сертификаты находятся в директории `./bootstrap/` и
должны быть доступны для каждого экземпляра.
Сертификаты генерируются с помощью скрипта `./bootstrap/gen.sh`.

В примере заданы параметры SSL-шифрования для экземпляра с помощью переменных окружения:

```{literalinclude} docker-compose.yml
:start-at: environment
:end-before: volumes
:language: yaml
:dedent:
```

Здесь:

* `TARANTOOL_ADVERTISE_URI` -- адрес и порт, на котором узел доступен в кластере;
* `TARANTOOL_TRANSPORT` -- значение SSL;
* `TARANTOOL_SSL_SERVER_CA_FILE` -- путь к корневому сертификату сервера;
* `TARANTOOL_SSL_SERVER_CERT_FILE` -- путь к сертификату сервера;
* `TARANTOOL_SSL_SERVER_KEY_FILE` -- путь к закрытому ключу сервера;
* `TARANTOOL_SSL_CLIENT_CA_FILE` -- путь к корневому сертификату клиента;
* `TARANTOOL_SSL_CLIENT_CERT_FILE` -- путь к сертификату клиента;
* `TARANTOOL_SSL_CLIENT_KEY_FILE` -- путь к закрытому ключу клиента;
* `TARANTOOL_SSL_SERVER_PASSWORD` -- пароль для ключа сервера;
* `TARANTOOL_SSL_CLIENT_PASSWORD` -- пароль для ключа клиента.

(admin_guide-traffic_encryption-connect)=
## Подключение к узлу с помощью клиентских сертификатов

Перейдите в папку с примером `traffic_encryption` и запустите стенд:

```shell
cd ./doc/examples/traffic_encryption/
docker compose up
```

Попытайтесь подключиться к экземпляру, используя команду `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Ответ будет выглядеть так:

```bash
• Connecting to the instance...
⨯ failed to run interactive console: failed to create new console: failed to connect: failed to get protocol: failed to read Tarantool greeting: read tcp [::1]:62950->[::1]:3300: i/o timeout
```

Подключитесь к узлу снова, используя клиентские сертификаты:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300   --sslkeyfile ./bootstrap/client-key.pem --sslcertfile ./bootstrap/client-cert.pem
```

После ввода команды в терминале появится сообщение `Enter PEM pass phrase`. Введите пароль для ключа клиента:

```shell
54321
```

При успешном подключении ответ будет выглядеть так:

```bash
   • Connecting to the instance...
Enter PEM pass phrase:
   • Connected to localhost:3300

localhost:3300> 
```

(admin_guide-traffic_encryption-go)=
## Подключение через Go-коннектор

В этом разделе описано подключение к экземпляру Tarantool DB через [Go-коннектор](https://github.com/tarantool/go-tarantool/).
Пример расположен в директории `./go/` примера `traffic_encryption`.

Запустите кластер:

```shell
docker compose up
```
 
Перейдите в директорию с примером Go-коннектора и запустите его:

```shell
cd go && go run main.go
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
python connect.py
```

Пример выполнения:

```bash
(venv) python connect.py 
- '2.11.2-0-g94f8b6aad-r609-gc64'
```

Код подключения выглядит так:

```{literalinclude} python/connect.py
:start-at: con = tarantool.Connection(
:end-before: print(con.eval
:language: python
:dedent:
```
