# Создание пользовательской метрики

В примере демонстрируется создание произвольной метрики, для этого используются модуль [metrics](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/metrics/) и
пользовательский код на языке Lua.

Узнать больше о пользовательских метриках можно в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/metrics/#metrics-api-reference-custom-metrics).

Для мониторинга используются:

* [Prometheus](https://prometheus.io/) — сбор и хранение метрик;
* [Grafana](https://grafana.com/) — визуализация метрик.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Вызов хранимой функции](#вызов-хранимой-функции)
* [Просмотр метрики в Grafana](#просмотр-метрики-в-grafana)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `custom_metrics`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `custom_metrics` расположен в директории `examples/custom_metrics`.
>  * Отдельный архив [custom_metrics.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Fcustom_metrics&filename=custom_metrics), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301..3308
* 8081
* 8088
* 3000

Перейдите в директорию `custom_metrics/tt`:

```shell
cd examples/custom_metrics/tt
```

Стенд состоит из следующих компонентов:
- кластер Tarantool DB:
  - 1 роутер;
  - 1 набор реплик по 3 хранилища;
- кластер etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM);
- средства мониторинга — [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

Запустите всё следующей командой:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска становятся доступны следующие пользовательские интерфейсы:

* [http://localhost:8081](http://localhost:8081) — веб-интерфейс TCM;
* [http://localhost:3000](http://localhost:3000) — веб-интерфейс Grafana.

Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

## Вызов хранимой функции

На завершающем этапе запуска кластера выполняется публикация YAML-конфигурации кластера в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish)
и применяются [миграции](https://www.tarantool.io/docs/tdb/ru/2_x/user_guide/migrations).
В примере выполняется миграция из файла `./tt/cluster/migrations/scenario/001_test.lua` примера `custom_metrics`.
В ходе этой миграции создается хранимая функция `counter_task`.
Каждый вызов этой функции будет увеличивать значение метрики на единицу.
Исходный код функции выглядит так:

```lua
function()
    -- Проверить, была ли переменная уже инициализирована
    if _G.test_insert_count == nil then
        -- Инициализировать переменную нужно только один раз
        _G.test_insert_count = require('metrics').counter('test_insert_count', 'The number of data operations')
    end

    -- Функция для генерации метрики
    local function update_metric(counter)
        -- Здесь происходит обновление значения метрики. Каждая пара время-значение сопровождается
        -- меткой. В качестве метки выступает структура с произвольными пользовательскими
        -- данными, необходимыми для построения нужных графиков. К такой структуре применяется следующее условие:
        -- количество вариантов значений внутри нее должно быть ограничено, чтобы не
        -- перегрузить БД, собирающую метрики (как правило, это одна из Time Series баз данных).

        local label_pairs = {
            request_type = 'default',
        }
        counter:inc(1, label_pairs) -- Увеличить значение счётчика на единицу и одновременно подписать
                                    -- новую пару время-значение
    end

    -- Вызвать функцию генерации метрики
    update_metric(_G.test_insert_count)
end
```

Чтобы вызвать хранимую функцию `counter_task`:

1. В TCM откройте вкладку **Stateboard**.
2. Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
3. Во вкладке **Terminal** выполните следующую команду:

   ```lua
   box.func.counter_task:call()
   ```

## Просмотр метрики в Grafana

Откройте в браузере веб-интерфейс Grafana по адресу [http://localhost:3000/dashboards](http://localhost:3000/dashboards).
В списке **Dashboards** выберите панель **Tarantool 3 dashboard** в папке **General**.
Проверьте, что графики показывают данные за последние 15 минут, а частота обновления равна 5 секундам.

Разверните панель **Cluster Overview** и откройте график **Custom count**.
Чтобы развернуть график на полный экран, нажмите на графике кнопку **...** (**Menu**) в правом верхнем углу и нажмите в выпадающем меню
кнопку **View**.

![График Custom count в Grafana](images/custom_count.png)

После каждого вызова хранимой функции `counter_task` значение `restores per second` на графике должно увеличиваться на 1.
В графике используется выражение `test_insert_count{alias="router-msk"}`, которое было задано в хранимой процедуре.

## Остановка стенда

Для остановки стенда выполните следующую команду:

```shell
make stop
```
