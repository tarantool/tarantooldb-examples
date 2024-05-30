(admin_guide-deploy_docker_compose)=
# Запуск кластера через Docker compose

В этом руководстве показано, как развернуть Tarantool DB с помощью Docker compose.

```{admonition} Примечание
:class: note

Данный способ является вспомогательным и используется для тестирования и демонстрации в примерах документации.
Для целевого развертывания используйте [инсталлятор Ansible Tarantool Enterprise](admin_guide-deploy_ate).
```

Содержание:

* [](admin_guide-deploy_docker_compose-prereq)
* [](admin_guide-deploy_docker_compose-start_example)
* [](admin_guide-deploy_docker_compose-files)
* [](admin_guide-deploy_docker_compose-config)
* [](admin_guide-deploy_docker_compose-user_host)
* [](admin_guide-deploy_ci-stop_example)

(admin_guide-deploy_docker_compose-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install.md) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `up_with_docker_compose`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-0.8.0.tar.gz`.
    Пример `up_with_docker_compose` расположен в таком архиве в директории `./doc/examples/up_with_docker_compose/`.
    
  * Отдельный архив [up_with_docker_compose.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/up_with_docker_compose/up_with_docker_compose.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-deploy_docker_compose-start_example)=
## Запуск стенда

Перейдите в директорию примера `up_with_docker_compose`:

```shell
cd ./doc/examples/up_with_docker_compose/
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d --build 
```

(admin_guide-deploy_docker_compose-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `up_with_docker_compose`:

* `docker-compose.yml` -- описание узлов кластера;
* `bootstrap/topology.json` -- топология кластера;
* `./tools/client/bootstrap.sh` -- скрипт, [применяющий топологию кластера](user_guide-connectors-utils-bootstrap);
* `bootstrap/config.yml` -- конфигурация кластера;
* `bootstrap/migrations/source` -- директория, содержащая файлы с описанием миграций; 
* `./tools/client/migrate.sh` -- скрипт, [применяющий миграции](user_guide-connectors-utils-migrate).

(admin_guide-deploy_docker_compose-config)=
## Конфигурация контейнера для узла Tarantool DB

Конфигурация контейнера для узла Tarantool DB задается в файле `docker-compose.yml`:

```{literalinclude} docker-compose.yml
:start-at: tarantool-router-msk
:end-before: tarantool-router-spb
:language: yaml
:dedent:
```

Здесь:
* `image` --  название Docker-образа, используемого для создания контейнера;
* `networks`-- название подсети;
* `ports` -- используемые порты;
* `environment` -- переменные окружения для опций Tarantool и Cartridge:
  * `TARANTOOL_ADVERTISE_URI` -- адрес и порт, на котором узел доступен в кластере;
  * `TARANTOOL_ALIAS` -- название узла кластера.

  Полный список опций доступен в документации к модулю [cartridge.argparse](https://www.tarantool.io/ru/doc/latest/book/cartridge/cartridge_api/modules/cartridge.argparse/) и в описании [Docker-образа](/install_and_upgrade/install.md) Tarantool DB.

(admin_guide-deploy_docker_compose-user_host)=
## Контейнер user-host

В файле `docker-compose.yml` есть специальный контейнер ``user-host``.
Он выступает в роли компьютера разработчика, с которого выполняются:

1. Настройка топологии кластера и первоначальный запуск (bootstrap) модуля шардирования [vshard](https://www.tarantool.io/ru/doc/latest/book/admin/vshard_admin/).
2. Загрузка клиентского кода в кластер: описание спейсов и функций (миграции)

В примере конфигурация контейнера `user-host` выглядит так:

```{literalinclude} docker-compose.yml
:start-at: user-host
:end-at: bootstrap/:/bootstrap/
:language: yaml
:dedent:
```

Здесь:

* `image` --  название Docker-образа, используемого для создания контейнера;
  Используется как источник скриптов `bootstrap.sh`, `health_check.sh` и `migrate.sh`.
  Предполагается, что в реальных условиях скрипты будут загружены на компьютер разработчика из [личного кабинета tarantool.io](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb).
* `networks`-- название подсети;
* `environment` -- переменные окружения:
  * `TARANTOOLDB_TARGET_URI` -- адрес, по которому доступны API-команды кластера.
    Используется скриптами `bootstrap.sh`, `health_check.sh` и `migrate.sh`;
  * `BOOTSTRAP_FAILOVER` -- первоначальный запуск механизма восстановления после сбоев (failover);
  * `TARANTOOLDB_BOOTSTRAP_TIMEOUT` -- время ожидания первоначального запуска (bootstrap);
* `working_dir` -- директория, в которой лежат скрипты;
* `command` -- запуск скриптов `bootstrap.sh`, `health_check.sh` и `migrate.sh`;
* `depends_on` -- секция определяет, что контейнер `user-host` запускается только после запуска всех остальных узлов кластера;
* `volumes` -- передача в контейнер директории с настройками кластера и пользовательской логикой, чтобы они стали доступны для скриптов.

## Остановка стенда

Остановить кластер можно так:

```shell
docker compose down
```
