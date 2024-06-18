# Фильтрация и итерация в read view с помощью CRUD

В этом разделе приведены подробные примеры использования операций `select` и `pairs` для read view с помощью
модуля [CRUD](https://github.com/tarantool/crud).

Содержание:

* [](user_guide-readview_crud_filter-prereq)
* [](user_guide-readview_crud_filter-start_example)
* [](user_guide-readview_crud_filter-migrations)
* [](user_guide-readview_crud-filter-create)
* [](user_guide-readview_crud-filter-select)
* [](user_guide-readview_crud-filter-pairs)
* [](user_guide-readview_crud-filter-stop_example)

(user_guide-readview_crud_filter-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* утилита [TT CLI](install-install_tt);
* исходные файлы примера `read_view`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `read_view` расположен в таком архиве в директории `./doc/examples/read_view/`.
    
  * Отдельный архив [read_view.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/read_view/read_view.tar.gz), скачанный c сайта Tarantool.
  ```
  
(user_guide-readview_crud_filter-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `read_view`:

* `config.yml` -- конфигурация и топология кластера;
* `docker-compose.yml` -- описание узлов кластера;
* `migrations/scenario` -- директория, содержащая файлы с описанием миграций;
* `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

(user_guide-readview_crud_filter-start_example)=
## Запуск стенда


Для успешного запуска должны быть свободны порты:
* 3301-3306;
* 8081;
* 2379;

Перейдите в директорию примера `read_view`:

```
cd ./doc/examples/read_view/
```

Запустите стенд через docker compose:

```shell
docker compose up -d
```

Команда развернет стенд, состоящий из:
* кластера Tarantool DB (1 роутер, 4 хранилища, 1 TCM);
* клиентского приложения, подающего нагрузку.

После запуска должны работать все контейнеры. Также после запуска становится доступен пользовательский интерфейс http://localhost:8081 -- веб-интерфейс кластера Tarantool DB (TCM).

Получите пароль для входа в веб-интерфейс Tarantool DB (TCM):
```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте веб-интерфейс в браузере по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

Чтобы настроить кластер:

1. В веб-интерфейсе перейдите на вкладку **Cluster**.
2. В строке с кластером `Default cluster` нажмите кнопку **...** (**Actions**) справа и выберите **Edit** в выпадающем меню.
3. Переключитесь на второй экран настройки, используя кнопку **Next**.
4. На втором экране укажите в поле **Prefix** значение `/tdb` и нажмите  **Next**.
5. На третьем экране укажите следующие значения:
   - в поле **Username** -- `admin`;
   - в поле **Password** --  `secret-cluster-cookie`.
   
6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**.
8. Выберите любой роутер из списка (например, `router-1`) и в открывшемся окне перейдите на вкладку **Terminal**.
9. В терминале введите команду `box.space`. В выводе должен присутствовать спейс `customers`.
10. Перейдите на вкладку `Tuples`. В ней должен присутствовать созданный спейс, а внутри должны быть данные.

(user_guide-readview_crud_filter-migrations)=
## Создание спейса и подключение к узлу

На завершающем этапе поднятия кластера выполняется публикация YAML-конфигурации кластера в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/reference/tooling/tt_cli/cluster/#tt-cluster-publish)
и применяются [миграции](../migrations/migrations_space_format.md).
Миграции создают спейс `customers` (файл `./migrations/scenario/001_create_space.lua`) и
загружают в него данные (файл `./migrations/scenario/002_data.lua`).

Спейс имеет следующий формат:

```{literalinclude} bootstrap/migrations/scenario/001_create_space.lua
:start-after: -- Создание спейса customers
:end-before: utils.register_sharding_key
:language: lua
:dedent:
```

Подключитесь к роутеру с ролью [crud-router](reference-roles-crud), используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

(user_guide-readview_crud-filter-create)=
## Создание представления для чтения

Чтобы создать read view, вызовите функцию `crud.readview()`:

```lua
rv = crud.readview()
```

(user_guide-readview_crud-filter-select)=
## Фильтрация кортежей с помощью select

Метод `read_view_object:select()` позволяет фильтровать кортежи по условиям.
Каждое условие должно использовать имя поля или имя индекса.
Первое условие с именем индекса используется для итерации по спейсам.
Если условия с именами индексов отсутствуют, выполняется полное сканирование (Map-Reduce).
Остальные условия используются в качестве дополнительных фильтров.
Условие поиска для индексируемого поля должно быть размещено первым, чтобы избежать
полного сканирования.
Чтобы избежать длинных выборок, можно ограничить количество результатов с помощью параметра `first`.

```{admonition} Примечание
:class: note

Если вы укажете ключ шардирования или `bucket_id`, операция `select` будет выполнена на одном узле.
В противном случае произойдет Map-Reduce по всем узлам.
```

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
Так как первое условие -- индекс `age_index`, результат отсортирован по возрасту.

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

```{admonition} Примечание
:class: note

Если указать частичный ключ не для первого параметра -- например, ``{ '==', 'full_name', {nil, 'Griffin'}``, то будет
выполнено полное сканирование (Map-Reduce).
```

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

(user_guide-readview_crud-filter-pairs)=
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
age_sum = crud.pairs('developers', nil, { use_tomap = true }):reduce(function(acc, x)
    return acc + x.age
end, 0)

age_sum
```

Вывод выглядит так:

```yaml
---
- 172
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


(user_guide-readview_crud-filter-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
