(admin_guide-deploy_one_node)=
# Запуск кластера из одного узла через Docker compose

В этом руководстве показано, как развернуть кластер Tarantool DB из одного узла с помощью Docker compose.

Содержание:

* [](admin_guide-deploy_one_node-prereq)
* [](admin_guide-deploy_one_node-files)
* [](admin_guide-deploy_one_node-start_example)
* [](admin_guide-deploy_one_node-config)
* [](admin_guide-deploy_one_node-stop_example)

(admin_guide-deploy_one_node-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `all_in_one`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-0.8.0.tar.gz`.
    Пример `all_in_one` расположен в таком архиве в директории `./doc/examples/all_in_one/`.
    
  * Отдельный архив [all_in_one.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/all_in_one/all_in_one.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-deploy_one_node-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `all_in_one`:

* `docker-compose.yml` -- описание узлов кластера. Узнать больше: [](admin_guide-deploy_docker_compose).
* `config.yml` -- топология и конфигурация кластера;
* `migrations/scenario` -- директория, содержащая файлы с описанием миграций; 
* `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).
  Кроме того, при запуске примера скрипт `make_config_tcm_yml.lua` создает файл `config.tcm.yml`.
  Это файл содержит конфигурацию для загрузки в Tarantool Cluster Manager, сгенерированную на основе конфигурации кластера.

(admin_guide-deploy_one_node-start_example)=
## Запуск стенда

Перейдите в директорию примера `all_in_one`:

```shell
cd ./doc/examples/all_in_one/
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d --build 
```

Получите пароль для входа в веб-интерфейс Tarantool DB:
```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

(admin_guide-deploy_one_node-config)=

## Конфигурация контейнера для узла Tarantool DB

Конфигурация контейнера для узла Tarantool DB задается в файле `docker-compose.yml`:

```{literalinclude} docker-compose.yml
:start-at: tarantool-router-storage-1
:end-at: etcd3
:language: yaml
:dedent:
```

Здесь:
* `image` --  название Docker-образа, используемого для создания контейнера;
* `networks`-- название подсети;
* `ports` -- используемые порты;
* `volumes` -- логические тома, заданные для контейнера;
* `environment` -- переменные окружения для опций Tarantool:
  * `TT_INSTANCE_NAME` -- имя экземпляра в кластере;
  * `TT_CONFIG` -- ссылка на конфигурацию кластера.
* `depends on` -- последовательность загрузки контейнеров. Контейнер `tarantool-router-storage-1` запускается только после запуска узлов `etcd1`, `etcd2` и `etcd3`;

  Полный список опций доступен в документации к модулю [cartridge.argparse](https://www.tarantool.io/ru/doc/latest/book/cartridge/cartridge_api/modules/cartridge.argparse/) и в описании [Docker-образа](/install_and_upgrade/install.md) Tarantool DB.

(admin_guide-deploy_one_node-stop_example)=

## Остановка кластера

Остановить кластер можно так:

```shell
docker compose down
```
