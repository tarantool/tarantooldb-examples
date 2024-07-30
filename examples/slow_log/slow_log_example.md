(user_guide-slow_log-example)=
# Логирование медленных запросов для функций и CRUD-запросов

В этом руководстве описано, как настроить запись медленных запросов в журнал для функций и CRUD-запросов.

Подробнее о модуле `slow_log` можно узнать в разделе [Логирование медленных запросов](user_guide-slow_log).

Руководство включает следующие шаги:

* [](user_guide-slow_log-prereq)
* [](user_guide-slow_log-files)
* [](user_guide-slow_log-start_example)
* [](user_guide-slow_log-crud)
* [](user_guide-slow_log-function)
* [](user_guide-slow_log-stop_example)

(user_guide-slow_log-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](install-install_tt);
* исходные файлы примера `slow_log`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `slow_log` расположен в таком архиве в директории `./doc/examples/slow_log/`.
    
  * Отдельный архив [slow_log.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/slow_log/slow_log.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-slow_log-files)=
## Используемые файлы

Для запуска и настройки кластера используются файлы из папки `slow_log`:

* `docker-compose.yml` -- описание узлов кластера;
* `config.yml` -- конфигурация и топология кластера;
* `migrations/scenario` -- директория, содержащая файлы с описанием [миграций](user_guide-migrations);
* `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

(user_guide-slow_log-start_example)=
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
docker compose up -d
```

Команда развернет стенд, состоящий из:

- кластера Tarantool DB:
  - 1 роутер;
  - 1 набор реплик на 4 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
  - 2 координатора автоматического восстановления после сбоев (*failover coordinator*);
- кластера etcd из 3 узлов.


После запуска должны работать все контейнеры, кроме `init_host`.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Получить пароль для входа в TCM можно так:

```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте TCM в браузере по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

Чтобы настроить кластер:

1. В веб-интерфейсе перейдите на вкладку **Clusters**.
2. В строке с кластером `Default cluster` нажмите кнопку **...** (**Actions**) справа и выберите **Edit** в выпадающем меню.
3. Переключитесь на второй экран настройки, используя кнопку **Next**.
4. На втором экране укажите в поле **Prefix** значение `/tdb` и нажмите  **Next**.
5. На третьем экране укажите следующие значения:
    - в поле **Username** -- `admin`;
    - в поле **Password** --  `secret-cluster-cookie`.

6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**.
8. Выберите любой роутер из списка (например, `router-1`) и в открывшемся окне перейдите на вкладку **Terminal**.
9. Во вкладке **Terminal** введите команду `box.space`. Проверьте, что в выводе есть спейс `data` -- этот спейс создается при запуске кластера.
10. Роль `slow_log` задана на роутере. Чтобы проверить это, перейдите в выбранном роутере на вкладку **Details**.
    Видно, что в поле `roles` заданы роли `roles.crud-router` и `app.roles.slow_log`.

(user_guide-slow_log-crud)=
## Запись CRUD-запросов в журнал

В примере данные хранятся в спейсе `data`, который имеет следующий формат:

```{literalinclude} migrations/scenario/001_test.lua
:start-at: box.schema.space.create
:end-before: helpers.register_sharding_key
:language: lua
:dedent:
```

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- В терминале на вашем ПК с помощью команды `tt connect`:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

- В веб-интерфейсе TCM.

Подключитесь к роутеру `router-1`, используя **первый способ** -- через TCM. Для этого:
	
1. Перейдите на вкладку **Stateboard**.
2. Выберите роутер `router-1` и в открывшемся окне перейдите на вкладку **Terminal**.
  
Добавьте кортеж в спейс `data`, используя функцию из модуля CRUD:

```lua
require('crud').replace("data", {1, box.NULL, {}})
```

Вернитесь в локальный терминал и просмотрите логи приложения:

```shell
docker compose logs | grep 'Function call crud'
```

Запись в логе может выглядеть так:

```shell
slow_log-tarantool-router-1    | 2023-11-30 14:02:35.599 [12] main/176/main/tarantooldb.app.roles.slow_log I> Function call crud.replace(["data",[1,null,[]]]) was too long: 0.011s
```

(user_guide-slow_log-function)=
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
app.roles.slow_log:
  enable: true
  threshold: 3
  namespaces:
    - app
```

Подключитесь к роутеру в TCM на вкладке **Stateboard**, выбрав роутер `router-1` и открыв вкладку **Terminal**.

Вызовите функцию `app.wait_for`, задав для нее значение в 3 секунды:

```lua
box.schema.func.call('app.wait_for', 3)
```

Вернитесь в локальный терминал и просмотрите логи приложения:

```shell
docker compose logs | grep wait_for
```

Запись в логе может выглядеть так:

```
slow_log-tarantool-router-1    | 2023-11-30 14:13:52.738 [12] main/225/main/tarantool I> start wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantool I> stop wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantooldb.app.roles.slow_log I> Function call app.wait_for([3]) was too long: 3.002s
```

При использовании модуля `slow_log` персистентные функции заменяются на версии с логированием времени выполнения.
Оригинальные функции сохраняются с префиксом `__slow_log_orig_`.
Для функции `app.wait_for` будет создана функция `__slow_log_orig_app.wait_for`.
После отключения модуля функция `__slow_log_orig_app.wait_for` будет удалена.

(user_guide-slow_log-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
