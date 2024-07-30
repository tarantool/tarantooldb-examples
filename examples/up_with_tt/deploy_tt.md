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
  Архив можно скачать в личном кабинете tarantool.io, в разделе [tarantooldb/release/for_deploy/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy);
* утилита [TT CLI](https://www.tarantool.io/ru/doc/latest/reference/tooling/tt_cli/);
* исходные файлы примера `up_with_tt`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `up_with_tt` расположен в таком архиве в директории `./doc/examples/up_with_tt/`.
    
  * Отдельный архив [up_with_tt.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/up_with_tt/up_with_tt.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-deploy_tt-files)=
## Используемые файлы

В примере `up_with_tt` для конфигурации кластера используются файлы из директории `./tarantooldb/`:

* `tt.yaml` -- [конфигурация](https://www.tarantool.io/ru/doc/latest/reference/tooling/tt_cli/configuration/) TT CLI.
  Чтобы сгенерировать этот файл, используется команда `tt init`;

Обратите внимание на опцию ``instances_enabled``. На нашем случае опция говорит tt о том, что текущая директория может содержать `config.yml` и `instances.yml` или содержит символьную ссылку на приложение Tarantool 3 с этими файлами.

(admin_guide-deploy_tt-start_example)=
## Запуск стенда
Перейдите в директорию с примером `up_with_tt`:

```shell
cd ./doc/examples/up_with_tt/
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
tarantooldb:storage-001-a     RUNNING     98110
tarantooldb:storage-001-b     RUNNING     98111
tarantooldb:storage-002-a     RUNNING     98112
tarantooldb:storage-002-b     RUNNING     98113
tarantooldb:router-001-a      RUNNING     98114
```


Теперь кластер доступен по IPROTO по адресу одного из узлов. Можно также подключиться по названию узла.

``
tt connect tarantooldb:storage-001-a
``

(admin_guide-deploy_tt-stop_example)=
## Остановка кластера

Остановить кластер можно с помощью команды `tt stop`:

```shell
tt stop tarantooldb
```
