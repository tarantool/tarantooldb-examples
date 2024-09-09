(user_guide-expirationd_user_logic)=
# Проверка устаревших кортежей в спейсе с помощью пользовательских функций

В этом руководстве описано, как удалять все кортежи в спейсе старше заданного времени.
Определение устаревших кортежей и их обработка определяется пользовательскими функциями.
Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](user_guide-expirationd).

Руководство включает следующие шаги:

* [](user_guide-expirationd_user_logic_example-prereq)
* [](user_guide-expirationd_user_logic_example-start_example)
* [](user_guide-expirationd_user_logic_example-migration)
* [](user_guide-expirationd_user_logic_example-add_data)
* [](user_guide-expirationd_user_logic_example-config)
* [](user_guide-expirationd_user_logic_example-functions)
* [](user_guide-expirationd_user_logic_example-stop_example)

(user_guide-expirationd_user_logic_example-prereq)=
## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* утилита [TT CLI](install-install_tt);
* исходные файлы примера `expirationd_user_logic`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `expirationd` расположен в таком архиве в директории `./doc/examples/expirationd_user_logic/`.
    
  * Отдельный архив [expirationd_user_logic.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/expirationd_user_logic/expirationd_user_logic.tar.gz), скачанный c сайта Tarantool.
  ```
  
(user_guide-expirationd_user_logic_example-start_example)=
## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd`:

```shell
cd ./doc/examples/expirationd_user_logic/
```

Запустите кластер:

```shell
make start
```

Запущенный стенд состоит из:
- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- кластера etcd из 3 узлов;
- 1 узла [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `messages`:

```lua
box.space
```

Спейс `messages` должен присутствовать в выводе, он создается при запуске кластера.

(user_guide-expirationd_user_logic_example-migration)=
## Описание миграции

В руководстве используется миграция из файла `./cluster/migrations/scenario/001_test.lua` примера `expirationd_user_logic`.
В этой миграции:
- создан спейс `messages`;
- созданы персистентные функции с логикой устаревания данных -- `messages_is_tuple_expired`, `messages_iterate_with`, `messages_process_expired_tuple`;
- созданы тестовые функции для генерации данных:
  - `__start_messages_stream` -- запуск фоновой записи тестовых данных в спейс `messages`;
  - `__stop_messages_stream` -- остановка фоновой записи тестовых данных в спейс.

В примере создан спейс `messages` со следующим форматом:

```{literalinclude} cluster/migrations/scenario/001_test.lua
:start-after: -- создание спейса messages
:end-before: helpers.register_sharding_key
:language: lua
:dedent:
```

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

(user_guide-expirationd_user_logic_example-add_data)=
## Подключение к узлу и загрузка тестовых данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:
- В терминале с помощью команды `tt connect`:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301

- В веб-интерфейсе TCM.

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:
	
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

(user_guide-expirationd_user_logic_example-config)=
## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:

```{literalinclude} cluster/config.yml
:start-at: roles_cfg
:end-at: seconds
:language: yaml
:dedent:
```

Здесь:
  
* `messages_expiration` -- название задачи по устареванию данных;
  * `space` -- название спейса, по которому идет поиск устаревших кортежей;
  * `is_expired` -- название функции, которая получает кортеж и проверяет его срок жизни;
  * `is_master_only` -- экспирация запущена только на master-узлах;
  * `options` -- дополнительные опции конфигурации:
    * `tuples_per_iteration` -- количество кортежей, которое проверяется за одну итерацию;
    * `iterate_with` -- название функции, которая получает и обрабатывает устаревшие кортежи;
    * `process_expired_tuple` -- название функции, возвращающей итератор для обхода спейса;
    * `args` -- аргументы, доступные в функциях `message_iterate_with` и `message_process_expired_tuple`, `seconds` --
      время жизни кортежа.
  
Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](configuration_reference-expirationd).

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
Проверить текущее количетсво записей в таблице можно так:

```lua
crud.count('messages')
```

(user_guide-expirationd_user_logic_example-functions)=
## Функции для экспирации и конфигурация expirationd

В функции для обработки устаревших кортежей (`process_expired_tuple`) можно не только удалять, но и выполнять любые
другие операции, в том числе операции по сети.
При этом, чем быстрее работает функция `process_expired_tuple`, тем меньше вероятность, что ее работа отразится на 
общей производительности экземпляра.

(user_guide-expirationd_user_logic_example-stop_example)=
## Остановка кластера

Чтобы остановить кластер, выполните в локальном терминале следующую команду:

```shell
make stop
```
