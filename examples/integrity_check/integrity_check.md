(admin_guide-integrity_check)=
#  Проверка целостности приложения при его запуске

В этом руководстве показано, как упаковать и запустить приложение Tarantool DB с проверкой целостности (integrity check) с помощью утилиты [tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/).

При создании архива приложения tt CLI генерирует дополнительные файлы с хешами всех компонентов приложения с помощью опции `--integrity_check`. В дальнейшем при запуске Tarantool DB будет отслеживать целостность всех компонентов приложения во время работы.

Содержание:

* [](admin_guide-integrity_check-prereq)
* [](admin_guide-integrity_check-files)
* [](admin_guide-integrity_check-keypair)
* [](admin_guide-integrity_check-pack)
* [](admin_guide-integrity_check-install)
* [](admin_guide-integrity_check-run)
* [](admin_guide-integrity_check-demo)
* [](admin_guide-integrity_check-etcd)
* [](admin_guide-integrity_check-stop)

(admin_guide-integrity_check-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* архив для развёртывания Tarantool DB.
  Архив можно скачать в личном кабинете tarantool.io, в разделе [tarantooldb/release/for_deploy/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy);
* утилита tt CLI версии 2.11.1 или выше;
* OpenSSL для создания ключевой пары;
* Docker и Docker Compose (для варианта с централизованным хранилищем конфигурации на основе Tarantool).

Для успешного запуска должны быть свободны следующие порты:
* 3301--3305 -- порты кластера Tarantool DB;
* 2379, 2389, 2399 -- порты etcd для клиентских подключений (для варианта с централизованным хранилищем конфигурации).

(admin_guide-integrity_check-files)=
## Используемые файлы

В примере `integrity_check` используются следующие файлы:

* `config.yml` -- конфигурация и топология кластера;
* `instances.yml` -- список узлов кластера для запуска в текущем окружении;
* `tt.yml` -- конфигурация утилиты tt CLI;
* `etcd/` -- директория с файлами для запуска кластера etcd:
  * `config.yml` -- конфигурация для подключения кластера к etcd;
  * `docker-compose.yml` -- описание кластера etcd из 3 узлов.

(admin_guide-integrity_check-keypair)=
## Создание ключевой пары

Для упаковки приложения с опцией `--with-integrity_check` сначала необходимо создать ключевую пару:

```shell
cd ./doc/examples/integrity_check
openssl genrsa -traditional -out private.pem 2048
openssl rsa -in private.pem -pubout > public.pem
```

(admin_guide-integrity_check-pack)=
## Упаковка приложения

Загрузите архив для развёртывания Tarantool DB и распакуйте его в папку примера `./doc/examples/integrity_check`:

```shell
tar -xzvf tarantooldb-<VERSION>.<OS>.<ARCH>.tar.gz
```

Здесь:

- `VERSION` -- версия продукта;
- `OS` -- поддерживаемая операционная система;
- `ARCH` -- архитектура процессора.

Пример: `tarantooldb-2.2.3.linux.x86_64.tar.gz`.

При распаковке будет создана директория `tarantooldb`.

Скопируйте в эту директорию файлы `instances.yml`, `config.yml` и `tt.yml` из директории примера:

```shell
cp *.yml tarantooldb/
```

Запустите кластер, чтобы проверить работу приложения:

```shell
cd tarantooldb
./tt start tarantooldb
```

Проверить состояние узлов можно, используя команду `tt status`:

```shell
./tt status tarantooldb
```

Ответ выглядит так:
```
INSTANCE                      STATUS      PID
tarantooldb:storage-001-a     RUNNING     98110
tarantooldb:storage-001-b     RUNNING     98111
tarantooldb:storage-002-a     RUNNING     98112
tarantooldb:storage-002-b     RUNNING     98113
tarantooldb:router-001-a      RUNNING     98114
```

Остановите кластер перед упаковкой:

```shell
./tt stop -y tarantooldb
```

После упакуйте приложение в архив с генерацией хеш-сумм компонентов с указанием приватного ключа. Для упаковки используется команда `tt pack`:

```shell
./tt pack tgz --with-integrity-check ../private.pem
```

Полный список параметров для команды `tt pack` приведен в документации tt CLI в разделе [Упаковка приложения](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/pack/).
Подробнее о запуске с проверкой целостности можно также узнать в документации tt CLI в [соответствующем разделе](https://www.tarantool.io/en/doc/latest/tooling/tt_cli/start/#integrity-check).

(admin_guide-integrity_check-install)=
## Установка приложения

Распакуйте архив в текущую директорию. При распаковке будет создана папка `tarantooldb`, переименуйте её в `tarantooldb_ic` и переместите в корневую директорию примера:

```shell
tar -xzvf tarantooldb*gz
mv tarantooldb ../tarantooldb_ic
```

(admin_guide-integrity_check-run)=
## Запуск в режиме проверки целостности

Перейдите в папку распакованного приложения `./doc/examples/integrity_check/tarantooldb_ic`.
Для запуска кластера в режиме проверки целостности укажите в команде `tt start` опцию `--integrity-check` и публичный ключ.
Дополнительно задана опция `--integrity-check-period` со значением `10`. Опция означает, что проверка целостности файлов приложения будет происходить раз в 10 секунд.

```shell
cd ../tarantooldb_ic
./tt --integrity-check ../public.pem start --integrity-check-period 10
```

Проверить состояние узлов можно, используя команду `./tt status`:

```shell
./tt status
```

Ответ выглядит так:
```
INSTANCE                      STATUS      PID
tarantooldb_ic:storage-001-a  RUNNING     98110
tarantooldb_ic:storage-001-b  RUNNING     98111
tarantooldb_ic:storage-002-a  RUNNING     98112
tarantooldb_ic:storage-002-b  RUNNING     98113
tarantooldb_ic:router-001-a   RUNNING     98114
```

Выполните начальную загрузку модуля шардирования `vshard`:

```shell
./tt replicaset vshard bootstrap tarantooldb_ic:router-001-a
```

Подключитесь к любому экземпляру и проверьте его состояние:

```shell
./tt connect tarantooldb_ic:storage-001-a
```

Выполните команду `box.info()`:

```lua
box.info()
```

Ответ будет содержать информацию об экземпляре.

Для отключения от экземпляра нажмите `CTRL+D`.

(admin_guide-integrity_check-demo)=
## Проверка работы контроля целостности

Теперь проверьте, что контроль целостности работает корректно. Для этого нужно изменить конфигурационный файл при запущенном кластере.
Внесите любое изменение в файл `config.yml`. Например, добавьте комментарий:

```shell
echo "# test comment" >> config.yml
```

После изменения файла кластер в течение 10 секунд обнаружит нарушение целостности и перейдёт в нерабочее состояние. Проверить это можно командой `./tt status`:

```shell
./tt status
```

Ответ будет выглядеть так:
```
INSTANCE                      STATUS      PID
tarantooldb_ic:storage-001-a  NOT RUNNING -
tarantooldb_ic:storage-001-b  NOT RUNNING -
tarantooldb_ic:storage-002-a  NOT RUNNING -
tarantooldb_ic:storage-002-b  NOT RUNNING -
tarantooldb_ic:router-001-a   NOT RUNNING -
```

В логах экземпляров можно увидеть ошибку `integrity check failed`. Посмотреть логи можно с помощью команды ниже:

```shell
cat var/log/router-001-a/tt.log | grep "integrity check failed"
```

Пример ошибки в логе:
```
(ERROR): periodic integrity check failed: "hash mismatch for <name_file> ..."
```

Для восстановления работоспособности верните файл конфигурации к состоянию до внесения изменений или создайте архив заново с правильными хешами.

Перед выполнением следующего раздела примера остановите кластер и удалите папку `tarantooldb_ic` из корневой директории примера:

```shell
./tt stop
cd ..
rm -rf tarantooldb_ic
```

(admin_guide-integrity_check-etcd)=
## Контроль целостности при использовании централизованного хранилища конфигурации

Если конфигурация кластера хранится в централизованном хранилище (etcd или TBCS), выполните следующие шаги.

### Запуск кластера etcd

Сначала необходимо запустить кластер etcd. Для этого создайте внешнюю сеть Docker и перейдите в директорию с файлом `docker-compose.yml`:

```shell
docker network create tarantooldb_network
cd etcd
docker compose up -d
```

```{admonition} Примечание
:class: note

В некоторых системах команда может выглядеть как `docker-compose up -d` (через дефис).
```

Проверить состояние кластера etcd можно следующей командой:

```shell
docker compose ps
```

Ответ выглядит так:
```
NAME             IMAGE                         COMMAND                  SERVICE   CREATED         STATUS         PORTS
etcd-etcd1-1     quay.io/coreos/etcd:v3.5.25   "etcd --name etcd1 …"    etcd1     5 seconds ago   Up 4 seconds   0.0.0.0:2379->2379/tcp
etcd-etcd2-1     quay.io/coreos/etcd:v3.5.25   "etcd --name etcd2 …"    etcd2     5 seconds ago   Up 4 seconds   0.0.0.0:2389->2379/tcp
etcd-etcd3-1     quay.io/coreos/etcd:v3.5.25   "etcd --name etcd3 …"    etcd3     5 seconds ago   Up 4 seconds   0.0.0.0:2399->2379/tcp
```

### Настройка конфигурации

Замените файл конфигурации кластера `tarantooldb/config.yml` на конфигурацию для работы с etcd:

```shell
cp -f config.yml ../tarantooldb/config.yml
```

Пример содержимого файла `config.yml` для работы с etcd:

```yaml
config:
  etcd:
    endpoints:
      - http://127.0.0.1:2379
      - http://127.0.0.1:2389
      - http://127.0.0.1:2399
    prefix: /tdb-ic
```

Загрузите конфигурацию кластера в централизованное хранилище, указав в команде опцию `--with-integrity-check`.
В команде загружается файл `config.yml` из корня примера, который содержит топологию кластера.

```shell
cd ../tarantooldb
./tt cluster publish "http://localhost:2379/tdb-ic" ../config.yml --with-integrity-check ../private.pem
```

Далее упакуйте приложение в архив:

```shell
./tt pack tgz --with-integrity-check ../private.pem
```

Распакуйте приложение в целевую папку и запустите его с опцией `--integrity-check`:

```shell
tar -xzvf tarantooldb*gz
mv tarantooldb ../tarantooldb_ic
cd ../tarantooldb_ic
./tt --integrity-check ../public.pem start --integrity-check-period 10
```

Проверить состояние узлов можно, используя команду `./tt status`:

```shell
./tt status
```

### Проверка работы контроля целостности

При использовании централизованного хранилища конфигурации проверка целостности работает для конфигурации, загруженной в etcd или TBCS.

Для проверки сначала внесите произвольное изменение в файл конфигурации:

```shell
echo "# test comment" >> ../config.yml
```

Затем загрузите измененную конфигурацию в etcd без опции `--with-integrity-check`:

```shell
./tt cluster publish "http://localhost:2379/tdb-ic" ../config.yml
```

Подключитесь к экземпляру кластера и проверьте его статус:

```shell
./tt connect tarantooldb_ic:storage-001-a
```

Выполните команду `box.info()`, чтобы проверить наличие предупреждений:

```lua
box.info()
```

Ответ будет содержать ошибку о нарушении целостности:

```lua
- type: error
  message: ...'integrity check failed: invalid hash or signature by key "/tdb-ic/config/all"'
```

Для восстановления целостности необходимо загрузить исходную конфигурацию без опции `--with-integrity-check`, либо измененную с указанием опции `--with-integrity-check`:

```shell
./tt cluster publish "http://localhost:2379/tdb-ic" ../config.yml --with-integrity-check ../private.pem
```

(admin_guide-integrity_check-stop)=
## Остановка стенда

Остановить стенд можно с помощью команды `./tt stop`:

```shell
./tt stop -y
```

Для остановки кластера etcd перейдите в директорию `etcd` и выполните команду ниже:

```shell
cd ../etcd
docker compose down
docker network rm tarantooldb_network
```

```{admonition} Примечание
:class: note

В некоторых системах команда может выглядеть как `docker-compose down` (через дефис).
```
