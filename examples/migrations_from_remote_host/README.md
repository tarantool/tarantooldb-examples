# Выполнение миграций с удалённой машины

В этом руководстве показано, как выполнить [миграции](../migrations/README.md) с сервера, который не входит в состав кластера.

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск и настройка стенда](#запуск-и-настройка-стенда)
* [Запуск миграции](#запуск-миграции)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `migrations_from_remote_host`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `migrations_from_remote_host` расположен в директории `examples/migrations_from_remote_host`.
>  * Отдельный архив [migrations_from_remote_host.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fmigrations_from_remote_host&filename=migrations_from_remote_host), скачанный из этого репозитория.

Запустить кластер из этого примера можно любым доступным способом — через Ansible Tarantool Enterprise, Docker Compose или локально.
В руководстве для запуска используется [Docker Compose](../up_with_docker_compose/README.md).

## Запуск и настройка стенда

Для запуска и настройки стенда используются файлы из папки ``migrations_from_remote_host``:

* `docker-compose.yml` — описание узлов кластера;
* `installer/topology.json` — описание топологии кластера.

Перейдите в директорию примера `migrations_from_remote_host`:

```shell
cd examples/migrations_from_remote_host
```

Запустите стенд через Docker Compose:

```shell
docker compose up -d  --build
```

Чтобы проверить успешный запуск кластера, выполните следующую команду:

```shell
docker compose logs installer
```

При успешном старте последняя строка в выводе будет следующей:

```shell
installer-1  | [bootstrap.sh] Cluster started
```

Запущенный стенд состоит из:
* кластера Tarantool DB из двух роутеров и двух шардов;
* веб-сервера nginx, предоставляющего доступ к удаленному серверу по HTTP с авторизацией и балансировкой нагрузки.

Удаленный доступ к админ-функциям кластера доступен по адресу [localhost:8000](http://localhost:8000).
Проверить и настроить узлы кластера изнутри можно в веб-интерфейсе Tarantool DB, например по адресу [localhost:8081](http://localhost:8081).

## Запуск миграции

Для запуска миграции используются следующие файлы:

- `config.yml` (`./user-host/config.yml`) — файл конфигурации кластера;
- `migrations/source/` (`./user-host/migrations/source/`) — директория, содержащая файлы миграций;
- скрипт `migrate.sh` (`./tools/client/migrate.sh`) — загрузка конфигурации кластера, клиентского кода и выполнения миграций.

Перед запуском миграции скопируйте скрипт [migrate.sh](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/utils#user_guide-connectors-utils-migrate), выполняющий миграции, из директории `tools/client`:

```shell
cp ../../../tools/client/migrate.sh ./
chmod a+x migrate.sh
```

Запустите миграцию:

```shell
TARANTOOLDB_TARGET_URI=localhost:8000 TARANTOOLDB_BOOTSTRAP_PATH=./user-host/ TARANTOOLDB_HEADERS="Authorization: Bearer 123" ./migrate.sh
```

Здесь для удаленного доступа используется авторизация по токену.
В запросе авторизации должен присутствовать заголовок `Authorization: Bearer 123`.
Логика проверки этого заголовка настроена в конфигурации nginx.

После успешного завершения миграции в консоли появится следующее сообщение:

```shell
Load config..
Config loaded
Start migrate..
Migrations completed successfully
```

Проверить успешное выполнение миграций можно в веб-интерфейсе Tarantool DB, там можно увидеть загруженную конфигурацию кластера
и созданные спейсы `test1` и `test2` (вкладка **Space Explorer**).

## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
