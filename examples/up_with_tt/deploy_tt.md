(admin_guide-deploy_tt)=
#  Запуск Tarantool DB с помощью TT CLI

В этом руководстве показано, как развернуть Tarantool DB локально, используя утилиту [TT CLI](install-install_tt) (`tt`).

Содержание:

* [](admin_guide-deploy_tt-files)
* [](admin_guide-deploy_tt-start_example)
* [](admin_guide-deploy_tt-stop_example)

(admin_guide-deploy_tt-files)=
## Используемые файлы

В примере для конфигурации кластера используются файлы из директории `./tarantooldb/`:

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

Загрузите в эту директорию архив для развёртывания Tarantool DB.
Архив можно скачать в customer zone, в разделе [tarantooldb/release/for_deploy/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy).

Распакуйте архив:

```shell
tar -xzvf tarantooldb-<VERSION>.tar.gz
```

Здесь:
* `VERSION`-- версия Tarantool DB. Пример: `tarantooldb-0.8.0.linux.x86_64.tar.gz`.

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
INSTANCE                      STATUS          PID
tarantooldb:stateboard        RUNNING         18939
tarantooldb:router-msk        NOT RUNNING     
tarantooldb:router-spb        NOT RUNNING     
tarantooldb:storage-1-msk     NOT RUNNING     
tarantooldb:storage-1-spb     NOT RUNNING     
tarantooldb:storage-2-msk     NOT RUNNING     
tarantooldb:storage-2-spb     NOT RUNNING
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
