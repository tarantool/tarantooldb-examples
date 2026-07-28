# Проверка устаревших кортежей в спейсе с помощью пользовательских функций

В этом руководстве описано, как удалять все кортежи в спейсе старше заданного времени.
Определение устаревших кортежей и их обработка определяется пользовательскими функциями.
Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/expirationd).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск кластера](#запуск-кластера)
* [Описание миграции](#описание-миграции)
* [Подключение к узлу и загрузка тестовых данных](#подключение-к-узлу-и-загрузка-тестовых-данных)
* [Конфигурация устаревания данных](#конфигурация-устаревания-данных)
* [Функции для экспирации и конфигурация expirationd](#функции-для-экспирации-и-конфигурация-expirationd)
* [Остановка кластера](#остановка-кластера)

## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* исходные файлы примера `expirationd_user_logic`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `expirationd_user_logic` расположен в директории `examples/expirationd_user_logic`.
>  * Отдельный архив [expirationd_user_logic.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fexpirationd_user_logic&filename=expirationd_user_logic), скачанный из этого репозитория.

## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd`:

```shell
cd examples/expirationd_user_logic
```

Запустите кластер:

```shell
docker compose up -d
```

## Описание миграции

В руководстве используется миграция из файла `./bootstrap/migrations/source/001_test.lua` примера `expirationd_user_logic`.
В этой миграции:
- создан спейс `messages`;
- созданы персистентные функции с логикой устаревания данных — `messages_is_tuple_expired`, `messages_iterate_with`, `messages_process_expired_tuple`;
- созданы тестовые функции для генерации данных:
  - `__start_messages_stream` — запуск фоновой записи тестовых данных в спейс `messages`;
  - `__stop_messages_stream` — остановка фоновой записи тестовых данных в спейс.

В примере создан спейс `messages` со следующим форматом:

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

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

Смотрите также: [Проверка устаревших кортежей с помощью универсальной функции](../expirationd_universal_func/README.md).

## Подключение к узлу и загрузка тестовых данных

Подключитесь к экземпляру, используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Загрузите тестовые данные в спейс, используя функцию `_start_messages_stream`:

```lua
localhost:3300> box.schema.func.call('__start_messages_stream')
```

Для примера достаточно 100-200 записей в спейсе.
Посмотреть количество записей можно в веб-интерфейсе во вкладке **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)).

Когда записей в спейсе станет достаточно, отключите генерацию данных с помощью функции `_stop_messages_stream`:

```lua
localhost:3300> box.schema.func.call('__stop_messages_stream')
```

## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:

```yaml
expirationd:
  messages_expiration:
    space: messages
    is_expired: messages_is_tuple_expired
    is_master_only: true
    options:
      tuples_per_iteration: 100
      iterate_with: messages_iterate_with
      process_expired_tuple: messages_process_expired_tuple
      args:
        seconds: 5
```

Здесь:

* `messages_expiration` — название задачи по устареванию данных;
  * `space` — название спейса, по которому идет поиск устаревших кортежей;
  * `is_expired` — название функции, которая получает кортеж и проверяет его срок жизни;
  * `is_master_only` — экспирация запущена только на master-узлах;
  * `options` — дополнительные опции конфигурации:
    * `tuples_per_iteration` — количество кортежей, которое проверяется за одну итерацию;
    * `iterate_with` — название функции, которая получает и обрабатывает устаревшие кортежи;
    * `process_expired_tuple` — название функции, возвращающей итератор для обхода спейса;
    * `args` — аргументы, доступные в функциях `messages_iterate_with` и `messages_process_expired_tuple`, `seconds` —
      время жизни кортежа.

Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](https://www.tarantool.io/docs/tdb/ru/1_x/reference/configuration_reference#configuration_reference-expirationd).

Согласно этой конфигурации, задачи по устареванию данных `messages_expiration` выполняются так:

1. Запускается файбер для фоновой проверки спейса `messages`.
2. Файбер обходит спейс `messages` по итератору из функции `messages_iterate_with`.
   Функция `messages_iterate_with` выглядит так:

   ```lua
   -- options из конфигурации для messages_expiration
   function(options)
       local datetime = require('datetime')
       -- создан интервал с помощью аргументов из конфигурации
       local int = datetime.interval.new({ sec = options.args.seconds or 60 }) 
       -- возвращен необходимый итератор
       -- обход по индексу `create_date` с началом от текущего момента минус заданный интервал
       -- если iterator_type == LE, то будут удаляться все записи, созданные более чем `options.args.seconds` секунд назад
       return box.space.messages.index.create_date:pairs({ datetime.now() - int }, { iterator = 'LE' })
   end
   ```

3. Срок жизни каждого кортежа проверяется с помощью булевой функции `messages_is_tuple_expired`.
   Значение `true` означает, что срок жизни кортежа истек.
4. Такой кортеж передается в функцию `messages_process_expired_tuple`, которая удалит этот кортеж:

   ```lua
    function(space, args, tuple)
        box.space[space]:delete({tuple.id})
    end
   ```

После применения конфигурации можно увидеть, что сгенерированные ранее данные были удалены.
Подключитесь повторно к узлу кластера:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Запустите еще раз генерацию данных уже с включенным устареванием данных:

```lua
localhost:3300> box.schema.func.call('__start_messages_stream')
```

Теперь откройте в веб-интерфейсе вкладку **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)) и выберите произвольное хранилище.
Начните обновлять страницу браузера.
Видно, что количество записей в спейсе не растет и периодически уменьшается.
Это означает, что удаляются все записи старше 5 секунд.

## Функции для экспирации и конфигурация expirationd

В функции для обработки устаревших кортежей (`process_expired_tuple`) можно не только удалять, но и выполнять любые
другие операции, в том числе операции по сети.
При этом, чем быстрее работает функция `process_expired_tuple`, тем меньше вероятность, что ее работа отразится на общей производительности экземпляра.

## Остановка кластера

Чтобы остановить кластер, выполните следующую команду:

```shell
docker compose down
```
