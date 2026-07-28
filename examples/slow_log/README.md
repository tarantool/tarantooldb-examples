# Логирование медленных запросов для функций и CRUD-запросов

В этом руководстве описано, как настроить запись медленных запросов в журнал для функций и CRUD-запросов.
Подробнее о модуле `slow_log` можно узнать в разделе [Логирование медленных запросов](https://www.tarantool.io/docs/tdb/ru/2_x/admin_guide/troubleshooting/slow_log).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Включение журнала медленных запросов](#включение-журнала-медленных-запросов)
* [Запись CRUD-запросов в журнал](#запись-crud-запросов-в-журнал)
* [Логирование пользовательской функции](#логирование-пользовательской-функции)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install_tt);
* исходные файлы примера `slow_log`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `slow_log` расположен в директории `examples/slow_log`.
>  * Отдельный архив [slow_log.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Fslow_log&filename=slow_log), скачанный из этого репозитория.

## Используемые файлы

Для запуска и настройки кластера используются файлы из папки `slow_log`:

* `cluster/` — директория c файлами для запуска кластера Tarantool DB:
  * `config.yml` — конфигурация и топология кластера;
  * `docker-compose.yml` — описание узлов кластера Tarantool DB;
  * `migrations/scenario` — директория, содержащая файлы с описанием [миграций](https://www.tarantool.io/docs/tdb/ru/2_x/user_guide/migrations);
* `tools/` — директория с файлами для запуска кластера etcd и TCM:
  * `docker-compose.yml` — описание узлов кластера etcd;
  * `tcm.yml` — конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/tooling/tcm/).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301—3304
* 8081

Перейдите в директорию примера `slow_log`:

```shell
cd examples/slow_log
```

Запустите стенд Tarantool DB:

```shell
make start
```

Команда развернет стенд, состоящий из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `data`:

```lua
box.space
```

Спейс `data` должен присутствовать в выводе, он создается при запуске кластера.

Роль `slow_log` задана на роутере.
Чтобы проверить это, перейдите в выбранном роутере на вкладку **Details**.
Видно, что в поле `roles` заданы роли `roles.crud-router` и `app.roles.slow_log`.

## Включение журнала медленных запросов

Чтобы включить логирование медленных запросов:
1. В TCM перейдите на вкладку **Configuration**.
2. В секции конфигурации `roles_cfg` замените `enable: false` на `enable: true`:
   ```yaml
   roles_cfg:
     app.roles.slow_log:
       enable: true # <--
   ```
3. Нажмите кнопку **Apply**.

## Запись CRUD-запросов в журнал

В примере данные хранятся в спейсе `data`, который имеет следующий формат:

```lua
box.schema.space.create('data', {if_not_exists = true})
box.space.data:format({
    { name = 'id', type = 'number' },
    { name = 'bucket_id', type = 'unsigned' },
    { name = 'data', type = 'any' },
})
box.space.data:create_index('pk', { parts = {'id'}, if_not_exists = true})
box.space.data:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
```

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру, используя **первый способ** — через TCM. Для этого:

1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

На вкладке **Terminal** добавьте кортеж в спейс `data`, используя функцию из модуля CRUD:

```lua
require('crud').replace("data", {1, box.NULL, {}})
```

Вернитесь в локальный терминал и просмотрите логи приложения:

```shell
cd cluster
docker compose logs tarantool-router-msk | grep 'Function call crud'
cd ..
```

Запись в логе может выглядеть так:

```shell
tarantool-router-msk-1  | 2025-02-05 11:17:23.203 [1] main/231/main/app.roles.slow_log slow_log.lua:21
I> Function call crud.replace(["data",[1,null,[]]]) was too long: 0.000s
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

Чтобы включить запись в журнал для функции `app.wait_for`, обновите секцию `app.roles.slow_log` в файле конфигурации:

```yaml
roles_cfg:
  app.roles.slow_log:
    enable: true
    threshold: 0.0
    namespaces:
      - app
      - crud
```

В TCM на вкладке **Stateboard** выберите роутер `router-msk` и подключитесь к нему, открыв вкладку **Terminal**.

Во вкладке **Terminal** вызовите функцию `app.wait_for`, задав для нее значение в 3 секунды:

```lua
box.schema.func.call('app.wait_for', 3)
```

Вернитесь в локальный терминал и просмотрите логи приложения:

```shell
cd cluster
docker compose logs tarantool-router-msk | grep wait_for
cd ..
```

Запись в логе может выглядеть так:

```
tarantool-router-msk-1  | 2025-02-05 11:55:16.351 [1] main/792/main/tarantool [string "return                     function(sleep_tim..."]:4 I> start wait_for 3
tarantool-router-msk-1  | 2025-02-05 11:55:19.351 [1] main/792/main/tarantool [string "return                     function(sleep_tim..."]:6 I> stop wait_for 3
tarantool-router-msk-1  | 2025-02-05 11:55:19.351 [1] main/792/main/app.roles.slow_log slow_log.lua:21 I> Function call app.wait_for([3]) was too long: 3.000s
```

При использовании модуля `slow_log` персистентные функции заменяются на версии с логированием времени выполнения.
Оригинальные функции сохраняются с префиксом `__slow_log_orig_`.
Для функции `app.wait_for` будет создана функция `__slow_log_orig_app.wait_for`.
После отключения модуля функция `__slow_log_orig_app.wait_for` будет удалена.

## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
