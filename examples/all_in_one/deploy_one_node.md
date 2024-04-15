(admin_guide-deploy_one_node)=
# Запуск кластера из одного узла через Docker compose

В этом руководстве показано, как развернуть кластер Tarantool DB из одного узла с помощью Docker compose.

Содержание:

* [](admin_guide-deploy_one_node-prereq)
* [](admin_guide-deploy_docker_compose-start_example)
* [](admin_guide-deploy_one_node-files)
* [](admin_guide-deploy_one_node-stop_example)

(admin_guide-deploy_one_node-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `all_in_one`.
  Полный пример находится в директории `./doc/examples/all_in_one/`.
  Скачать архив с исходными файлами примера можно на [сайте Tarantool](https://tarantool.io/ru/tarantooldb/doc/latest/examples/all_in_one/all_in_one.tar.gz).

(admin_guide-deploy_one_node-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `./doc/examples/all_in_one/`:

* `docker-compose.yml` -- описание узлов кластера. Узнать больше: [](admin_guide-deploy_docker_compose).
* `bootstrap/topology.json` -- топология кластера;
* `./client/utils/bootstrap.sh` -- скрипт, применяющий топологию кластера;
* `bootstrap/config.yml` -- конфигурация кластера;
* `bootstrap/migrations/source` -- директория, содержащая файлы с описанием миграций; 
* `./client/utils/migrate.sh` -- скрипт, применяющий миграции.

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
