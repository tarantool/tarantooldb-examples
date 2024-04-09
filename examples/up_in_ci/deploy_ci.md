# Запуск кластера в CI

При работе в CI возникает необходимость запускать Docker в Docker или другой виртуальной среде.
В примере описано, как при таком подходе решить возможную проблему с передачей локальной папки в Docker-образ.

Содержание:

* [](admin_guide-deploy_ci-prereq)
* [](admin_guide-deploy_ci-start_example)
* [](admin_guide-deploy_ci-user_host)
* [](admin_guide-deploy_ci-stop_example)

(admin_guide-deploy_ci-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install.md) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `up_in_ci`.
  Пример находится в директории `./doc/examples/up_in_ci/`.
  Скачать архив с исходными файлами примера можно на [сайте Tarantool](https://tarantool.io/ru/tarantooldb/doc/latest/examples/up_in_ci/up_in_ci.tar.gz).

(admin_guide-deploy_ci-start_example)=
## Запуск стенда

Перейдите в директорию `up_in_ci`:

```shell
cd ./doc/examples/up_in_ci/
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d --build 
```

(admin_guide-deploy_ci-user_host)=
## Контейнер user-host

Контейнер `user-host` указывается в файле `docker-compose.yml`.
Подробное описание контейнера приводится в разделе [](admin_guide-deploy_docker_compose-user_host).

В примере конфигурация контейнера `user-host` выглядит так:

```{literalinclude} docker-compose.yml
:start-at: user-host
:end-at: tarantool-storage4
:language: yaml
:dedent:
```

Здесь:

* `build.context.dockerfile` -- сборка отдельного контейнера, в который копируется папка `bootstrap` и пользовательские скрипты;
* `networks`-- название подсети;
* `environment` -- задание переменных окружения:
  * `TARANTOOLDB_TARGET_URI` -- адрес, по которому доступны API-команды кластера.
    Используется скриптами `bootstrap.sh`, `health_check.sh` и `migrate.sh`;
* `working_dir` -- директория, в которой лежат файл конфигурации и файлы миграций;
* `command` -- запуск скриптов `bootstrap.sh`, `health_check.sh` и `migrate.sh`;
* `depends_on` -- секция определяет, что контейнер `user-host` запускается только после запуска всех остальных узлов кластера;
* `volumes` -- передача в контейнер директории с настройками кластера и пользовательской логикой, чтобы они стали доступны для скриптов.


(admin_guide-deploy_ci-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
