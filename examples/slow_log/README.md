# Модуль логирования долгих запросов slow_log

Модуль логирования `slow_log` нужен для логирования долгих запросов по iproto.

### Примечание

- Использование **slow_log** может быть ресурсоемким и оказать значительное негативное влияние на производительность. Рекомендуем перед включением роли провести нагрузочное тестирование для оценки потенциального влияния на производительность. 
- Результаты работы **slow_log** не могут использоваться в качестве измерения производительности, так как сама функциональность slow_log может оказывать значительное влияние на результат.

## Конфигурация

Для использования модуля необходимо включить на нужном инстансе роль **slow_log** и добавить секцию ``slow_log`` в конфиг.

Активация slow_log-а в конфиге:

```yaml
slow_log:
  enable: true
```

Установить ``threshold`` после которого запросы будут логироваться как "долгие" можно устноавить так:

```yaml
slow_log:
  enable: true
  threshold: 0.01
```

По умолчанию **threshold** равен ``0.5``.

По умолчанию логирование будет включено для запоросов через модуль [``crud``](https://github.com/tarantool/crud).

Добавить функции которые нужно логировать можно так:

```
slow_log:
  enable: true
  threshold: 0.01
  namespaces:
    - "app"
```

Здесь установлено логирование для функций из модуля ``app``(функции из ``_G['app']``) и для персистентных функций с префиксом ``app.``.

## Пример использования

В качестве примера рассмотрим простое приложение с двумя стораджами и одним роутером. Роль ``slow_log`` активна на роутере.

Данные хранятся в спейсе ``data``:

```lua
box.schema.space.create('data', {if_not_exists = true})
box.space.data:format({
    { name = 'id', type = 'number' },
    { name = 'bucket_id', type = 'unsigned' },
    { name = 'data', type = 'any' },
})
```

Также создана персистентная функция ``app.wait_for``, которая спит переданное количество секунд.

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


1. Запустим пример ``docker-compose up -d``.
2. Проверим логирование через ``crud``.
   Выставим в конфиге ``threshold`` в 0, чтобы гарантированно получить сообщение в логе.
3. Подключимся через ``tt`` к роутеру и через ``crud`` добавим запись

   ``tt connect admin:secret-cluster-cookie@localhost:3300``

   ``require('crud').replace("data", {1, box.NULL, {}})``
4. Посмотрим логи приложения:

   ``docker-compose logs | grep 'Function call crud'``

   Должен найтись такой лог:

   ```
    slow_log-tarantool-router-1    | 2023-11-30 14:02:35.599 [12] main/176/main/tarantooldb.app.roles.slow_log I> Function call crud.replace(["data",[1,null,[]]]) was too long: 0.011s
   ```
5. Теперь добавим поддержку логирования для функции ``app.wait_for``
    Необходимо обновить секцию ``slow_log`` в конфиге:
    ```
    enable: true
    threshold: 3
    namespaces:
    - app
    ```
6. Проверим функцию ``app.wait_for``

    Подключимся через tt к роутеру.

    ``tt connect admin:secret-cluster-cookie@localhost:3300``
    
    ``box.schema.func.call('app.wait_for', 3)``
7. Проверим логи

    ``docker-compose logs | grep wait_for``

    Должен найтись такой лог:

    ```
    slow_log-tarantool-router-1    | 2023-11-30 14:13:52.738 [12] main/225/main/tarantool I> start wait_for 3
    slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantool I> stop wait_for 3
    slow_log-tarantool-router-1    | 2023-11-30 14:13:55.740 [12] main/225/main/tarantooldb.app.roles.slow_log I> Function call app.wait_for([3]) was too long: 3.002s
    ```

При использовании модуля персистентные функции заменяются на версии с логированием времени выполнения, оригинальные функции
сохраняются с префиксом ``__slow_log_orig_``. В случае с ``app.wait_for`` при использовании ``slow_log`` будет создана функция
``__slow_log_orig_app.wait_for``. После отключения модуля ``__slow_log_orig_app.wait_for`` будет удалена.
