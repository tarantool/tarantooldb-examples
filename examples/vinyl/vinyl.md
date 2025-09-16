(user_guide-vinyl_spaces)=
# Использование спейсов vinyl

Доступно с версии 3.0.0.

В этом руководстве описано, как настроить и использовать спейсы на дисковом движке vinyl.

(user_guide-vinyl_spaces-prereq)=
## Пререквизиты

Для выполнения примера вам понадобятся:

- установленный [Docker-образ](install_docker-image) Tarantool DB; 
- приложение Docker Compose;
- утилита [tt CLI](install-install_tt);
- исходные файлы примера `vinyl`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `vinyl` расположен в таком архиве в директории `./doc/examples/vinyl/`.
    
  * Отдельный архив [vinyl.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/vinyl/vinyl.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-vinyl_spaces-start_example)=
## Запуск стенда

Для успешного запуска стенда должны быть свободны следующие порты: 

- 2379
- 3300--3308
- 8081

Перейдите в папку с примером `vinyl`:

```shell
cd ./doc/examples/vinyl/
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
- веб-интерфейс [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме `init_host`.
Контейнер `init_host` используется только для инициализации и завершает свою работу после настройки кластера.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Через TCM вы можете управлять кластером и подключаться к его узлам.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

(user_guide-vinyl_spaces-description)=
## Особенности работы с vinyl

При работе с дисковым движком vinyl необходимо учитывать следующие особенности, отличающие его от движка memtx: 

- функция `len()` возвращает только приблизительное количество кортежей в спейсе.
  Если необходимо точное количество кортежей, используйте функцию `count()` или `pairs():length()`, но имейте в виду, что эти операции
  значительно медленнее;
- операция `delete` не возвращает удалённый кортеж.
  Если нужно получить значение удаленного кортежа, перед его удалением выполните операцию `get`;
- возможно переключение контекста файбером при чтении из vinyl, поскольку данные могут отсутствовать в памяти и
  придется обращаться к диску.

Подробнее о различиях между vinyl и memtx можно узнать в [документации Tarantool](https://www.tarantool.io/en/doc/latest/platform/engines/memtx_vinyl_diff/).

(user_guide-vinyl_spaces-create)=
## Создание спейса vinyl

В руководстве при запуске кластера применяется [миграция](user_guide-migrations) из файла
`./cluster/migrations/scenario/001_messages.lua` примера `vinyl`.
В этой миграции создан на движке vinyl шардированный спейс `messages` для хранения пользовательских сообщений:

```{literalinclude} cluster/migrations/scenario/001_messages.lua
:start-after: local function apply()
:end-at: helpers.register_sharding_key
:language: lua
:dedent:
```

(user_guide-vinyl_spaces-create-index)=
### Составной первичный индекс

Спейс `messages` использует составной первичный индекс по двум полям:

```{literalinclude} cluster/migrations/scenario/001_messages.lua
:start-at: box.space.messages:create_index
:end-before: helpers.register_sharding_key
:language: lua
:dedent:
```

Здесь:

- `bucket_id` -- идентификатор виртуального сегмента, используемый для шардирования;
- `id` -- идентификатор сообщения.

При использовании движка vinyl создание отдельного вторичного индекса по `bucket_id` избыточно и неэффективно по
двум причинам:
- каждый вторичный индекс в vinyl представляет собой отдельное LSM-дерево, требующее дополнительное место на диске;
- при поиске по вторичному индексу Tarantool сначала находит первичный ключ во вторичном индексе, а затем обращается
  к первичному индексу для получения полной записи.
  При выполнении range-запроса это приводит к случайным чтениям с диска.

Использование составного первичного индекса `{ bucket_id, id }` дает возможность шардирования без издержек вторичного
индекса.

Для настройки производительности индексов в vinyl доступны следующие параметры конфигурации: 

- `vinyl.bloom_fpr` -- коэффициент ложноположительного срабатывания фильтра Блума.
  Чем ниже значение, тем точнее фильтр, но больше потребление памяти.
  Значение по умолчанию: 0.05;
- `vinyl.page_size` -- размер страницы при чтении и записи в байтах.
  Значение по умолчанию: 8192;
- `vinyl.range_size` -- максимальный размер диапазона по умолчанию (в байтах);
- `vinyl.run_count_per_level` -- максимальное количество файлов (забегов) на каждом уровне LSM-дерева.
  Чем больше значение, тем шире LSM-дерево.
  Значение по умолчанию: 2;
- `vinyl.run_size_ratio` -- соотношение между размерами уровней в LSM-дереве.
  Чем меньше значение, тем выше LSM-дерево.
  Значение по умолчанию: 3.5.

Задать эти настройки можно в YAML-конфигурации кластера в секции `vinyl`.
Подробную информацию о поддерживаемых опциях конфигурации для движка vinyl можно найти в
[документации Tarantool](https://www.tarantool.io/ru/doc/latest/reference/configuration/configuration_reference/#vinyl).

(user_guide-vinyl_spaces-create-sharding_key)=
### Регистрация ключа шардирования

Модуль `CRUD` по умолчанию вычисляет `bucket_id` по первичному ключу, поэтому в миграции необходимо явно указать `id`
в качестве ключа шардирования:

```{literalinclude} cluster/migrations/scenario/001_messages.lua
:start-at: helpers.register_sharding_key
:end-at: helpers.register_sharding_key
:language: lua
:dedent:
```

(user_guide-vinyl_spaces-crud)=
## Работа с данными через модуль CRUD

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Это можно сделать двумя способами:

- через веб-интерфейс TCM;
- через терминал с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:

1. Перейдите в раздел **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal** (`TT Connect`).

Теперь вы находитесь в интерактивной консоли Tarantool и можете выполнять запросы к кластеру.

(user_guide-vinyl_spaces-crud-functions)=
### Определение вспомогательных функций

Для удобства ввода данных добавьте в консоли следующие вспомогательные функции:

- `now()` -- функция возвращает текущее время: 

  ```lua
  function now()
      local datetime = require('datetime')
      return datetime.now()
  end
  ```

- `get_pk(id)` -- функция формирует первичный ключ в виде `{ bucket_id, id }`, вычисляя `bucket_id`:

  ```lua
  function get_pk(id)
      return { vshard.router.bucket_id_strcrc32(id), id }
  end
  ```

(user_guide-vinyl_spaces-crud-insert)=
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

(user_guide-vinyl_spaces-crud-select)=
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

(user_guide-vinyl_spaces-crud-get)=
### Получение одной записи

Прочитайте запись с `id = 1`:

```lua
crud.get('messages', get_pk(1))
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

(user_guide-vinyl_spaces-crud-update)=
### Обновление записи

Обновите сообщение с `id = 2`, изменив его текст:

```lua
crud.update('messages', get_pk(2), { {'=', 'text', 'Some text'} })
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

(user_guide-vinyl_spaces-crud-delete)=
### Удаление записи

Удалите сообщение с `id = 1`:

```lua
crud.delete('messages', get_pk(1))
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

```{note}
Операция `delete` в vinyl **не возвращает** удалённый кортеж.
```

(user_guide-vinyl_spaces-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
