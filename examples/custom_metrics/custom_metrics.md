(admin_guide-custom_metrics)=
# Создание пользовательской метрики

В примере демонстрируется создание произвольной метрики, для этого используются модуль [metrics](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/metrics/) и
пользовательский код на языке Lua.

Узнать больше о пользовательских метриках можно в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/metrics/#metrics-api-reference-custom-metrics).

Для мониторинга используются:

* [Prometheus](https://prometheus.io/) -- сбор и хранение метрик;
* [Grafana](https://grafana.com/) -- визуализация метрик.

Содержание:

* [](admin_guide-custom_metrics-prereq)
* [](admin_guide-custom_metrics-start_example)
* [](admin_guide-custom_metrics-function)
* [](admin_guide-custom_metrics-watch_metrics)
* [](admin_guide-custom_metrics-stop_example)

(admin_guide-custom_metrics-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `custom_metrics`.
 
(admin_guide-custom_metrics-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3000
* 3301--3304
* 8081
* 8088
* 9090

Перейдите в директорию примера `custom_metrics`:

```shell
cd ./doc/examples/custom_metrics/
```

Стенд состоит из следующих компонентов:
- кластер Tarantool DB:
  - 1 роутер;
  - 1 набор реплик по 3 хранилища;
- кластер etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- средства мониторинга -- [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

Запустите всё следующей командой:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска становятся доступны следующие пользовательские интерфейсы:

* [http://localhost:8081](http://localhost:8081) -- веб-интерфейс TCM;
* [http://localhost:3000](http://localhost:3000) -- веб-интерфейс Grafana.

Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

(admin_guide-custom_metrics-function)=
## Вызов хранимой функции

На завершающем этапе запуска кластера выполняется публикация YAML-конфигурации кластера в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish)
и применяются [миграции](user_guide-migrations).
В примере выполняется миграция из файла `./tt/cluster/migrations/scenario/001_test.lua` примера `custom_metrics`.
В ходе этой миграции создается хранимая функция `counter_task`.
Каждый вызов этой функции будет увеличивать значение метрики на единицу.
Исходный код функции выглядит так:

```{literalinclude} tt/cluster/migrations/scenario/001_test.lua
:start-at: function()
:end-before: box.schema.func.create
:language: lua
:dedent:
```

Чтобы вызвать хранимую функцию `counter_task`:

1. В TCM откройте вкладку **Stateboard**.
2. Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
3. Во вкладке **Terminal** выполните следующую команду:

   ```lua
   box.func.counter_task:call()
   ```

(admin_guide-custom_metrics-watch_metrics)=
## Просмотр метрики в Grafana

Откройте в браузере веб-интерфейс Grafana по адресу [http://localhost:3000/dashboards](http://localhost:3000/dashboards).
В списке **Dashboards** выберите панель **Tarantool DB dashboard** в папке **General**.
Проверьте, что графики показывают данные за последние 15 минут, а частота обновления равна 5 секундам.

Разверните панель **Tarantool cluster overview** и откройте график **Custom count**.
Чтобы развернуть график на полный экран, нажмите на графике кнопку **...** (**Menu**) в правом верхнем углу и нажмите в выпадающем меню
кнопку **View**.

![](images/custom_count.png)

После каждого вызова хранимой функции `counter_task` значение `restores per second` на графике должно увеличиваться на 1.
В графике используется выражение `test_insert_count{alias="router-msk"}`, которое было задано в хранимой процедуре.

(admin_guide-custom_metrics-stop_example)=
## Остановка стенда

Для остановки стенда выполните следующую команду:

```shell
make stop
```
