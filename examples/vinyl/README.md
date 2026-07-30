# Использование спейсов на движке vinyl

Доступно с версии 3.0.0.

В этом руководстве описаны создание спейса vinyl, его настройка, а также выполнение операций с этим спейсом через модуль CRUD.

Рекомендации по настройке параметров vinyl приведены в разделе [Методика настройки движка vinyl в Tarantool DataBase](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/using_engines/setup_vinyl).

## Пререквизиты

Для выполнения примера вам понадобятся:

- установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
- приложение Docker Compose;
- утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt);
- исходные файлы примера `vinyl`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `vinyl` расположен в директории `examples/vinyl`.
>  * Отдельный архив [vinyl.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fvinyl&filename=vinyl), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска стенда должны быть свободны следующие порты:

- 2379
- 3300–3308
- 8081

Перейдите в папку с примером `vinyl`:

```shell
cd examples/vinyl
```

Запустите стенд:

```shell
make start
```

После выполнения команды будет развернут следующий стенд:
- кластер Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластер etcd из 3 узлов;
- веб-интерфейс [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме `init_host`.
Контейнер `init_host` используется только для инициализации и завершает свою работу после настройки кластера.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Через TCM вы можете управлять кластером и подключаться к его узлам.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

## Особенности работы с vinyl

При работе с дисковым движком vinyl необходимо учитывать следующие особенности, отличающие его от движка memtx:

- функция `len()` возвращает только приблизительное количество кортежей в спейсе.
  Если необходимо точное количество кортежей, используйте функцию `count()` или `pairs():length()`, но имейте в виду, что эти операции
  значительно медленнее;
- операция `delete` не возвращает удалённый кортеж.
  Если нужно получить значение удаленного кортежа, перед его удалением выполните операцию `get`;
- возможно переключение контекста файбером при чтении из vinyl, поскольку данные могут отсутствовать в памяти и
  придется обращаться к диску.

Подробнее о различиях между vinyl и memtx можно узнать в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/platform/engines/memtx_vinyl_diff/).

## Создание спейса vinyl

В руководстве при запуске кластера применяется [миграция](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/migrations) из файла
`./cluster/migrations/scenario/001_messages.lua` примера `vinyl`.
В этой миграции создан на движке vinyl [шардированный спейс](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/sharding) `messages` для хранения пользовательских сообщений:

```lua
if is_storage() then
    box.schema.space.create('messages', { engine = 'vinyl', if_not_exists = true })
    box.space.messages:format({
        { name = 'id', type = 'number' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'text', type = 'string' },
        { name = 'created_at', type = 'datetime' },
    })

    box.space.messages:create_index('bucket_id', { parts = { 'bucket_id', 'id' }, if_not_exists = true })

    helpers.register_sharding_key('messages', { 'id' })
```

### Составной первичный индекс

Спейс `messages` использует составной первичный индекс по двум полям:

```lua
box.space.messages:create_index('bucket_id', { parts = { 'bucket_id', 'id' }, if_not_exists = true })
```

Здесь:

