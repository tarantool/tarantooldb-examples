(user_guide-slow_log-example)=
# Логирование медленных запросов для функций и CRUD-запросов

В этом руководстве описано, как настроить запись медленных запросов в журнал для функций и CRUD-запросов.

Подробнее о модуле `slow_log` можно узнать в разделе [Логирование медленных запросов](user_guide-slow_log).

Руководство включает следующие шаги:

* [](user_guide-slow_log-prereq)
* [](user_guide-slow_log-start_example)
* [](user_guide-slow_log-crud)
* [](user_guide-slow_log-function)
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

(user_guide-slow_log-start_example)=
## Запуск стенда

Перейдите в директорию примера `slow_log`:

```shell
cd ./doc/examples/slow_log/
```

Запустите стенд Tarantool DB:

```shell
docker compose up -d
```

Команда поднимает кластер с двумя хранилищами и одним роутером.
Роль `slow_log` задана на роутере.

Подробная информация о том, как включить логирование медленных запросов и задать соответствующую конфигурацию, приведена в разделе [](user_guide-slow_log-set_config).

Чтобы гарантированно получить сообщение в логе, задайте для опции `slow_log.threshold` значение `0` в конфигурационном файле:

```yaml
threshold: 0
```

(user_guide-slow_log-crud)=
## Запись CRUD-запросов в журнал

Подключитесь к роутеру с помощью команды `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных.

В примере данные хранятся в спейсе `data` со следующим форматом:

```{literalinclude} bootstrap/migrations/source/001_test.lua
:start-after: if is_storage
:end-before: box.space.data:create_index
:language: lua
:dedent:
```

Добавьте кортеж в спейс `data`, используя функцию из модуля CRUD:

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

(user_guide-slow_log-function)=
## Логирование пользовательской функции

В примере создана персистентная функция `app.wait_for`, которая ждет заданное количество секунд:

```{literalinclude} bootstrap/migrations/source/001_test.lua
:start-at: box.schema.func.create
:end-before: return true
:language: lua
:dedent:
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

```
slow_log-tarantool-router-1    | 2023-11-30 14:13:52.738 [12] main/225/main/tarantool I> start wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantool I> stop wait_for 3
slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantooldb.app.roles.slow_log I> Function call app.wait_for([3]) was too long: 3.002s
```

При использовании модуля персистентные функции заменяются на версии с логированием времени выполнения.
Оригинальные функции сохраняются с префиксом `__slow_log_orig_`.
Для функции `app.wait_for` будет создана функция `__slow_log_orig_app.wait_for`.
После отключения модуля функция `__slow_log_orig_app.wait_for` будет удалена.

(user_guide-slow_log-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
