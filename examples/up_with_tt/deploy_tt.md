(admin_guide-deploy_tt)=
#  Запуск Tarantool DB вручную

В этом руководстве показано, как развернуть Tarantool DB локально, используя утилиту [tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/) (`tt`).
Утилита tt CLI есть в составе архива Tarantool DB для развертывания, ее отдельная установка не требуется.
Если нужно скачать утилиту отдельно, обратитесь к разделу [](install-install_tt).

Содержание:

* [](admin_guide-deploy_tt-prereq)
* [](admin_guide-deploy_tt-files)
* [](admin_guide-deploy_tt-start_example)
* [](admin_guide-deploy_tt-stop_example)

(admin_guide-deploy_tt-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* архив для развёртывания Tarantool DB.
  Архив можно скачать в личном кабинете tarantool.io, в разделе [tarantooldb/release/for_deploy/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy);
* утилита tt CLI;
* исходные файлы примера `up_with_tt`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `up_with_tt` расположен в таком архиве в директории `./doc/examples/up_with_tt/`.
    
  * Отдельный архив [up_with_tt.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/up_with_tt/up_with_tt.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-deploy_tt-files)=
## Используемые файлы

В примере `up_with_tt` для конфигурации кластера используются файлы из директории `./tarantooldb/`:

- `config.yml` -- конфигурация и топология кластера;
- `instances.yml` -- список узлов кластера для запуска в текущем окружении;
- `tt.yml` -- [конфигурация](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/configuration/) tt CLI.
  Чтобы сгенерировать этот файл, используется команда `tt init`.

Обратите внимание на опцию `instances_enabled` в файле `tt.yml`.
Здесь опция указывает `tt` на то, что текущая директория может содержать `config.yml` и `instances.yml` или
содержит символьную ссылку на приложение Tarantool 3 с этими файлами.

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

Пример: `tarantooldb-3.0.0.linux.x86_64.tar.gz`.

При распаковке будет создана директория `tarantooldb`.
Переименовывать её нельзя.

Скопируйте в эту директорию файлы `instances.yml`, `config.yml` и `tt.yml` из директории `up_with_tt`:

```shell
cp *.yml tarantooldb/
```

Запустите экземпляры Tarantool DB с помощью команды `tt start`:

```shell
tt start tarantooldb
```

Команда развернет кластер Tarantool DB из 1 роутера и 2 наборов реплик по 2 хранилища.
Проверить состояние узлов можно, используя команду `tt status`:

```shell
tt status tarantooldb
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

Теперь кластер доступен по IPROTO по адресу одного из узлов.
Подключиться к узлу можно по его названию:

``
tt connect tarantooldb:storage-001-a
``

(admin_guide-deploy_tt-stop_example)=
## Остановка кластера

Остановить кластер можно с помощью команды `tt stop`:

```shell
tt stop tarantooldb
```
