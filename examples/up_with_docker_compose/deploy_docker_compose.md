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
* [](admin_guide-deploy_docker_compose-stop_example)

(admin_guide-deploy_docker_compose-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
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
make start
```

Команда последовательно выполняет следующие шаги:
1. Запускает централизованное хранилище конфигурации -- кластер etcd;
2. Загружает конфигурацию кластера в централизованное хранилище;
3. Запускает кластер Tarantool DB;
4. Загружает миграции в кластер и выполняет их.

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов;
- средств мониторинга ([Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/)).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).
Также после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 -- веб-интерфейс TCM;
* http://localhost:9090 -- веб-интерфейс Prometheus;
* http://localhost:3000 -- веб-интерфейс Grafana.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
После применения настроек кластер будет выглядеть так:

![](/images/tcm-stateboard.png)

(admin_guide-deploy_docker_compose-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `up_with_docker_compose`:

* `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  * `migrations/scenario` -- директория, содержащая файлы с описанием миграций;
* `tools/` -- директория с файлами для запуска кластера etcd и средств мониторинга:
  * `grafana/` -- директория, содержащая настройки для ведения мониторинга;
  * `prometheus/` -- директория, содержащая настройки Prometheus для сбора и передачи метрик в Grafana;
  * `docker-compose.yml` -- описание узлов кластера etcd и средств мониторинга;
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/);
* `Makefile` -- инструкции для утилиты `make` для запуска и остановки всего стенда.

(admin_guide-deploy_docker_compose-config)=
## Конфигурация контейнера для узла Tarantool DB

Конфигурация контейнера для узла Tarantool DB задается в файле `docker-compose.yml`:

```{literalinclude} cluster/docker-compose.yml
:start-at: tarantool-router-msk
:end-before: tarantool-router-spb
:language: yaml
:dedent:
```

Здесь:
* `image` --  название Docker-образа, используемого для создания контейнера;
* `networks`-- название подсети;
* `ports` -- используемые порты;
* `environment` -- переменные окружения для опций Tarantool:
  * `TT_INSTANCE_NAME` -- имя экземпляра в кластере;
  * `TT_CONFIG_ETCD_ENDPOINTS` -- адреса централизованного хранилища конфигурации;
  * `TT_CONFIG_ETCD_PREFIX` -- адрес данных кластера Tarantool DB в централизованном хранилище конфигурации;
  * `TT_CONFIG_ETCD_HTTP_REQUEST_TIMEOUT` -- таймаут запроса для получения конфигурации.

  Полный список опций доступен в описании [Docker-образа](install_docker-image-description) Tarantool DB.

(admin_guide-deploy_docker_compose-init_host)=
## Контейнер init_host

В файле `cluster/docker-compose.yml` есть специальный контейнер `init_host`.
С этого контейнера выполняются:

1. Загрузка клиентского кода (миграций) в кластер и его применение: описание спейсов и функций.
2. Добавление кластера в веб-интерфейс.

(admin_guide-deploy_docker_compose-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
