(admin_guide-deploy_one_node)=
# Запуск кластера из одного узла через Docker compose

В этом руководстве показано, как развернуть кластер Tarantool DB из одного узла с помощью Docker compose.

Содержание:

* [](admin_guide-deploy_one_node-prereq)
* [](admin_guide-deploy_one_node-files)
* [](admin_guide-deploy_one_node-start_example)
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
* `bootstrap/topology.json` -- топология кластера;
* `./client/utils/bootstrap.sh` -- скрипт, [применяющий топологию кластера](user_guide-connectors-utils-bootstrap);
* `bootstrap/config.yml` -- конфигурация кластера;
* `bootstrap/migrations/source` -- директория, содержащая файлы с описанием миграций; 
* `./client/utils/migrate.sh` -- скрипт, [применяющий миграции](user_guide-connectors-utils-migrate).

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

(admin_guide-deploy_one_node-stop_example)=
## Остановка кластера

Остановить кластер можно так:

```shell
docker compose down
```