- `bucket_id` — [идентификатор виртуального сегмента](https://www.tarantool.io/docs/tdb/ru/3_x/admin_guide/sharding), используемый для шардирования;
- `id` — идентификатор сообщения.

При использовании движка vinyl создание отдельного вторичного индекса по `bucket_id` избыточно и неэффективно по
двум причинам:
- каждый вторичный индекс в vinyl представляет собой отдельное LSM-дерево, требующее дополнительное место на диске;
- при поиске по вторичному индексу Tarantool сначала находит первичный ключ во вторичном индексе, а затем обращается
  к первичному индексу для получения полной записи.
  При выполнении range-запроса это приводит к случайным чтениям с диска.

Использование составного первичного индекса `{ bucket_id, id }` дает возможность шардирования без издержек вторичного
индекса.

Для настройки производительности индексов в vinyl доступны следующие параметры конфигурации:

- `vinyl.bloom_fpr` — коэффициент ложноположительного срабатывания фильтра Блума.
  Чем ниже значение, тем точнее фильтр, но больше потребление памяти.
  Значение по умолчанию: 0.05;
- `vinyl.page_size` — размер страницы при чтении и записи в байтах.
  Значение по умолчанию: 8192;
- `vinyl.range_size` — максимальный размер диапазона по умолчанию (в байтах);
- `vinyl.run_count_per_level` — максимальное количество `.run`-файлов на каждом уровне LSM-дерева.
  Чем больше значение, тем шире LSM-дерево.
  Значение по умолчанию: 2;
- `vinyl.run_size_ratio` — соотношение между размерами уровней в LSM-дереве.
  Чем меньше значение, тем выше LSM-дерево.
  Значение по умолчанию: 3.5.

Задать настройки спейса, связанные с движком vinyl, можно двумя способами:
- в YAML-конфигурации кластера в секции `vinyl`;
- в опции [index_opts](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_space/create_index/#index-opts)
  при создании индекса через `space_object:create_index()`.

Подробную информацию о поддерживаемых опциях конфигурации для движка vinyl можно найти в
[документации Tarantool](https://www.tarantool.io/ru/doc/latest/reference/configuration/configuration_reference/#vinyl).

### Регистрация ключа шардирования

Модуль `CRUD` по умолчанию вычисляет `bucket_id` по первичному ключу, поэтому в миграции необходимо явно указать `id`
в качестве ключа шардирования:

```lua
helpers.register_sharding_key('messages', { 'id' })
```

## Работа с данными через модуль CRUD

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Это можно сделать двумя способами:

- через веб-интерфейс TCM;
- через терминал с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** — через TCM. Для этого:

1. Перейдите на раздел **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal** (`TT Connect`).

Теперь вы находитесь в интерактивной консоли Tarantool и можете выполнять запросы к кластеру.

### Определение вспомогательной функции

Для удобства ввода данных добавьте в консоль следующую вспомогательную функцию:

- `now()` — функция возвращает текущее время:

  ```lua
  function now()
      local datetime = require('datetime')
      return datetime.now()
  end
  ```

### Вставка данных

Во вкладке **Terminal** добавьте несколько сообщений в спейс `messages` с помощью метода `crud.insert_object_many`:

```lua
crud.insert_object_many('messages', {
    { id = 1, text = 'Привет!', created_at = now() },
    { id = 2, text = 'Hello world', created_at = now() },
    { id = 3, text = 'Bye', created_at = now() },
    { id = 4, text = 'Ok', created_at = now() },
    { id = 5, text = 'Hi', created_at = now() },
})
```

### Выборка данных

Посмотрите содержимое спейса, используя операцию `crud.select()`:

```lua
crud.select('messages')
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 'Привет!', '2025-08-28T11:12:09.028308Z']
  - [3, 11804, 'Bye', '2025-08-28T11:12:09.028313Z']
  - [5, 1172, 'Hi', '2025-08-28T11:12:09.028333Z']
  - [2, 21401, 'Hello world', '2025-08-28T11:12:09.028312Z']
  - [4, 28161, 'Ok', '2025-08-28T11:12:09.028330Z']
  metadata: [{'name': 'id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'text', 'type': 'string'}, {'name': 'created_at', 'type': 'datetime'}]
- null
...
```

### Получение одной записи

Прочитайте запись с `id = 1`:

```lua
crud.get('messages', { box.NULL, 1 })
```

Вывод:

```shell
---
- rows:
  - [1, 12477, 'Привет!', '2025-08-28T11:12:09.028308Z']
  metadata: [{'name': 'id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'text', 'type': 'string'}, {'name': 'created_at', 'type': 'datetime'}]
- null
...
```

### Обновление записи

Обновите сообщение с `id = 2`, изменив его текст:

```lua
crud.update('messages', { box.NULL, 2 }, { {'=', 'text', 'Some text'} })
```

Вывод:

```shell
---
- rows:
  - [2, 21401, 'Some text', '2025-08-28T11:12:09.028312Z']
  metadata: [{'name': 'id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'text', 'type': 'string'}, {'name': 'created_at', 'type': 'datetime'}]
- null
...
```

### Удаление записи

Удалите сообщение с `id = 1`:

```lua
crud.delete('messages', { box.NULL, 1 })
```

Вывод:

```shell
---
- rows: []
  metadata: [{'name': 'id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'text', 'type': 'string'}, {'name': 'created_at', 'type': 'datetime'}]
- null
...
```

> [!NOTE]
> Операция `delete` в vinyl **не возвращает** удалённый кортеж.

## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
