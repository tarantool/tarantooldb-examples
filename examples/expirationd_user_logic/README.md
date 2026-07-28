# Проверка устаревших кортежей в спейсе с помощью пользовательских функций

В этом руководстве описано, как удалять все кортежи в спейсе старше заданного времени.
Определение устаревших кортежей и их обработка определяется пользовательскими функциями.
Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/expirationd).

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
* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt);
* исходные файлы примера `expirationd_user_logic`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `expirationd_user_logic` расположен в директории `examples/expirationd_user_logic`.
>  * Отдельный архив [expirationd_user_logic.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fexpirationd_user_logic&filename=expirationd_user_logic), скачанный из этого репозитория.

## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081

Перейдите в папку с примером `expirationd_user_logic`:

```shell
cd examples/expirationd_user_logic
```

Запустите кластер:

```shell
make start
```

Запущенный стенд состоит из:
- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- кластера etcd из 3 узлов;
- 1 узла [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `storage-1` узел `storage-1-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `messages`:

```lua
box.space
```

Спейс `messages` должен присутствовать в выводе, он создается при запуске кластера.

## Описание миграции

В руководстве используется миграция из файла `./cluster/migrations/scenario/001_test.lua` примера `expirationd_user_logic`.
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

## Подключение к узлу и загрузка тестовых данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** — через TCM. Для этого:

1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Во вкладке **Terminal** загрузите тестовые данные в спейс, используя функцию `_start_messages_stream`:

```lua
box.schema.func.call('__start_messages_stream')
```

Для примера достаточно 100-200 записей в спейсе.
Чтобы просмотреть кортежи в спейсе `messages`, в веб-интерфейсе TCM перейдите на вкладку **Tuples** и выберите в списке спейс `messages`.
Откроется новая вкладка с содержимым кортежей спейса `messages`.

Когда записей в спейсе станет достаточно, отключите генерацию данных с помощью функции `_stop_messages_stream`:

```lua
box.schema.func.call('__stop_messages_stream')
```

## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:

```yaml
roles_cfg:
  roles.expirationd:
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
    * `args` — аргументы, доступные в функциях `message_iterate_with` и `message_process_expired_tuple`, `seconds` —
      время жизни кортежа.

Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](https://www.tarantool.io/docs/tdb/ru/3_x/reference/configuration_reference#configuration_reference-expirationd).

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

После наполнения спейса данными можно увидеть, что сгенерированные данные начали удаляться.
Проверить текущее количество записей в таблице можно так:

```lua
crud.count('messages')
```

## Функции для экспирации и конфигурация expirationd

В функции для обработки устаревших кортежей (`process_expired_tuple`) можно не только удалять, но и выполнять любые
другие операции, в том числе операции по сети.
При этом, чем быстрее работает функция `process_expired_tuple`, тем меньше вероятность, что ее работа отразится на
общей производительности экземпляра.

## Остановка кластера

Чтобы остановить кластер, выполните в локальном терминале следующую команду:

```shell
make stop
```
