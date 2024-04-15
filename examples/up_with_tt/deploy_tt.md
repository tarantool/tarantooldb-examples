(admin_guide-deploy_tt)=
#  Запуск Tarantool DB с помощью TT CLI

В этом руководстве показано, как развернуть Tarantool DB локально, используя утилиту [TT CLI](install-install_tt) (`tt`).

Содержание:

* [](admin_guide-deploy_tt-prereq)
* [](admin_guide-deploy_tt-files)
* [](admin_guide-deploy_tt-start_example)
* [](admin_guide-deploy_tt-stop_example)

(admin_guide-deploy_tt-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* архив для развёртывания Tarantool DB.
  Архив можно скачать в customer zone, в разделе [tarantooldb/release/for_deploy/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy);
* исходные файлы примера `up_with_tt`.
  Пример находится в директории `./doc/examples/up_with_tt/`.
  Скачать архив с исходными файлами примера можно на [сайте Tarantool](https://tarantool.io/ru/tarantooldb/doc/latest/examples/up_with_tt/up_with_tt.tar.gz).

(admin_guide-deploy_tt-files)=
## Используемые файлы

В примере `up_with_tt` для конфигурации кластера используются файлы из директории `./tarantooldb/`:

* `tt.yaml` -- [конфигурация](https://www.tarantool.io/en/doc/latest/reference/tooling/tt_cli/configuration/) TT CLI.
  Чтобы сгенерировать этот файл, используется команда `tt init`;

* `instances.yml` -- список узлов кластера для запуска в текущем окружении;
* `replicasets.yml` -- описание наборов реплик и их ролей.

(admin_guide-deploy_tt-start_example)=
## Запуск стенда

Перейдите в директорию с примером `up_with_tt`:

```shell
cd ./doc/examples/up_with_tt/
```

Загрузите в эту директорию архив для развёртывания Tarantool DB и распакуйте его:

```shell
tar -xzvf tarantooldb-<VERSION>.<OS>.<ARCH>.tar.gz
```

Здесь:

- `VERSION` -- версия продукта;
- `OS` -- поддерживаемая операционная система;
- `ARCH` -- архитектура процессора.

Пример: `tarantooldb-0.8.0.linux.x86_64.tar.gz`.

При распаковке будет создана директория `tarantooldb`. Переименовывать её нельзя.
Скопируйте в эту директорию файлы `instances.yml`, `replicasets.yml` и `tt.yml` из директории `up_with_tt`:

```shell
cp *.yml tarantooldb/
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
```
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

Теперь кластер доступен по адресу одного из узлов (кроме `stateboard`), например, [http://localhost:8081](http://localhost:8081).

(admin_guide-deploy_tt-stop_example)=
## Остановка кластера

Остановить кластер можно с помощью команды `tt stop`:

```shell
tt stop tarantooldb
```
