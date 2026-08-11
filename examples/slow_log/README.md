# Логирование медленных запросов для функций и CRUD-запросов

В этом руководстве описано, как настроить запись медленных запросов в журнал для функций и CRUD-запросов.

Подробнее о модуле `slow_log` можно узнать в разделе [Логирование медленных запросов](https://www.tarantool.io/docs/tdb/ru/1_x/admin_guide/troubleshooting/slow_log).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Запись CRUD-запросов в журнал](#запись-crud-запросов-в-журнал)
* [Логирование пользовательской функции](#логирование-пользовательской-функции)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* исходные файлы примера `slow_log`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `slow_log` расположен в директории `examples/slow_log`.
>  * Отдельный архив [slow_log.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fslow_log&filename=slow_log), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию примера `slow_log`:

```shell
cd examples/slow_log
```

Запустите стенд Tarantool DB:

```shell
docker compose up -d
```

Команда поднимает кластер с двумя хранилищами и одним роутером.
Роль `slow_log` задана на роутере.

Подробная информация о том, как включить логирование медленных запросов и задать соответствующую конфигурацию, приведена в разделе [Настройка журнала медленных запросов](https://www.tarantool.io/docs/tdb/ru/1_x/admin_guide/troubleshooting/slow_log/configuration).

Чтобы гарантированно получить сообщение в логе, задайте для опции `slow_log.threshold` значение `0` в конфигурационном файле:

```yaml
threshold: 0
```

## Запись CRUD-запросов в журнал

Подключитесь к роутеру с помощью команды `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных.

В примере данные хранятся в спейсе `data` со следующим форматом:

```lua
box.schema.space.create('data', {if_not_exists = true})
box.space.data:format({
    { name = 'id', type = 'number' },
    { name = 'bucket_id', type = 'unsigned' },
    { name = 'data', type = 'any' },
})
```

Добавьте кортеж в спейс `data`, используя функцию из модуля CRUD:

```lua
crud.replace("data", {1, box.NULL, {}})
```

После просмотрите логи приложения:

```shell
docker compose logs | grep 'Function call crud'
```

Запись в логе может выглядеть так:

```shell
slow_log-tarantool-router-1    | 2023-11-30 14:02:35.599 [12] main/176/main/tarantooldb.app.roles.slow_log I> Function call crud.replace(["data",[1,null,[]]]) was too long: 0.011s
```

## Логирование пользовательской функции

В примере создана персистентная функция `app.wait_for`, которая ждет заданное количество секунд:

```lua
box.schema.func.create('app.wait_for',  {
    language = 'LUA',
    if_not_exists = true,
    body = [[
        function(sleep_time)
            local log = require('log')
            local fiber = require('fiber')
            log.info("start wait_for " .. sleep_time)
            fiber.sleep(sleep_time)
            log.info("stop wait_for " .. sleep_time)
        end
    ]],
})
```

Чтобы включить запись в журнал для функции `app.wait_for`, обновите секцию `slow_log` в файле конфигурации:

```yaml
enable: true
threshold: 3
namespaces:
- app
```

Далее подключитесь к роутеру с помощью утилиты `tt`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Вызовите функцию `app.wait_for`, задав для нее значение в 3 секунды:

```lua
box.schema.func.call('app.wait_for', 3)
```

После просмотрите логи приложения:

```shell
docker compose logs | grep wait_for
```

Запись в логе может выглядеть так:

```shell
slow_log-tarantool-router-1    | 2023-11-30 14:13:52.738 [12] main/225/main/tarantool I> start wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantool I> stop wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantooldb.app.roles.slow_log I> Function call app.wait_for([3]) was too long: 3.002s
```

При использовании модуля персистентные функции заменяются на версии с логированием времени выполнения.
Оригинальные функции сохраняются с префиксом `__slow_log_orig_`.
Для функции `app.wait_for` будет создана функция `__slow_log_orig_app.wait_for`.
После отключения модуля функция `__slow_log_orig_app.wait_for` будет удалена.

## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
