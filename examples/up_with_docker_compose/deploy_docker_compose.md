(admin_guide-deploy_docker_compose)=
# Запуск кластера через Docker Compose

В этом руководстве показано, как развернуть кластер Tarantool DB с помощью Docker Compose.

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
* [](admin_guide-deploy_docker_compose-init_host)
* [](admin_guide-deploy_ci-stop_example)

(admin_guide-deploy_docker_compose-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `up_with_docker_compose`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `up_with_docker_compose` расположен в таком архиве в директории `./doc/examples/up_with_docker_compose/`.
    
  * Отдельный архив [up_with_docker_compose.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/up_with_docker_compose/up_with_docker_compose.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-deploy_docker_compose-start_example)=
## Запуск стенда

Перейдите в директорию примера `up_with_docker_compose`:

```shell
cd ./doc/examples/up_with_docker_compose/
```

Запустите кластер Tarantool DB:

```shell
docker compose up -d
```

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
  - 2 координатора автоматического восстановления после сбоев (*failover coordinator*);
- кластера etcd из 3 узлов;
- средств мониторинга ([Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/)).

После запуска должны работать все контейнеры, кроме `init_host`.
Также после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 -- веб-интерфейс TCM;
* http://localhost:3000 -- веб-интерфейс Grafana.

Получите пароль для входа в TCM:

```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте в браузере TCM по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

(admin_guide-deploy_docker_compose-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `up_with_docker_compose`:

* `config.yml` -- конфигурация и топология кластера;
* `docker-compose.yml` -- описание узлов кластера;
* `migrations/scenario` -- директория, содержащая файлы с описанием миграций;
* `grafana` -- директория, содержащая настройки для ведения мониторинга;
* `prometheus` -- директория, содержащая настройки Prometheus для сбора и передачи метрик в Grafana;
* `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

Кроме того, при запуске примера скрипт `make_config_tcm_yml.lua` создает файл `config.tcm.yml`.
Это файл содержит конфигурацию для загрузки в TCM, сгенерированную на основе конфигурации кластера.

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
* `volumes` -- директории с настройками кластера и пользовательской логикой, переданные в контейнер;
* `environment` -- переменные окружения для опций Tarantool:
  * `TT_INSTANCE_NAME` -- имя экземпляра в кластере;
  * `TT_CONFIG` -- ссылка на конфигурацию кластера.

  Полный список опций доступен в описании [Docker-образа](install_docker-image-description) Tarantool DB.

* `depends on` -- последовательность запуска контейнеров. Контейнер `tarantool-router-msk` запускается только после запуска узлов `etcd1`, `etcd2` и `etcd3`;

(admin_guide-deploy_docker_compose-init_host)=
## Контейнер init_host

В файле `docker-compose.yml` есть специальный контейнер `init_host`.
С этого контейнера выполняются:

1. Публикация YAML-конфигурации кластера в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/reference/tooling/tt_cli/cluster/#tt-cluster-publish).
2. Загрузка клиентского кода (миграций) в кластер и его применение: описание спейсов и функций.

В примере конфигурация контейнера `init_host` выглядит так:

```{literalinclude} docker-compose.yml
:start-at: init_host
:end-before: tcm-1
:language: yaml
:dedent:
```

Здесь:

* `image` -- название Docker-образа, используемого для создания контейнера;
* `networks`-- название подсети;
* `volumes` -- директории с настройками кластера и пользовательской логикой, переданные в контейнер;
* `depends_on` -- секция определяет, что контейнер `user-host` запускается только после запуска всех остальных узлов кластера;
* `working_dir` -- рабочая директория;
* `command` -- команды выполняют загрузку миграций и конфигурации кластера.

## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
