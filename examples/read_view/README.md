# Фильтрация и итерация в представлениях для чтения с помощью CRUD

В этом разделе приведены подробные примеры использования операций `select` и `pairs` для read view с помощью
модуля [CRUD](https://github.com/tarantool/crud).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда и подключение к узлу](#запуск-стенда-и-подключение-к-узлу)
* [Создание представления для чтения](#создание-представления-для-чтения)
* [Фильтрация кортежей с помощью select](#фильтрация-кортежей-с-помощью-select)
* [Итерация с помощью pairs](#итерация-с-помощью-pairs)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* исходные файлы примера `read_view`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `read_view` расположен в директории `examples/read_view`.
>  * Отдельный архив [read_view.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fread_view&filename=read_view), скачанный из этого репозитория.

## Запуск стенда и подключение к узлу

Перейдите в директорию примера `read_view`:

```shell
cd examples/read_view
```

Запустите стенд через Docker Compose:

```shell
docker compose up -d
```

Команда развернет кластер, состоящий из одного роутера и двух наборов реплик по 2 экземпляра в каждой.
На завершающем этапе поднятия кластера вызывается команда автоматического бутстрапа и [миграции](../migrations/README.md).
Миграции создают спейс `customers` (файл `./bootstrap/migrations/source/001_create_space.lua`) и
загружают в него данные (файл `./bootstrap/migrations/source/002_data.lua`).
Спейс имеет следующий формат:

```lua
box.schema.space.create('customers', {if_not_exists = true})
box.space.customers:format({
    { name = 'id', type = 'integer' },
    { name = 'bucket_id', type = 'unsigned' },
    { name = 'name', type = 'string' },
    { name = 'surname', type = 'string' },
    { name = 'age', type = 'number' },
})
box.space.customers:create_index('pk', { parts = {'id'}, if_not_exists = true})
box.space.customers:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
box.space.customers:create_index('age_index', { parts = {'age'}, unique = false, if_not_exists = true})
box.space.customers:create_index('full_name', { parts = {'name', 'surname'}, unique = false, if_not_exists = true})
```

Когда в спейс загрузились данные, подключитесь к роутеру с ролью [crud-router](https://www.tarantool.io/docs/tdb/ru/1_x/reference/roles#reference-roles-crud), используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

## Создание представления для чтения

Чтобы создать read view, вызовите функцию `crud.readview()`:

```lua
rv = crud.readview()
```

## Фильтрация кортежей с помощью select

Метод `read_view_object:select()` позволяет фильтровать кортежи по условиям.
Каждое условие должно использовать имя поля или имя индекса.
Первое условие с именем индекса используется для итерации по спейсам.
Если условия с именами индексов отсутствуют, выполняется полное сканирование (Map-Reduce).
Остальные условия используются в качестве дополнительных фильтров.
Условие поиска для индексируемого поля должно быть размещено первым, чтобы избежать
полного сканирования.
Чтобы избежать длинных выборок, можно ограничить количество результатов с помощью параметра `first`.

> [!NOTE]
> Если вы укажете ключ шардирования или `bucket_id`, операция `select` будет выполнена на одном узле.
> В противном случае произойдет Map-Reduce по всем узлам.

В примере ниже получены первые 6 кортежей из спейса `customers`:

```lua
rv:select('customers', nil, { first = 6 })
```

Запрос возвращает метаданные, массив кортежей и ошибку:

```yaml
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 1, 12477, 'Elizabeth', 'Bagnall', 12 ]
    - [ 2, 21401, 'Mary', 'Bowman', 46 ]
    - [ 3, 11804, 'David', 'Bradley', 33 ]
    - [ 4, 28161, 'William', 'Bridgens', 81 ]
    - [ 5, 1172, 'Jack', 'Brown', 35 ]
    - [ 6, 13064, 'William', 'Long', 25 ]
- null
...
```

### Запрос по простому индексу

В примере по индексу `age_index` выбраны первые 10 клиентов, возраст которых больше или равен 20.
Так как первое условие — индекс `age_index`, результат отсортирован по возрасту.

```shell
rv:select('customers', { { '>=', 'age_index', 20 } }, { first = 10 })
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 40, 6292, 'Evelyn', 'Mishra', 20 ]
    - [ 12, 16624, 'Olivia', 'Kinsella', 22 ]
    - [ 25, 158, 'Ava', 'Fisher', 23 ]
    - [ 34, 9834, 'Amelia', 'Ahmed', 24 ]
    - [ 6, 13064, 'William', 'Long', 25 ]
    - [ 23, 28454, 'Mia', 'Morrison', 25 ]
    - [ 20, 3826, 'Abigail', 'Gauld', 26 ]
    - [ 29, 17582, 'Chloe', 'Walters', 27 ]
    - [ 14, 24056, 'Emily', 'Grimshaw', 28 ]
    - [ 38, 26474, 'Avery', 'Murray', 28 ]
- null
...
```

Здесь запросы по индексу `age_index` и полю `age` эквивалентны, в обоих случаях поиск будет осуществляться по индексу без полного сканирования:

```lua
rv:select('customers', { { '>=', 'age_index', 20 } }, { first = 10 })
rv:select('customers', { { '>=', 'age', 20 } }, { first = 10 })
```

Если имена индекса и поля совпадают, поиск также идет по индексу.

### Запрос по составному индексу

В примере используется составной индекс `full_name`, состоящий из полей `name` и `surname`.
Запрос возвращает 10 первых клиентов, имя и фамилия которых совпадают с условием:

```shell
rv:select('customers', { { '==', 'full_name', { 'Thomas', 'Griffin' } } }, { first = 10 })
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 13, 14925, 'Thomas', 'Griffin', 64 ]
- null
...
```

В запросе также можно использовать часть составного ключа:

```shell
rv:select('customers', { { '==', 'full_name', 'William' } }, { first = 10 })
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 4, 28161, 'William', 'Bridgens', 81 ]
    - [ 6, 13064, 'William', 'Long', 25 ]
    - [ 22, 21655, 'William', 'Norman', 42 ]
- null
...
```

> [!NOTE]
> Если указать частичный ключ не для первого параметра, например ``{ '==', 'full_name', {nil, 'Griffin'}``, будет
> выполнено полное сканирование (Map-Reduce).

### Запрос по полю без индекса

Если указать в запросе не индексируемое поле, в этом случае выполнится полное сканирование (Map-Reduce).

В примере выбраны первые 10 покупателей с заданной фамилией:

```shell
rv:select('customers', { { '==', 'surname', 'Wilcox' } }, { first = 10 })
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 30, 29239, 'Jacob', 'Wilcox', 49 ]
- null
...
```

## Итерация с помощью pairs

Метод `read_view_object:pairs()` позволяет итерироваться по распределенному спейсу.

В примере записаны в таблицу в виде кортежа первые 4 записи:

```lua
tuples = {}
for _, tuple in rv:pairs('customers', nil, { first = 4 }) do
    table.insert(tuples, tuple)
end

tuples
```

Вывод выглядит так:

```yaml
---
- - [ 1, 12477, 'Elizabeth', 'Bagnall', 12 ]
  - [ 2, 21401, 'Mary', 'Bowman', 46 ]
  - [ 3, 11804, 'David', 'Bradley', 33 ]
  - [ 4, 28161, 'William', 'Bridgens', 81 ]
...
```

### Параметр use_tomap

Чтобы итерироваться по объектам или плоским кортежам, используйте параметр `use_tomap` со значением `true`.
В примере в таблицу записаны в виде объектов первые 4 покупателя:

```lua
objects = {}
for _, obj in rv:pairs('customers', nil, { use_tomap = true, first = 4 }) do
    table.insert(objects, obj)
end

objects
```

Вывод выглядит так:

```yaml
---
- - bucket_id: 12477
    id: 1
    surname: Bagnall
    age: 12
    name: Elizabeth
  - bucket_id: 21401
    id: 2
    surname: Bowman
    age: 46
    name: Mary
  - bucket_id: 11804
    id: 3
    surname: Bradley
    age: 33
    name: David
  - bucket_id: 28161
    id: 4
    surname: Bridgens
    age: 81
    name: William
...
```

### Lua Fun

Операция `pairs` совместима с библиотекой [Lua Fun](https://github.com/luafun/luafun).
Примеры работы с основными функциями из этой библиотеки приведены ниже.

#### Filter

Функция [filter()](https://luafun.github.io/filtering.html#filtering) возвращает новый итератор, элементы которого удовлетворяют предикату.
В примере функция-предикат возвращает элементы, у которых значение поля возраста делится на 2 без остатка.

```lua
objects = {}
for _, obj in rv:pairs('customers', nil, { first = 4, use_tomap = true }):filter(function(x)
    return x.age % 2 == 0
end) do
    table.insert(objects, obj)
end

objects
```

Вывод выглядит так:

```yaml
---
- - bucket_id: 12477
    id: 1
    surname: Bagnall
    age: 12
    name: Elizabeth
  - bucket_id: 21401
    id: 2
    surname: Bowman
    age: 46
    name: Mary
...
```

#### Reduce (foldl)

Функция [reduce (foldl)](https://luafun.github.io/reducing.html#fun.foldl) уменьшает итератор слева направо:

```lua
age_sum = crud.pairs('customers', nil, { use_tomap = true }):reduce(function(acc, x)
    return acc + x.age
end, 0)

age_sum
```

Вывод выглядит так:

```yaml
---
- 1441
...
```

#### Map

Функция [map()](https://luafun.github.io/transformations.html#fun.map) возвращает новый итератор, к каждому элементу
которого была применена функция.

```lua
objects = {}
for _, obj in rv:pairs('customers', nil, { first = 4, use_tomap = true }):map(function(x)
    return { id = x.id, name = x.name, age = x.age * 2 }
end) do
    table.insert(objects, obj)
end

objects
```

Вывод выглядит так:

```yaml
---
- - age: 24
    name: Elizabeth
    id: 1
  - age: 92
    name: Mary
    id: 2
  - age: 66
    name: David
    id: 3
  - age: 162
    name: William
    id: 4
...
```

#### Take

Функция [take()](https://luafun.github.io/slicing.html#fun.take) возвращает итератор с заданным количеством
последовательностей:

```lua
tuples = {}
for _, tuple in rv:pairs('customers', { { '>=', 'age', 25 } }):take(2) do
    table.insert(tuples, tuple)
end

tuples
```

Вывод выглядит так:

```yaml
---
- - [ 6, 13064, 'William', 'Long', 25 ]
  - [ 23, 28454, 'Mia', 'Morrison', 25 ]
...
```

## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
