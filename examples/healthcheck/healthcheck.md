(admin_guide-healthcheck)=
# Проверка работоспособности кластера

Доступно с версии 3.1.0.

В этом руководстве показано, как проверить работоспособность (здоровье) кластера с помощью технологической роли `roles.healthcheck`.
Роль позволяет:
- получать текущее состояние здоровья экземпляра;
- устанавливать оповещения (*alerts*) в кластере при проблемах с работоспособностью узла;
- отключать некоторые дополнительные проверки;
- задавать свой формат ответа;
- настраивать свою логику дополнительной проверки здоровья экземпляра.

Подробную информацию по настройке и использованию модуля `healthcheck` можно найти в документации модуля на [GitHub](https://github.com/tarantool/healthcheck-role).

Содержание:

* [](admin_guide-healthcheck-prereq)
* [](admin_guide-healthcheck-start_example)
* [](admin_guide-healthcheck-1st_check)
* [](admin_guide-healthcheck-imitation_replica_fail)
* [](admin_guide-healthcheck-imitation_replication_fail)
* [](admin_guide-healthcheck-stop_example)

(admin_guide-healthcheck-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* приложение curl;
* исходные файлы примера `healthcheck`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.1.0.tar.gz`.
    Пример `healthcheck` расположен в таком архиве в директории `./doc/examples/healthcheck/`.
    
  * Отдельный архив [healthcheck.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/healthcheck/healthcheck.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-healthcheck-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301--3308
* 8081
* 8281--8288

Перейдите в директорию примера `healthcheck`:

```shell
cd ./doc/examples/healthcheck/
```

Запустите кластер Tarantool DB:

```shell
make start
```

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-healthcheck-init_host).
Также после запуска становится доступен веб-интерфейс TCM.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
После применения настроек кластер будет выглядеть так:

![](/images/tcm-stateboard.png)

(admin_guide-healthcheck-1st_check)=
## Проверка здоровья узлов кластера

Чтобы запросить метрику здоровья экземпляра, выполните HTTP GET-запрос на соответствующий порт с помощью утилиты curl. В примере ниже приведен запрос для узла `storage-1-msk` с портом `8283` и адресом метрики `/healthcheck`:

```shell
curl localhost:8283/healthcheck
```

Ответ выглядит так:

```shell
{"status":"alive"}
```

(admin_guide-healthcheck-imitation_replica_fail)=
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

(admin_guide-healthcheck-imitation_replication_fail)=
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

(admin_guide-healthcheck-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
