# Запуск Tarantool DataBase с помощью TT CLI

В этом руководстве показано, как развернуть Tarantool DB локально, используя утилиту [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt) (`tt`).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Остановка кластера](#остановка-кластера)

## Пререквизиты

Для выполнения примера требуются:

* архив для развёртывания Tarantool DB.
  Архив можно скачать в личном кабинете tarantool.io, в разделе [tarantooldb/release/for_deploy/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy);
* утилита [TT CLI](https://www.tarantool.io/ru/doc/2.11/reference/tooling/tt_cli/);
* исходные файлы примера `up_with_tt`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `up_with_tt` расположен в директории `examples/up_with_tt`.
>  * Отдельный архив [up_with_tt.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fup_with_tt&filename=up_with_tt), скачанный из этого репозитория.

## Используемые файлы

В примере `up_with_tt` для конфигурации кластера используются файлы из директории `./tarantooldb/`:

* `tt.yaml` – [конфигурация](https://www.tarantool.io/ru/doc/2.11/reference/tooling/tt_cli/configuration/) TT CLI.
  Чтобы сгенерировать этот файл, используется команда `tt init`;

* `instances.yml` — список узлов кластера для запуска в текущем окружении;
* `replicasets.yml` — описание наборов реплик и их ролей.

## Запуск стенда

Перейдите в директорию с примером `up_with_tt`:

```shell
cd examples/up_with_tt
```

Загрузите в эту директорию архив для развёртывания Tarantool DB и распакуйте его:

```shell
tar -xzvf tarantooldb-<VERSION>.<OS>.<ARCH>.tar.gz
```

Здесь:

- `VERSION` — версия продукта;
- `OS` — поддерживаемая операционная система;
- `ARCH` — архитектура процессора.

Пример: `tarantooldb-1.0.0.linux.x86_64.tar.gz`.

При распаковке будет создана директория `tarantooldb`. Переименовывать её нельзя.
Скопируйте в эту директорию файлы `instances.yml`, `replicasets.yml` и `tt.yml` из директории `up_with_tt`:

```shell
cp *.yml tarantooldb/
```

После копирования перейдите в директорию `tarantooldb`:

```shell
cd tarantooldb
```

Запустите экземпляры Tarantool DB с помощью команды `tt start`:

```shell
tt start tarantooldb
```

Проверить состояние узлов можно, используя команду `tt status`:

```shell
tt status tarantooldb
```

Ответ выглядит так:
```shell
INSTANCE                      STATUS      PID
tarantooldb:router-msk        RUNNING     118242
tarantooldb:router-spb        RUNNING     118243
tarantooldb:storage-1-msk     RUNNING     118244
tarantooldb:storage-1-spb     RUNNING     118245
tarantooldb:storage-2-msk     RUNNING     118246
tarantooldb:storage-2-spb     RUNNING     118247
tarantooldb:stateboard        RUNNING     118249
```

Соберите кластер из узлов Tarantool DB:

```shell
tt cartridge replicasets setup --bootstrap-vshard --name tarantooldb
```

Теперь кластер доступен по адресу одного из узлов (кроме `stateboard`), например [http://localhost:8081](http://localhost:8081).

## Остановка кластера

Остановить кластер можно с помощью команды `tt stop`:

```shell
tt stop tarantooldb
```
