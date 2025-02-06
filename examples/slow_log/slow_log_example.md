(admin_guide-slow_log-example)=
# Логирование медленных запросов для функций и CRUD-запросов

В этом руководстве описано, как настроить запись медленных запросов в журнал для функций и CRUD-запросов.
Подробнее о модуле `slow_log` можно узнать в разделе [Логирование медленных запросов](admin_guide-slow_log).

Руководство включает следующие шаги:

* [](admin_guide-slow_log-prereq)
* [](admin_guide-slow_log-files)
* [](admin_guide-slow_log-start_example)
* [](admin_guide-slow_log-enable)
* [](admin_guide-slow_log-crud)
* [](admin_guide-slow_log-function)
* [](admin_guide-slow_log-stop_example)

(admin_guide-slow_log-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* исходные файлы примера `slow_log`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `slow_log` расположен в таком архиве в директории `./doc/examples/slow_log/`.
    
  * Отдельный архив [slow_log.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/slow_log/slow_log.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-slow_log-files)=
## Используемые файлы

Для запуска и настройки кластера используются файлы из папки `slow_log`:

* `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  * `migrations/scenario` -- директория, содержащая файлы с описанием [миграций](user_guide-migrations);
* `tools/` -- директория с файлами для запуска кластера etcd и TCM:
  * `docker-compose.yml` -- описание узлов кластера etcd;
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/tooling/tcm/).

(admin_guide-slow_log-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301--3304
* 8081

Перейдите в директорию примера `slow_log`:

```shell
cd ./doc/examples/slow_log/
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
- 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

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

(admin_guide-slow_log-enable)=
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

(admin_guide-slow_log-crud)=
## Запись CRUD-запросов в журнал

В примере данные хранятся в спейсе `data`, который имеет следующий формат:

```{literalinclude} cluster/migrations/scenario/001_test.lua
:start-at: box.schema.space.create
:end-before: helpers.register_sharding_key
:language: lua
:dedent:
```

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру, используя **первый способ** -- через TCM. Для этого:

1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
2. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
  
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

(admin_guide-slow_log-function)=
## Логирование пользовательской функции

В примере создана персистентная функция `app.wait_for`, которая ждет заданное количество секунд:

```{literalinclude} cluster/migrations/scenario/001_test.lua
:start-at: box.schema.func.create
:end-before: return true
:language: lua
:dedent:
```

Чтобы включить запись в журнал для функции `app.wait_for`, обновите секцию `app.roles.slow_log` в файле конфигурации:

```{include}  /reference/configuration_reference.md
:start-after: (configuration_reference-slow_log-example_start)=
:end-before: (configuration_reference-slow_log-example_end)
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

(admin_guide-slow_log-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
