# Проверка работоспособности кластера

Доступно с версии 3.1.0.

В этом руководстве показано, как проверить работоспособность (здоровье) кластера с помощью технологической роли `roles.healthcheck`.
Роль позволяет:
- получать текущее состояние здоровья экземпляра;
- устанавливать оповещения (*alerts*) в кластере при проблемах с работоспособностью узла;
- отключать дополнительные проверки;
- задавать свой формат ответа;
- настраивать свою логику дополнительной проверки здоровья экземпляра.

Подробную информацию по настройке и использованию модуля `healthcheck` можно найти в документации модуля на [GitHub](https://github.com/tarantool/healthcheck-role).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Проверка здоровья узлов кластера](#проверка-здоровья-узлов-кластера)
* [Имитация отказа реплики в наборе реплик](#имитация-отказа-реплики-в-наборе-реплик)
* [Имитация отказа репликации на реплике](#имитация-отказа-репликации-на-реплике)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* приложение curl;
* исходные файлы примера `healthcheck`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `healthcheck` расположен в директории `examples/healthcheck`.
>  * Отдельный архив [healthcheck.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fhealthcheck&filename=healthcheck), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081
* 8281–8288

Перейдите в директорию примера `healthcheck`:

```shell
cd examples/healthcheck
```

Запустите кластер Tarantool DB:

```shell
make start
```

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).
Также после запуска становится доступен веб-интерфейс TCM.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
После применения настроек кластер будет выглядеть так:

![Вкладка Stateboard в TCM](images/tcm-stateboard.png)

## Проверка здоровья узлов кластера

Чтобы запросить метрику здоровья экземпляра, выполните HTTP GET-запрос на соответствующий порт с помощью утилиты curl. В примере ниже приведен запрос для узла `storage-1-msk` с портом `8283` и адресом метрики `/healthcheck`:

```shell
curl localhost:8283/healthcheck
```

Ответ выглядит так:

```shell
{"status":"alive"}
```

## Имитация отказа реплики в наборе реплик

Чтобы сымитировать отказ экземпляра, остановите его с помощью команды `docker compose pause`:

```shell
cd cluster
docker compose pause tarantool-storage-1-spb
```

Проверьте работоспособность мастер-узла:

```shell
curl localhost:8283/healthcheck
```

Ответ выглядит так:

```shell
{"status":"alive"}
```

Проверка работоспособности показывает, что мастер-узел исправен. Это сделано намеренно для уменьшения чувствительности проверки, поскольку в данном случае доступны запись и чтение с мастер-узла.

Теперь проверьте здоровье второй реплики в этом наборе реплик:

```shell
curl localhost:8285/healthcheck
```

Ответ:

```shell
{"status":"dead","details":["replication.state_bad.storage-1-spb: Replication from \"storage-1-spb\" to \"storage-1-brn\" state \"connect\" (timed out)"]}
```

Видно, что реплика имеет статус `dead`. Кроме того, в ее описании указана информация о недоступности другой реплики. Если в наборе реплик отключить мастер-узел вместо реплики, то обе реплики перейдут в статус `dead`.

Верните экземпляр в работу:

```shell
docker compose unpause tarantool-storage-1-spb
```

## Имитация отказа репликации на реплике

Чтобы сымитировать отказ репликации на одной из реплик:

1. Откройте TCM и перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `storage-1`.
3. Выберите узел `storage-1-brn` и в открывшемся окне перейдите на вкладку **Terminal**.
4. Во вкладке **Terminal** выполните следующую команду:

```lua
box.cfg({replication = {}})
```

Проверьте здоровье узла `storage-1-brn`:

```shell
curl localhost:8285/healthcheck
```

Ответ:

```shell
{"status":"dead","details":["replication.upstream_absent.storage-1-msk: Replication from \"storage-1-msk\" to \"storage-1-brn\" is not running","replication.upstream_absent.storage-1-spb: Replication from \"storage-1-spb\" to \"storage-1-brn\" is not running"]}
```

Видно, что реплика имеет статус `dead`. Кроме того, в ее описании указана информация о недоступности других узлов из набора реплик.

## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
