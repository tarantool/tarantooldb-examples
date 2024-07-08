(user_guide-slow_log)=
# Логирование медленных запросов

*Журнал медленных запросов* (*slow log*) -- это запись таких [iproto](https://www.tarantool.io/ru/doc/2.11/dev_guide/internals/box_protocol/)-запросов к базе данных,
время выполнения которых превышает заданное пороговое значение.
Для логирования таких запросов используется модуль `slow_log`.
В Tarantool DB модуль доступен в виде технологической роли [slow_log](reference-roles-slow_log).

В этом руководстве описано, как включить и настроить логирование медленных запросов, а также приведен пример приложения,
в котором логирование настроено для функции и CRUD-запросов.

```{admonition} Примечание
:class: note

Модуль `slow_log` может быть ресурсоемким и снижать производительность.
Чтобы оценить потенциальное влияние на нее, перед включением модуля проведите нагрузочное тестирование.
Результаты работы модуля не могут быть использованы для измерения производительности.
```

Руководство включает следующие шаги:

* [](user_guide-slow_log-prereq)
* [](user_guide-slow_log-set_config)
* [](user_guide-slow_log-start_example)
* [](user_guide-slow_log-crud)
* [](user_guide-slow_log-fuction)
* [](user_guide-slow_log-stop_example)

(user_guide-slow_log-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* утилита [TT CLI](install-install_tt);
* исходные файлы примера `slow_log`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `slow_log` расположен в таком архиве в директории `./doc/examples/slow_log/`.
    
  * Отдельный архив [slow_log.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/slow_log/slow_log.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-slow_log-set_config)=
## Конфигурация модуля slow_log

(user_guide-slow_log-set_config-enable)=
### Включение журнала медленных запросов

По умолчанию, запись медленных запросов в журнал отключена.
Включить логирование медленных запросов можно с помощью опции [slow_log.enable](configuration_reference-slow_log-enable).
Для включения записи:
1. Задайте на нужном экземпляре технологическую роль **slow_log**.
2. Добавьте секцию `slow_log` в файл конфигурации (`config.yaml`):

    ```{literalinclude} bootstrap/config.yml
    :start-at: slow_log
    :end-at: enable
    :language: yaml
    :dedent:
    ```

По умолчанию запись будет включена для запросов через модуль [CRUD](https://github.com/tarantool/crud).

(user_guide-slow_log-set_config-threshold)=
### Установка порогового значения

Задать пороговое значение для времени выполнения запроса можно с помощью опции [slow_log.threshold](configuration_reference-slow_log-threshold).
При превышении этого значения запрос будет записан в журнал:

```{literalinclude} bootstrap/config.yml
:start-at: slow_log
:end-at: 0.01
:language: yaml
:dedent:
```

По умолчанию, значение `threshold` равно ``0.5``.

(user_guide-slow_log-set_config-namespace)=
### Добавление функции для логирования

Добавить функции, которые нужно логировать, можно с помощью опции [slow_log.namespace](configuration_reference-slow_log-namespaces).
В примере установлено логирование для

* функций из модуля ``app`` (функции из ``_G['app']``);
* для персистентных функций с префиксом ``app.``.

```yaml
slow_log:
  enable: true
  threshold: 0.01
  namespaces:
    - "app"
```

Полное описание опций конфигурации `slow_log` приведено в [Справочнике по конфигурации](/reference/configuration_reference.md).

(user_guide-slow_log-start_example)=
## Запуск стенда и подключение к узлу

Перейдите в директорию примера `slow_log`:

```shell
cd ./doc/examples/slow_log/
```

Запустите стенд Tarantool DB:

```shell
docker compose up -d`.
```

Команда поднимает кластер с двумя хранилищами и одним роутером.
Роль ``slow_log`` задана на роутере.

Чтобы гарантированно получить сообщение в логе, задайте для опции `slow_log.threshold` значение `0` в конфигурационном файле:

```yaml
threshold: 0
```

Подключитесь к роутеру с помощью команды `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных.

(user_guide-slow_log-crud)=
## Запись CRUD-запросов в журнал

В примере данные хранятся в спейсе ``data`` со следующим форматом:

```{literalinclude} bootstrap/migrations/source/001_test.lua
:start-after: if is_storage
:end-before: box.space.data:create_index
:language: lua
:dedent:
```

Добавьте кортеж в спейс ``data``, используя функцию из модуля CRUD:

```lua
require('crud').replace("data", {1, box.NULL, {}})
```

После просмотрите логи приложения:

```shell
docker compose logs | grep 'Function call crud'
```

Запись в логе может выглядеть так:

```shell
slow_log-tarantool-router-1    | 2023-11-30 14:02:35.599 [12] main/176/main/tarantooldb.app.roles.slow_log I> Function call crud.replace(["data",[1,null,[]]]) was too long: 0.011s
```

(user_guide-slow_log-fuction)=
## Логирование пользовательской функции

В примере создана персистентная функция ``app.wait_for``, которая ждет заданное количество секунд:

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
Чтобы включить запись в журнал для функции `app.wait_for`, обновите секцию ``slow_log`` в файле конфигурации:

```yaml
enable: true
threshold: 3
namespaces:
- app
```

Далее подключитесь к роутеру с помощью утилиты ``tt``:

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

```
slow_log-tarantool-router-1    | 2023-11-30 14:13:52.738 [12] main/225/main/tarantool I> start wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantool I> stop wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantooldb.app.roles.slow_log I> Function call app.wait_for([3]) was too long: 3.002s
```

При использовании модуля персистентные функции заменяются на версии с логированием времени выполнения, оригинальные функции
сохраняются с префиксом ``__slow_log_orig_``.
Для функции ``app.wait_for`` будет создана функция ``__slow_log_orig_app.wait_for``.
После отключения модуля ``__slow_log_orig_app.wait_for`` будет удалена.

(user_guide-slow_log-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
