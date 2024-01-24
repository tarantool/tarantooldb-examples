[Главная страница](../../../README.md)

Тестовый стенд для теста Read view с CRUD
======

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Оглавление**

- [Запуск кластера и наливка данных](#%D0%97%D0%B0%D0%BF%D1%83%D1%81%D0%BA-%D0%BA%D0%BB%D0%B0%D1%81%D1%82%D0%B5%D1%80%D0%B0-%D0%B8-%D0%BD%D0%B0%D0%BB%D0%B8%D0%B2%D0%BA%D0%B0-%D0%B4%D0%B0%D0%BD%D0%BD%D1%8B%D1%85)
  - [Docker](#docker)
- [Примеры работы](#%D0%9F%D1%80%D0%B8%D0%BC%D0%B5%D1%80%D1%8B-%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D1%8B)
  - [Подключение](#%D0%9F%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D0%B5)
    - [Подключение к роутеру](#%D0%9F%D0%BE%D0%B4%D0%BA%D0%BB%D1%8E%D1%87%D0%B5%D0%BD%D0%B8%D0%B5-%D0%BA-%D1%80%D0%BE%D1%83%D1%82%D0%B5%D1%80%D1%83)
  - [Примеры кода](#%D0%9F%D1%80%D0%B8%D0%BC%D0%B5%D1%80%D1%8B-%D0%BA%D0%BE%D0%B4%D0%B0)
    - [Создание объекта read view](#%D0%A1%D0%BE%D0%B7%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%BE%D0%B1%D1%8A%D0%B5%D0%BA%D1%82%D0%B0-read-view)
    - [Select](#select)
      - [Выборка через select](#%D0%92%D1%8B%D0%B1%D0%BE%D1%80%D0%BA%D0%B0-%D1%87%D0%B5%D1%80%D0%B5%D0%B7-select)
      - [Select с индексами](#select-%D1%81-%D0%B8%D0%BD%D0%B4%D0%B5%D0%BA%D1%81%D0%B0%D0%BC%D0%B8)
      - [Select с составным индексом](#select-%D1%81-%D1%81%D0%BE%D1%81%D1%82%D0%B0%D0%B2%D0%BD%D1%8B%D0%BC-%D0%B8%D0%BD%D0%B4%D0%B5%D0%BA%D1%81%D0%BE%D0%BC)
      - [Select с частичным ключём](#select-%D1%81-%D1%87%D0%B0%D1%81%D1%82%D0%B8%D1%87%D0%BD%D1%8B%D0%BC-%D0%BA%D0%BB%D1%8E%D1%87%D1%91%D0%BC)
      - [Select по не индексированному полю](#select-%D0%BF%D0%BE-%D0%BD%D0%B5-%D0%B8%D0%BD%D0%B4%D0%B5%D0%BA%D1%81%D0%B8%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D0%BD%D0%BE%D0%BC%D1%83-%D0%BF%D0%BE%D0%BB%D1%8E)
    - [Pairs](#pairs)
      - [Получение записей через pairs](#%D0%9F%D0%BE%D0%BB%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D0%B5-%D0%B7%D0%B0%D0%BF%D0%B8%D1%81%D0%B5%D0%B9-%D1%87%D0%B5%D1%80%D0%B5%D0%B7-pairs)
      - [Получение записей через pairs используя параметр use_tomap](#%D0%9F%D0%BE%D0%BB%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D0%B5-%D0%B7%D0%B0%D0%BF%D0%B8%D1%81%D0%B5%D0%B9-%D1%87%D0%B5%D1%80%D0%B5%D0%B7-pairs-%D0%B8%D1%81%D0%BF%D0%BE%D0%BB%D1%8C%D0%B7%D1%83%D1%8F-%D0%BF%D0%B0%D1%80%D0%B0%D0%BC%D0%B5%D1%82%D1%80-use_tomap)
    - [Lua Fun](#lua-fun)
      - [Filter](#filter)
      - [Reduce (foldl)](#reduce-foldl)
      - [Map](#map)
      - [Take](#take)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Ссылки на другие части документации по `read view`.
 - [Базовая информация о read view](../../read_view/read_view_info.md)
 - [Read view c CRUD](../../read_view/read_view_crud.md)

## Запуск кластера и наливка данных

### Docker

Для поднятия кластера и наливки данных выполните команду `docker compose up -d`. После завершения работы команды, будет
поднят кластер состоящий из 1 роутера и 2 репликасетов по 2 инстанса в каждом. На завершающем этапе поднятия кластера,
будет вызвана команда автобутстрапа и миграции. Миграции
создадут [тестовый space](bootstrap/migrations/source/001_create_space.lua) и
нальют [начальные данные](bootstrap/migrations/source/002_data.lua)

## Примеры работы

### Подключение

#### Подключение к роутеру

Для подключения к роутеру с ролью `crud-router` необходимо выполнить команду

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

### Примеры кода

#### Создание объекта read view

```lua
rv = crud.readview()
rv.close()
```

#### Select

Данный пример предоставляет серию интерактивных тестов, показывающих принципы работы с `Read View` с помощью
модуля `CRUD`.

`CRUD` с `read view` позволяет фильтровать кортежи по условиям. Каждое условие должно использовать имя поля или имя
индекса. Первое условие, в котором используется имя индекса, используется для итерации по `space'ам`. Если условия,
соответствующие именам индексов, отсутствуют, выполнится полное сканирование (Map-Reduce). Остальные условия
используются в
качестве дополнительных фильтров. Условие поиска для индексируемого поля должно быть размещено первым, чтобы избежать
полного сканирования. Кроме того, можно ограничить количество результатов с помощью параметра `first`. Это поможет
избежать слишком длинных выборок.

    Примечание. Если вы укажете ключ шардирования или `bucket_id` `select` будет выполнен на одном узле. В противном случае
    произойдет Map-Reduce по всем узлам.

##### Выборка через select

Получить первые 6 записей из `space` `customers`

**Пример:**

```lua
rv = crud.readview()
rv:select('customers', nil, { first = 6 })
rv.close()
```

**Вывод:**

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

##### Select с индексами

Используя индекс `age_index` получить первые 10 записей из `space` `customers`, у которых возраст больше или равен 20.

**Пример:**

```lua
rv = crud.readview()
rv:select('customers', { { '>=', 'age_index', 20 } }, { first = 10 })
rv.close()
```

**Вывод:**

```yaml
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

> Результат отсортирован по возрасту, потому-что первым условием является индекс по полю `age`. Индекс имеет
> имя `age_index`, но мы все равно можем выполнять запрос по имени поля `age`, и
> поиск будет выполняться с использованием индекса без полного сканирования (Map-Reduce). Если имена индекса и поля
> совпадают, поиск также будет осуществляться по индексу.

Эти два запроса эквивалентны, в обоих случаях поиск будет осуществляться по индексу:

```lua
rv = crud.readview()
rv:select('customers', { { '>=', 'age_index', 20 } }, { first = 10 })
rv:select('customers', { { '>=', 'age', 20 } }, { first = 10 })
rv.close()
```

##### Select с составным индексом

В примере у нас присутствует составной индекс состоящий из полей `name` и `surname`

**Пример:**

```lua
rv = crud.readview()
rv:select('customers', { { '==', 'full_name', { 'Thomas', 'Griffin' } } }, { first = 10 })
rv.close()
```

**Вывод:**

```yaml
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 13, 14925, 'Thomas', 'Griffin', 64 ]
- null
...
```

##### Select с частичным ключём

В примере у нас присутствует составной индекс состоящий из полей `name` и `surname`
К составному ключу так же позволительно использовать частичный ключ.

**Пример:**

```lua
rv = crud.readview()
rv:select('customers', { { '==', 'full_name', 'William' } }, { first = 10 })
rv.close()
```

**Вывод:**

```yaml
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

> Если указать частичный ключ не для первого параметра (например { { '==', 'full_name', {nil, 'Griffin'} }), то будет
> выполнено полное сканирование (Map-Reduce).

##### Select по не индексированному полю

Можно так же проводить выборку используя неиндексированное поле

**Пример:**

```lua
rv = crud.readview()
rv:select('customers', { { '==', 'surname', 'Wilcox' } }, { first = 10 })
rv.close()
```

**Вывод:**

```yaml
---
- metadata: [ { 'name': 'id', 'type': 'integer' }, { 'name': 'bucket_id', 'type': 'unsigned' },
  { 'name': 'name', 'type': 'string' }, { 'name': 'surname', 'type': 'string' }, { 'name': 'age',
                                                                                   'type': 'number' } ]
  rows:
    - [ 30, 29239, 'Jacob', 'Wilcox', 49 ]
- null
...
```

> В этом случае выполнится полное сканирование (Map-Reduce).

#### Pairs

С помощью `read view` `pairs` можно итерироваться по распределенному пространству.

##### Получение записей через pairs

Получить первые 4 записи в виде кортежа (tuple)

**Пример:**

```lua
rv = crud.readview()
tuples = {}
for _, tuple in rv:pairs('customers', nil, { first = 4 }) do
    table.insert(tuples, tuple)
end

tuples

rv.close()
```

**Вывод:**

```yaml
---
- - [ 1, 12477, 'Elizabeth', 'Bagnall', 12 ]
  - [ 2, 21401, 'Mary', 'Bowman', 46 ]
  - [ 3, 11804, 'David', 'Bradley', 33 ]
  - [ 4, 28161, 'William', 'Bridgens', 81 ]
...
```

##### Получение записей через pairs используя параметр use_tomap

Получить первые 4 записи в виде объектов.

**Пример:**

```lua
rv = crud.readview()
objects = {}
for _, obj in rv:pairs('customers', nil, { use_tomap = true, first = 4 }) do
    table.insert(objects, obj)
end

objects

rv.close()
```

**Вывод:**

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

#### Lua Fun

Pairs совместим с [Lua Fun](https://github.com/luafun/luafun). Некоторые примеры работы с основными функциями из
библиотеки приведены ниже.

##### Filter

Функция [filter](https://luafun.github.io/filtering.html#filtering) возвращает новый итератор, элементы которого
удовлетворяют предикату. В данном пример функция предикат возвращает те элементы, у которых значение поля возраста
делится на 2 без остатка.

**Пример:**

```lua
rv = crud.readview()
objects = {}
for _, obj in rv:pairs('customers', nil, { first = 4, use_tomap = true }):filter(function(x)
    return x.age % 2 == 0
end) do
    table.insert(objects, obj)
end

objects

rv.close()
```

**Вывод:**

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

##### Reduce (foldl)

Функция [reduce (foldl)](https://luafun.github.io/reducing.html#fun.foldl) уменьшает итератор слева направо.

**Пример:**

```lua
rv = crud.readview()
age_sum = crud.pairs('developers', nil, { use_tomap = true }):reduce(function(acc, x)
    return acc + x.age
end, 0)

age_sum

rv.close()
```

**Вывод:**

```yaml
---
- 172
...
```

##### Map

Функция [map](https://luafun.github.io/transformations.html#fun.map) возвращает новый итератор, к каждому элементу
которого была применена функция.

**Пример:**

```lua
rv = crud.readview()
objects = {}
for _, obj in rv:pairs('customers', nil, { first = 4, use_tomap = true }):map(function(x)
    return { id = x.id, name = x.name, age = x.age * 2 }
end) do
    table.insert(objects, obj)
end
rv.close()
```

**Содержимое переменной objects:**

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

##### Take

Функция [take](https://luafun.github.io/slicing.html#fun.take) возвращает итератор с заданным кол-ом
последовательностей.

**Пример:**

```lua
rv = crud.readview()
tuples = {}
for _, tuple in rv:pairs('customers', { { '>=', 'age', 25 } }):take(2) do
    table.insert(tuples, tuple)
end
rv.close()
```

**Содержимое переменной tuples:**

```yaml
---
- - [ 6, 13064, 'William', 'Long', 25 ]
  - [ 23, 28454, 'Mia', 'Morrison', 25 ]
...
```
