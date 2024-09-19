(admin_guide-traffic_encryption)=
# Шифрование трафика

Tarantool DB позволяет шифровать трафик по IPROTO при запросах от клиента и при репликации.

В этом руководстве описано, как включить шифрование на стороне кластера Tarantool DB,
а также создать шифрованные соединения из коннекторов на Go и Python.

Документацию по шифрованию трафика можно найти в [документации Tarantool Enterprise](https://www.tarantool.io/ru/doc/latest/concepts/configuration/configuration_connections/#securing-connections-with-ssl). 

Руководство включает следующие шаги:

* [](admin_guide-traffic_encryption-prereq)
* [](admin_guide-traffic_encryption-start_example)
* [](admin_guide-traffic_encryption-ssl_setup)
* [](admin_guide-traffic_encryption-files)
* [](admin_guide-traffic_encryption-tt)
* [](admin_guide-traffic_encryption-go)
* [](admin_guide-traffic_encryption-python)
* [](admin_guide-traffic_encryption-netbox)
* [](admin_guide-traffic_encryption-stop_example)

(admin_guide-traffic_encryption-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
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
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `traffic_encryption` расположен в таком архиве в директории `./doc/examples/traffic_encryption/`.

  * Отдельный архив [traffic_encryption.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/traffic_encryption/traffic_encryption.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-traffic_encryption-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301--3303
* 3310, 3311
* 8081

Порты 3310 и 3311 необходимы для корректного подключения между экземплярами через SSL в [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

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
- клиентских приложений для проверки подключения.

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

(admin_guide-traffic_encryption-ssl_setup)=
## Настройка SSL-шифрования

Для работы с SSL в Tarantool используются SSL-сертификаты.
Экземпляр Tarantool DB здесь -- это одновременно и сервер, и клиент по отношению к другим экземплярам.
Чтобы любой экземпляр мог подключаться ко всем остальным экземплярам, для каждого экземпляра требуется как сертификат
сервера, так и сертификат клиента.
Это означает, что для экземпляра кластера всегда нужно передавать как серверные, так и клиентские аргументы.

В примере `traffic_encryption` сертификаты находятся в директории `./certs/` и
должны быть доступны для каждого экземпляра.
Сертификаты генерируются с помощью скрипта `./certs/gen.sh`.

Также в примере используется TCM. В этом случае нужно создавать отдельные сертификаты для каждого экземпляра.
Сертификаты для экземпляров генерируются с помощью скриптов `./certs/gen_router.sh` и `./certs/gen_storage.sh`.
Чтобы сертификаты в TCM считывались корректно, в скриптах для генерации сертификатов на хранилище используется CA сертификат роутера.

В примере заданы параметры SSL-шифрования для экземпляра с помощью переменных окружения:

```{literalinclude} cluster/docker-compose.yml
:start-at: TT_CLI_SSLKEYFILE
:end-before: command
:language: yaml
:dedent:
```

Здесь:

- `TT_CLI_SSLKEYFILE` -- путь к закрытому ключу клиента.
- `TT_CLI_SSLCERTFILE` -- путь к сертификату клиента;

Эти переменные окружения необходимы для корректной работы конфигурации при использовании Tarantool из клиентских приложений.

(admin_guide-traffic_encryption-files)=
## Используемые файлы

Для запуска и настройки кластера используются файлы из папки ``traffic_encryption``:

* `certs/`
  * `gen.sh` -- скрипт генерации локального набора сертификатов для стенда;
* `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  * `migrations/scenario` -- директория, содержащая файлы с описанием миграций; 
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;  
* `go/` -- директория с файлами для создания подключения через Go-коннектор;
* `python/` -- директория с файлами для создания подключения через Python-коннектор;
* `tools/` -- директория с файлами для запуска кластера etcd и средств мониторинга:
  * `docker-compose.yml` -- описание узлов кластера etcd и средств мониторинга;
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

(admin_guide-traffic_encryption-tt)=
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

(admin_guide-traffic_encryption-go)=
## Подключение через Go-коннектор

В этом разделе описано подключение к экземпляру Tarantool DB через [Go-коннектор](https://github.com/tarantool/go-tarantool/).
Пример расположен в директории `./go/` примера `traffic_encryption`.

Перейдите в директорию с примером Go-коннектора и запустите его:

```shell
cd go && go run main.go && cd ..
```

Go-клиент подключится к узлу через коннектор и запросит текущую
версию платформы Tarantool. Ответ может выглядеть так:
```
Tarantool 3.2.0 (Binary) 2404fdc5-4438-485a-b2e1-18fae889b95c
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
или
```shell
python3 connect.py
```

Результат может выглядеть так:
```bash 
- '3.2.0-0-g19607a903'
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
В открывшемся окне перейдите на вкладку **Terminal -> Direct**.

(admin_guide-traffic_encryption-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
