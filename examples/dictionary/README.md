# Запись и получение данных в словаре

В этом руководстве показано, как записать в словарь данные, а затем получить запись из базы данных с обогащением из словаря.
Для примера используется база данных с категориями денежных трат.

> [!NOTE]
> **Права доступа к кластеру и словарям**
>
> В этом примере для подключения к кластеру и выполнения операций со словарями используется пользователь `admin` с ролью `super`. _Роль_ здесь — это набор прав, которые могут быть предоставлены пользователю. Роль `super` дает полный набор административных прав.
>
> Если требуется ограничить права пользователя, работающего со словарем, можно задать для этого отдельного пользователя. Такой пользователь имеет доступ только к вызову методов API словарей, а также выгрузке и загрузке данных через утилиту tt ClI. Пример работы с таким пользователем описан в разделе [Работа со словарём с ограниченными правами](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/dictionary/dictionary_user_example).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда и подключение к узлу](#запуск-стенда-и-подключение-к-узлу)
* [Запись данных в словарь](#запись-данных-в-словарь)
* [Подготовка нормализованных данных](#подготовка-нормализованных-данных)
* [Чтение данных с обогащением из словаря](#чтение-данных-с-обогащением-из-словаря)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt);
* исходные файлы примера `dictionary`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `dictionary` расположен в директории `examples/dictionary`.
>  * Отдельный архив [dictionary.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fdictionary&filename=dictionary), скачанный из этого репозитория.

## Запуск стенда и подключение к узлу

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081

Перейдите в папку с примером `dictionary`:

```shell
cd examples/dictionary
```

Запустите стенд:

```shell
make start
```

Команда развернет стенд, который состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
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
Во вкладке **Terminal** проверьте наличие спейсов `money_moves`, `dictionary_data` и `dictionary_vclock`:

```lua
box.space
```

```yaml
---
- dictionary_data:
    is_local: true
    is_sync: false
    temporary: false
    engine: memtx
  dictionary_vclock:
    is_local: true
    is_sync: false
    temporary: false
    engine: memtx
  money_moves:
    is_local: false
    is_sync: false
    temporary: false
    engine: memtx
...
```

Узнать больше о спейсе `dictionary_data` можно в разделе [Начало работы с модулем dictionary](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/dictionary/dictionary_gs).

## Запись данных в словарь

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

В примере ниже задается словарь с названием `categories`, который содержит категории денежных трат.
Для записи элементов с соответствующими им ключами в словарь используется метод [dictionary_router_set()](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/dictionary#reference_lua-dictionary-set).

> [!NOTE]
> Tarantool DB 3.x поддерживает как новый формат названий методов dictionary API (`dictionary_router_get()`), так и старый (`dictionary_router.get()`).
> Методы, добавленные в версии Tarantool DB 2.x и выше, поддерживают оба формата названий.

Вызвать метод в новом формате через [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt) или в [TCM](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) во вкладке **Terminal** (`TT Connect`)
можно через `box.schema.func.call`, например:

```lua
box.schema.func.call('dictionary_router_set', 'categories', '1', 'Shops')
```

Вызвать метод в старом формате можно напрямую, например:

```lua
dictionary_router.set('categories', '1', 'Shops')
```

Во вкладке **Terminal** с помощью метода [dictionary_router_set()](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/dictionary#reference_lua-dictionary-set) запишите несколько элементов (`Shops`, `Food delivery` и другие) с соответствующими им ключами в словарь:

```lua
box.schema.func.call('dictionary_router_set', 'categories', '1', 'Shops')
box.schema.func.call('dictionary_router_set', 'categories', '2', 'Food delivery')
box.schema.func.call('dictionary_router_set', 'categories', '3', 'Transport')
box.schema.func.call('dictionary_router_set', 'categories', '4', 'Bills')
box.schema.func.call('dictionary_router_set', 'categories', '5', 'Med')
```

> [!NOTE]
> Ключ элемента в словаре может быть только строкой.

Чтобы проверить записанные в словарь данные, используйте метод [dictionary_router_get()](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/dictionary#reference_lua-dictionary-get):

```lua
box.schema.func.call('dictionary_router_get', 'categories', '1')
```

Вывод:

```yaml
---
- Shops
- null
...
```

## Подготовка нормализованных данных

Чтобы записать нормализованные данные, выполните во вкладке **Terminal** следующий код:

```lua
crud.replace('money_moves', {1, box.NULL, 123, require('datetime').now(), '1', false, 260.01})
crud.replace('money_moves', {2, box.NULL, 123, require('datetime').now(), '2', false, 1234.56})
crud.replace('money_moves', {3, box.NULL, 123, require('datetime').now(), '5', false, 1176.12})
crud.replace('money_moves', {4, box.NULL, 123, require('datetime').now(), '3', false, 30})
crud.replace('money_moves', {5, box.NULL, 123, require('datetime').now(), '3', false, 35})
crud.replace('money_moves', {6, box.NULL, 123, require('datetime').now(), '4', false, 11816.86})
crud.replace('money_moves', {7, box.NULL, 123, require('datetime').now(), '3', false, 218})
crud.replace('money_moves', {8, box.NULL, 123, require('datetime').now(), '1', false, 1026.45})
crud.replace('money_moves', {9, box.NULL, 123, require('datetime').now(), '1', false, 384.32})
crud.replace('money_moves', {10, box.NULL, 123, require('datetime').now(), '2', false, 890.99})
```

Проверьте записанные данные, используйте метод `crud.get()`:

```lua
crud.get('money_moves', 1)
```

Вывод:

```yaml
---
- rows:
  - [1, 12477, 123, '2026-03-24T13:52:27.316389Z', '1', false, 260.01]
  metadata: [{'name': 'money_move_id', 'type': 'number'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'recorder_id', 'type': 'number'}, {'name': 'dt', 'type': 'datetime'},
    {'name': 'category_id', 'type': 'string'}, {'name': 'income', 'type': 'boolean'},
    {'name': 'amount', 'type': 'number'}]
- null
...
```

## Чтение данных с обогащением из словаря

Чтобы получить запись с добавленной информацией из словаря, выполните во вкладке **Terminal** следующую команду:

```lua
box.schema.func.call('get_money_move', 1)
```

Вывод:

```yaml
---
- bucket_id: 12477
  category_id: '1'
  money_move_id: 1
  recorder_id: 123
  amount: 260.01
  income: false
  dt: 2026-03-24T13:52:27.316389Z
  category_name: Shops
...
```

## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
