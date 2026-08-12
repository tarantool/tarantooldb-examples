# Использование координаторов отказоустойчивости

В этом руководстве показано, как настроить работу
[внешних координаторов отказоустойчивости](https://www.tarantool.io/en/doc/latest/platform/replication/supervised_failover/#repl-supervised-failover)
(*supervised failover coordinators*).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Проверка работы](#проверка-работы)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `failover_coordinator`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `failover_coordinator` расположен в директории `examples/failover_coordinator`.
>  * Отдельный архив [failover_coordinator.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Ffailover_coordinator&filename=failover_coordinator), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию примера `failover_coordinator`:

```shell
cd examples/failover_coordinator
```

Запустите кластер Tarantool DB:

```shell
make start
```

Команда последовательно выполняет следующие шаги:
1. Запускает централизованное хранилище конфигурации — кластер etcd;
2. Загружает конфигурацию кластера в централизованное хранилище;
3. Запускает кластер Tarantool DB;
4. Загружает миграции в кластер и выполняет их.

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 2 координатора отказоустойчивости;
  - 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM);
- кластера etcd из 3 узлов;
- средств мониторинга ([Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/)).

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 — веб-интерфейс TCM;
* http://localhost:9090 — веб-интерфейс Prometheus;
* http://localhost:3000 — веб-интерфейс Grafana.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
После применения настроек кластер будет выглядеть так:

![Вкладка Stateboard в TCM](images/tcm-stateboard.png)

На вкладке **Stateboard** вызовите меню **Actions** кластера, нажав на кнопку `...` справа от строки поиска. В меню выберите
пункт **Supervised failover**. Откроется окно, в котором на вкладке
**Supervised failover** отображаются все работающие координаторы
кластера. Активный координатор отмечен в этом списке зелёной галочкой.

![Список координаторов отказоустойчивости в TCM](images/failover_list.png)

## Проверка работы

В TCM перейдите на вкладку **Stateboard**.
Нажмите на набор реплик `router-msk`.
Выберите роутер `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Во вкладке **Terminal** введите следующую команду, чтобы добавить в спейс новый кортеж:
```lua
crud.insert_object('bands', {id = 1, band_name = 'Free Flow Flava', year = 2014})
```

После этого проверьте записанный кортеж с помощью операции `crud.select()`:
```lua
crud.select('bands').rows
```

Теперь нужно остановить мастер-узлы. Чтобы определить мастер-узлы в наборе реплик, в TCM на вкладке **Stateboard** найдите в каждом наборе реплик экземпляр кластера с иконкой короны. В данном примере это узлы `storage-1-brn`
и `storage-2-brn`.

Чтобы остановить эти экземпляры кластера, вернитесь в терминал ОС и выполните следующие команды:
```shell
cd cluster/
docker compose stop tarantool-<имя_первого_мастера>
docker compose stop tarantool-<имя_второго_мастера>
cd ..
```

Видно, что мастер-узлы стали недоступны, а их лидерство передано другим экземплярам.

В TCM перейдите на вкладку **Stateboard**.
Нажмите на набор реплик `router-msk`.
Выберите роутер `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** введите следующую команду, чтобы добавить в спейс новый кортеж:

```lua
crud.insert_object('bands', {id = 2, band_name = 'Wax Tailor', year = 2001})
```

Кластер доступен для записи данных. Проверить кортеж, добавленный в спейс, можно так:
```lua
crud.select('bands').rows
```

## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
