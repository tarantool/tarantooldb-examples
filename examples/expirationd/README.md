# Модуль для отслеживания устаревания данных

Модуль [`expirationd`](https://github.com/tarantool/expirationd) необходим для фоновой обработки данных в рамках одного спейса.

Модуль работает в фоновом режиме и выполняет:
- обход спейса с заданной периодичностью и индексу
- проверку, что tuple удовлетворяет критерию, определенному в заданном пользователем функции `is_expired`
- применение к tuple функции `process_expired_tuple`, заданную пользователем

В `tarantooldb` модуль доступен в виде cartridge роли.

> **Важно**
> 
> Особенностью модуля является то, что персистентные функции, необходимые для его работы необходимо объявлять **заранее, до применения конфига для роли ``expirationd``**.

Для этого примера понадобятся:
* Docker-образ TarantoolDB ([установить](../../INSTALL.md))
* Docker compose
* Tarantool CLI ([установить](https://www.tarantool.io/en/doc/latest/reference/tooling/tt_cli/installation/))

## Пример использования модуля

В примере будет продемострировано как:
- правильно активировать роль expirationd
- настраивать параметры экспирации данных через конфиг

[Код начальной миграции](./bootstrap/migrations/source/001_test.lua).

В миграции:
- Создается спейс `messages`.
- Создаются персистентные функции с логикой экспирации: `messages_is_tuple_expired`, `messages_iterate_with`, `messages_process_expired_tuple`.
- Создаются тестовые функции для генерации данных `__start_messages_stream`, `__stop_messages_stream`.

В примере будет рассмотрен спейс `messages` со следующим форматом:

```lua
box.schema.space.create('messages', {if_not_exists = true})
box.space.messages:format({
    { name = 'id', type = 'uuid' },
    { name = 'bucket_id', type = 'unsigned' },
    { name = 'text', type = 'string' },
    { name = 'create_date', type = 'datetime' },
})
box.space.messages:create_index('pk', { parts = {'id'}, if_not_exists = true})
box.space.messages:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
box.space.messages:create_index('create_date', { parts = {'create_date'}, unique = false, if_not_exists = true})
```

Необходимо удалять все записи в спейсе, старше N секунд. N задается в конфиге.

Для более наглядной демонстрации работы `expirationd` добавлены функции `__start_messages_stream` и `__stops_messages_stream`, они запускают и останавливают фоновую запись тестовых данных в спейс messages.

Для успешного запуска должны быть свободны порты:
* 3300 .. 3304
* 8080 .. 8084

Выполните следующие команды:
``` shell
cd ./docs/examples/expirationd/
docker compose up -d
```

Добавим тестовые данные:

``tt connect admin:secret-cluster-cookie@localhost:3300``

```lua
localhost:3300> box.schema.func.call('__start_messages_stream')
```

Для примера достаточно 100-200 записей в спейсе, посмотреть количество записей можно через [space-explorer](http://localhost:8081/admin/space-explorer/hosts).

Отключаем генерацию данных:

```lua
localhost:3300> box.schema.func.call('__start_messages_stream')
```

Активируем роль expirationd на стораджах:

```bash
curl -sd @activate_expirationd.json http://localhost:8081/admin/api | jq
```

Также можно активировать роль через интерфейс, поставив соответствующую галочку в стораджах.

Теперь нужно задать конфигурацию для expirationd:

Нужно создать секцию `expirationd.yml` и в ней задать следующй конфиг:

```yaml
messages_expiration: # название для задачи по экспирации
    space: messages # название спейса по которому будет производить экспирация
    is_expired: messages_is_tuple_expired # функция, принимающая tuple и возвращающая true, если tuple нужно экспирировать и false, если нет
    is_master_only: true # если true, то экспирация будет запущена только на мастерах
    options: # дополнительные опции
        tuples_per_iteration: 100 # количество таплов которое нужно обойти за одну итерацию  
        iterate_with: messages_iterate_with # функция, возвращающая итератор для обхода спейса
        process_expired_tuple: messages_process_expired_tuple # функция, принимающая tuple и выплняющая его экспирацию
        args: # аргументы, доступные в функциях  message_iterate_with и message_process_expired_tuple
            seconds: 5
```

Согласно данному конфигу задачи по экпирации **messages_expiration** будет выполняться так:

1. Запускается файбер для фоновой экспирации спейса `messages`
2. Файбер обходит спейс `messages` по итератору из функции `messages_iterate_with`.
   В примере `messages_iterate_with` выглялит так:

   ```lua
   -- options из конфига для messages_expiration
   function(options)
       local datetime = require('datetime')
       -- создаем интервал, используя аргументы из конфига
       local int = datetime.interval.new({ sec = options.args.seconds or 60 }) 
       -- возвращаем необходимый итератор
       -- обходим по индексу `create_date`, начинаем от текущей момента минус заданный интервал
       -- если iterator_type == LE, то будут удаляться все записи созданные более чем `options.args.seconds` секунд назад
       return box.space.messages.index.create_date:pairs({ datetime.now() - int }, { iterator = 'LE' })
   end
   ```
3. Для каждого tuple будет применена функция `messages_is_tuple_expired`.
   В примере она всегда возвращает true `function() return true end`.
4. Если messages_is_tuple_expired вернет true, то далее tuple передается в функцию `messages_process_expired_tuple`.
   В примере она просто удаляет указанный tuple
   ```lua
    function(space, args, tuple)
        box.space[space]:delete({tuple.id})
    end
    ```

Подробнее об опциях и возможностях модуля expirationd можно почитать [здесь](https://tarantool.github.io/expirationd/).

После применения конфига можно увидеть, что данные, которые мы сгенерировали были удалены.

Запустим снова генерацию данных уже с включенной экспирацией.

``tt connect admin:secret-cluster-cookie@localhost:3300``

```lua
localhost:3300> box.schema.func.call('__start_messages_stream')
```

Открыв в [space-explorer](http://localhost:8081/admin/space-explorer/hosts) произвольный storage и обновляя страницу браузера, можно увидеть, что количество записей в спейсе не растет и периодически уменьшается. Это означает, что все записи старше 5 секунд удаляются.

В функции для `process_expired_tuple` можно не только удалять, но и выполнять любые другие операции, даже операции по сети. Однако желательно, чтобы `process_expired_tuple` работала как можно быстрее, т.к. в противном случае это может негативно сказаться на общей производительности инстанса.

## Функции для экспирации и конфиг expirationd
Если на инстансе с ролью `expirationd` не будет функций, описанных в конфиге, то конфиг **не применится**. При начальном деплое это может привести к `OperationError`, т.к. миграции будут выполняться после применения конфига для роли `expirationd`.

Для того, чтобы избежать данной ситуации необходимо создавать функции на инстансе до того как:
- на инстансе будет активирована роль `expirationd` в случае, если конфиг с функциями уже применен. Такая ситуация возможна при расширении кластера
- будет применен конфиг для `expirationd`

## Остановка стенда
```shell
docker compose down
```

## Итог
Пример демонстрирует использование модуля `expirationd`.
