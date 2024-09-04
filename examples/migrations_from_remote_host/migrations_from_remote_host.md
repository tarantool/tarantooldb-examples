# Выполнение миграций с удалённой машины

В этом руководстве показано, как выполнить [миграции](../migrations/migrations_space_format.md) с сервера, который не входит в состав кластера.

Руководство включает следующие шаги:

* [](user_guide-migrations_remote_host-prereq)
* [](user_guide-migrations_remote_host-start_example)
* [](user_guide-migrations_remote_host-run_migration)
* [](user_guide-migrations_remote_host-stop_example)

(user_guide-migrations_remote_host-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `migrations_from_remote_hosts`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `migrations_from_remote_hosts` расположен в таком архиве в директории `./doc/examples/migrations_from_remote_hosts/`.

  * Отдельный архив [migrations_from_remote_hosts.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/migrations_from_remote_host/migrations_from_remote_host.tar.gz), скачанный c сайта Tarantool.
  ```

Запустить кластер из этого примера можно любым доступным способом -- через Ansible Tarantool Enterprise, docker compose или локально.
В руководстве для запуска используется [Docker compose](../up_with_docker_compose/deploy_docker_compose).

(user_guide-migrations_remote_host-start_example)=
## Запуск и настройка стенда

Для запуска и настройки стенда используются файлы из папки ``migrations_from_remote_hosts``:

* `docker-compose.yml` -- описание узлов кластера;
* `installer/topology.json` -- описание топологии кластера.

Перейдите в директорию примера `migrations_from_remote_host`:

```
cd ./doc/examples/migrations_from_remote_host/
```

Запустите стенд через Docker compose:

```shell
docker compose up -d  --build
```

Чтобы проверить успешный запуск кластера, выполните следующую команду:

```shell
docker compose logs installer
```

При успешном старте последняя строка в выводе будет следующей:

```
Cluster started
```

Запущенный стенд состоит из:
* кластера Tarantool DB из двух роутеров и двух шардов;
* веб-сервера nginx, предоставляющего доступ к удаленному серверу по HTTP с авторизацией и балансировкой нагрузки.

Удаленный доступ к админ-функциям кластера доступен по адресу [localhost:8000](http://localhost:8000).
Проверить и настроить узлы кластера изнутри можно в веб-интерфейсе Tarantool DB, например по адресу [localhost:8081](http://localhost:8081).

(user_guide-migrations_remote_host-run_migration)=
## Запуск миграции

Для запуска миграции используются следующие файлы:

- `config.yml` (`./user-host/config.yml`) -- файл конфигурации кластера;
- `migrations/source/` (`./user-host/migrations/source/`) -- директория, содержащая файлы миграций;
- скрипт `migrate.sh` (`./tools/client/migrate.sh`) -- загрузка конфигурации кластера, клиентского кода и выполнения миграций.

Перед запуском миграции скопируйте скрипт [migrate.sh](user_guide-connectors-utils-migrate), выполняющий миграции, из директории `tools/client`:

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

```
Load config..
Config loaded
Start migrate..
Migrations completed successfully
```

Проверить успешное выполнение миграций можно в веб-интерфейсе Tarantool DB, там можно увидеть загруженную конфигурацию кластера
и созданные спейсы `test1` и `test2` (вкладка **Space Explorer**).

(user_guide-migrations_remote_host-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
