# Балансировка запросов к роутерам через Go-коннектор

В примере демонстрируется работа с повреждённым кластером под нагрузкой.
Приложение непрерывно записывает кортежи пачками через все роутеры по очереди.
Для записи используется операция `replace`.
Если какой-либо роутер стал недоступен, трафик с него переключается на другие роутеры.
Если роутер снова стал доступен, трафик на него возвращается.

Для мониторинга используются:

* [Prometheus](https://prometheus.io/) — сбор и хранение метрик;
* [Grafana](https://grafana.com/) — визуализация метрик.

> [!NOTE]
> Пример стенда с [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) и [InfluxDB](https://www.influxdata.com/)
> приведен в разделе [Балансировщик запросов к роутерам через Java-коннектор](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/connectors/java/connectors_java_balancer).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Панель Grafana](#панель-grafana)
* [Увеличение нагрузки](#увеличение-нагрузки)
* [Имитация отказа роутера](#имитация-отказа-роутера)
* [Восстановление роутера](#восстановление-роутера)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* Go;
* исходные файлы примера `go_balancer`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `go_balancer` расположен в директории `examples/go_balancer`.
>  * Отдельный архив [go_balancer.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fgo_balancer&filename=go_balancer), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3000
* 3301–3308
* 8081
* 9090

Перейдите в директорию примера `go_balancer`:

```shell
cd examples/go_balancer
```

Стенд состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
- клиентского приложения, подающего нагрузку;
- средств мониторинга — [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

Запустите всё, кроме клиентского приложения, следующей командой:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска доступны следующие пользовательские интерфейсы:
* [http://localhost:8081](http://localhost:8081) — веб-интерфейс TCM;
* [http://localhost:3000](http://localhost:3000) — веб-интерфейс Grafana.

Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
После применения настроек кластер будет выглядеть так:

![Вкладка Stateboard в TCM](images/tcm-stateboard.png)

Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```lua
box.space
```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

## Панель Grafana

Откройте в браузере веб-интерфейс Grafana по адресу [http://localhost:3000/dashboards](http://localhost:3000/dashboards).
В списке **Dashboards** откройте папку **General** и выберите панель **Tarantool DB dashboard** в выпадающем списке.
Проверьте, что графики показывают данные за последние 5 минут, а частота обновления равна 5 секундам:

![Панель дашборда Tarantool DB в Grafana](images/grafana-panel.png)

Разверните панель **Tarantool network activity** и откройте график **Processed requests**.
Чтобы развернуть график на полный экран, нажмите на графике кнопку **...** (**Menu**) в правом верхнем углу и нажмите в выпадающем меню
кнопку **View**.
Выберите роутеры на графике, используя один из способов ниже:

* Нажмите на название `router-msk` и, зажав `Shift`, нажмите на `router-spb`.
* Используйте переключатель сверху (**Instances**), чтобы выбрать роутеры на уровне всего дашборда.

![График обработанных запросов — оба роутера](images/processed-requests-1.png)

После перейдите на панель **Tarantool operations statistics** и откройте график **REPLACE space requests**.
Выберите все узлы, кроме роутеров:

![График запросов REPLACE к спейсу — все узлы, кроме роутеров](images/replace-1.png)

Затем перейдите на панель **CRUD module statistics** и откройте график **REPLACE success requests**:

![График успешных запросов CRUD REPLACE](images/crud-replace-1.png)

## Увеличение нагрузки

Откройте вторую вкладку локального терминала.
В этой вкладке перейдите в директорию `go_balancer/go`:

```shell
cd examples/go_balancer/go
```

Запустите клиентское приложение:

```shell
go run -tags go_tarantool_ssl_disable main.go
```

Здесь:

* `go_tarantool_ssl_disable` — опция, отключающая поддержку TLS.
  Так как для поддержки TLS требуется установленный OpenSSL 3.x, для простоты в примере поддержка TLS отключена.

На графиках теперь заметна растущая нагрузка:

* растет число обработанных запросов на роутерах:

  ![График обработанных запросов под нагрузкой](images/processed-requests-2.png)

* растет число операций `replace` в единицу времени:

  ![График запросов REPLACE к спейсу под нагрузкой](images/replace-2.png)

Включите отображение графиков роутеров и оцените их:

![График запросов CRUD REPLACE под нагрузкой — роутеры](images/crud-replace-2.png)

Проверьте, что в спейсе `test` появились данные.
Для этого в веб-интерфейсе TCM перейдите на вкладку **Tuples** и выберите в списке спейс `test`.
Откроется новая вкладка с содержимым кортежей спейса `test`.

## Имитация отказа роутера

В первом терминале перейдите в директорию `cluster`:

```shell
cd cluster
```

Чтобы имитировать отказ роутера, выполните следующую команду:

```shell
docker compose stop tarantool-router-msk
```

Теперь в TCM во вкладке **Stateboard** узел `router-msk` помечается как нездоровый (`unhealthy`).
График запросов изменится так:

![График обработанных запросов после отказа роутера](images/processed-requests-3.png)

Нагрузка на второй роутер увеличилась вдвое.
График для второго роутера выглядит так:

![График обработанных запросов — отказавший роутер](images/processed-requests-4.png)

Роста нагрузки на этом графике нет.
График прерывается, так как роутер не работает и метрики с него не поступают.
Количество операций `replace` при этом не изменилось:

![График запросов REPLACE к спейсу после отказа роутера](images/replace-3.png)

Количество операций `crud-replace` на рабочем роутере возросло:

![График запросов CRUD REPLACE — рабочий роутер после отказа](images/crud-replace-3.png)

## Восстановление роутера

Для запуска первого роутера выполните следующую команду в директории `cluster`:

```shell
docker compose start tarantool-router-msk
```

В TCM во вкладке **Stateboard** видно, что узел `router-msk` восстановлен.
Нагрузка на второй роутер уменьшилась вдвое, появились данные по нагрузке с первого:

![График обработанных запросов после восстановления роутера](images/processed-requests-5.png)

Число операций `replace` не изменилось:

![График запросов REPLACE к спейсу после восстановления](images/replace-4.png)

Количество операций `crud-replace` на один роутер снизилось:

![График запросов CRUD REPLACE после восстановления](images/crud-replace-4.png)

## Остановка стенда

Для остановки стенда:

* В первом локальном терминале вернитесь в директорию `go_balancer/`:

  ```shell
  cd examples/go_balancer
  ```

  Выполните следующую команду:

  ```shell
  make stop
  ```

* Во втором локальном терминале выполните команду `Ctrl + Z`.
