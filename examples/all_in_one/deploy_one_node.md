(admin_guide-deploy_one_node)=
# Запуск кластера из одного узла через Docker Compose

В этом руководстве показано, как развернуть кластер Tarantool DB из одного узла с помощью Docker Compose.
В примере применяется нестандартный способ первоначального запуска модуля [шардирования](admin_guide-sharding)
-- с помощью встроенного модуля.
Этот способ можно включить через конфигурацию кластера:

```{literalinclude} cluster/config.yml
:start-at: groups
:end-at: app.vshard_bootstrapper
:language: yaml
:dedent:
```

Содержание:

* [](admin_guide-deploy_one_node-prereq)
* [](admin_guide-deploy_one_node-start_example)
* [](admin_guide-deploy_one_node-files)
* [](admin_guide-deploy_one_node-stop_example)

(admin_guide-deploy_one_node-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `all_in_one`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `all_in_one` расположен в таком архиве в директории `./doc/examples/all_in_one/`.
    
  * Отдельный архив [all_in_one.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/all_in_one/all_in_one.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-deploy_one_node-start_example)=
## Запуск стенда

Перейдите в директорию примера `all_in_one`:

```shell
cd ./doc/examples/all_in_one/
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:

- кластера Tarantool DB из одного узла. Этот узел одновременно выполняет роль и роутера, и хранилища;
- кластера etcd из 3 узлов;
- одного узла [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

После применения настроек кластер будет выглядеть так:

![](/images/tcm-stateboard-1_node.png)

(admin_guide-deploy_one_node-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `all_in_one`:

* `cluster/` -- директория с файлами для запуска кластера Tarantool DB:
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  * `migrations/scenario` -- директория, содержащая файлы с описанием миграций;
* `tools/` -- директория с файлами для запуска кластера etcd и TCM:
  * `docker-compose.yml` -- описание узлов кластера etcd;
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/);
* `Makefile` -- инструкции для утилиты `make` для запуска и остановки всего стенда.

(admin_guide-deploy_one_node-stop_example)=
## Остановка кластера

Остановить кластер можно так:

```shell
make stop
```
