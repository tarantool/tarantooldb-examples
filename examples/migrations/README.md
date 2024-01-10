# Пример эволюции схемы

В данном примере будет показано как разрабатывать типовое приложение на ``TarantoolDB``, а именно:
- как реализовывать ``API`` для доступа к данным
- как менять схему данных через модуль [migration](https://github.com/tarantool/migrations)
- как использовать модули [crud](https://github.com/tarantool/crud) и [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/)
- как использовать персистентные функции для доступа к данным

Для этого примера понадобятся:
* Docker-образ TarantoolDB ([установить](../../INSTALL.md))
* Docker compose
* Tarantool CLI ([установить](https://www.tarantool.io/en/doc/latest/reference/tooling/tt_cli/installation/))

## Описание задачи

В качестве примера мы будем реализовывать систему управления проектами. Будет 3 спейса: **projects**, **tasks**, **users**.

Изначально схема данных будет такой:

![Cхема данных](./images/schema1.drawio.svg)

Связанные спейсы Projects и Tasks будут иметь одинаковый ключ шардирования `project_id` и находиться на одном инстансе, 
а спейс `users` будет иметь ключ шардирования `user_id`. Сделано так из
следующих предположений:
- задач на проекте будет больше, чем пользователей
- при удалении проекта, необходимо удалить и задачи, связанные с ним, а это удобно сделать, если
  все записи находятся на одном узле

> **Важно**
> 
> При выборе ключа шардирования необходимо учитывать предметную область и предполагаемое API

Для взаимодействия с данными будем использовать методы `crud`.
Дополнительно реализуем следующее API:

- `app.delete_user(user_id)` - удалить пользователя, при этом у всех задач, связанных с этим пользователем, в поле `assigned_user_id` должен быть выставлен `box.NULL`.
- ``app.delete_project(project_id)`` - удалить проект и все связанные с ним задачи.
- ``app.get_project_data(project_id)`` - получить проект и все связанные с ним задачи и пользователей.

## Первая миграция

Код можно посмотреть [здесь](./bootstrap/migrations/source/001_test.lua). 

Для успешного запуска должны быть свободны порты:
* 3300 .. 3304
* 8080 .. 8084

Выполните следующие команды:
``` shell
cd ./docs/examples/migrations/
docker compose up -d
```

В результате будет запущен кластер TarantoolDB и в нём будут созданы спейсы **projects**, **tasks**, **users** и 
функции ``app.delete_user(user_id)``, ``app.get_project_data(project_id)``.

Загрузим тестовые данные. Для этого в [миграции](./bootstrap/migrations/source/001_test.lua) была создана функция `__create_example_data`. Она очищает кластер и заново его заполняет данными из примера.

Подключаемся к роутеру:

``` shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Загружаем данные:

```lua
localhost:3300> box.schema.func.call('__create_example_data')
```

Выполним базовые операции через модуль CRUD.

```lua
localhost:3300> crud.select('users')
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
  rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'john_doe', 'john.doe@example.com']
  - [1e63739a-dad0-4c5d-80e4-cd39594fe302, 1985, 'jane_smith', 'jane.smith@example.com']
- null
...

localhost:3300> crud.select('users', {{"==", "name", "john_doe"}})
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
  rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'john_doe', 'john.doe@example.com']
- null

localhost:3300> crud.update('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'), {{'=', 'name', "John Doe"}})
---
- rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'John Doe', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null

localhost:3300> crud.get('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'John Doe', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null

localhost:3300> crud.delete('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'John Doe', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...
```

Чтобы вернуть данные в прежнее состояние выполняем повторно:

```lua
localhost:3300> box.schema.func.call('__create_example_data')
```


Модуль [CRUD](https://github.com/tarantool/crud) значительно упрощает работу с шардированными данными и позволяет легко выполнять простые операции чтения/записи к таким данным прозрачно для пользователя. Для реализации более сложной логики, модуль предоставляет дополнительные команды, такие как `pairs`.
Для задач, которые реализуют  ``app.get_project_data(id)``, ``app.delete_user(id)``, ``app.delete_project(id)`` модуля CRUD недостаточно т.к. они предполагают работу с несколькими спейсами и нестандрантые операции чтения/записи.

### ``app.get_project_data(project_id)``
Для тестирования этой команды вернём данные в первоначальное состояние:
```lua
localhost:3300> box.schema.func.call('__create_example_data')
```

Выполним команду и оценим результат:
```lua
localhost:3300> box.schema.func.call('app.get_project_data', require('uuid').fromstr('46f8e628-d2c2-42ba-984f-29a459a3d0fc'))
---
- res:
    tasks:
    - status: In Progress
      user:
        name: john_doe
        email: john.doe@example.com
      name: Optimize Database
      description: Optimize the database to improve performance.
    name: Task Management
    description: Development of a task management system
  err: null
```

``app.get_project_data(project_id)`` выполняет ``join`` из всех спейсов, используются ``crud.get``, ``crud.pairs``.

Подробнее ознакомиться с описанием логики можно в [файле](./bootstrap/migrations/source/001_test.lua).

### ``app.delete_user(user_id)``

Рассмотрим теперь ``app.delete_user(id)``

Необходимо удалить пользователя, а во всех задачах связанных с ним присвоить полю `assigned_user_id` значение box.NULL.

```lua
localhost:3300> box.schema.func.call('__create_example_data')
```

Пример выполнения:
```lua
localhost:3300> box.schema.func.call('app.delete_user', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- res: true
  err: null
...

localhost:3300> box.schema.func.call('app.get_project_data', require('uuid').fromstr('46f8e628-d2c2-42ba-984f-29a459a3d0fc'))
---
- res:
    tasks:
    - status: In Progress
      name: Optimize Database
      description: Optimize the database to improve performance.
    name: Task Management
    description: Development of a task management system
  err: null

localhost:3300> crud.get('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- rows: []
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...
```

Видим, что информации о пользователе нет, мы его успешно удалили.

Для того, чтобы  присвоить полю `assigned_user_id` значение `box.NULL `на всех стораджах была объявлена функция ``tasks.set_box_NULL_for_user_id``. Она выставялет `box.NULL` в поле `assigned_user_id` для всех задач, у которых `assigned_user_id == user_id`, где
`user_id` аргумент функции.

Ее код выглядит так:
```lua
function(user_id)
  local fiber = require('fiber')
  local every_100 = 0
  for _, t in box.space.tasks.index.assigned_user_id:pairs({user_id}, 'EQ') do
      box.space.tasks:update(t.id, {{'=', 'assigned_user_id', box.NULL}})
      every_100 = every_100 + 1
      if every_100 == 100 then
          every_100 = 0
          fiber.yield() -- выполняем fiber.yield(), чтобы не занимать полностью TX тред в случае, когда задач у пользователя очень много
      end
  end
  return true
end
```

Особенностью ``app.delete_user(id)`` является то, что ``tasks`` и ``users`` шардируются по разным ключам и в общем случае
связанные задачи и пользователи будут находиться на разных шардах. Это значит, что нет узла, на котором бы было известно
на каких шардах будут находиться задачи, связанные с удаляемым пользователем. В общем случае такие задачи будут на всех 
шардах. Поэтому необходимо вызывать ``tasks.set_box_NULL_for_user_id`` на каждом мастере шарда. Для вызова функции на 
всех шардах используется модуль для горизонтального масштабирования [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/).

Блок кода, где происходит вызов функции `tasks.set_box_NULL_for_user_id`:

```lua
local _, err, uuid = vshard_router.map_callrw('tasks.set_box_NULL_for_user_id', {user_id})
```

Подробнее ознакомиться с описанием логики можно в [файле миграции](./bootstrap/migrations/source/001_test.lua)

### ``app.delete_project(project_id)``

Перейдем к ``app.delete_project(project_id)``.

```lua
localhost:3300> box.schema.func.call('__create_example_data')
```

```lua
localhost:3300> crud.select('projects')
---
- metadata: [{'name': 'id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}]
  rows:
  - [46f8e628-d2c2-42ba-984f-29a459a3d0fc, 1033, 'Task Management', 'Development of
      a task management system']
  - [f53392af-30e3-4bfc-bde8-37043951159a, 21589, 'Website Update', 'Making changes
      to the website design and functionality']
- null

localhost:3300> crud.select('tasks')
---
- metadata: [{'name': 'task_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}, {'name': 'status', 'type': 'string'}, {'name': 'project_id',
      'type': 'uuid'}, {'type': 'uuid', 'name': 'assigned_user_id', 'is_nullable': true}]
  rows:
  - [5043a3f6-6ffa-4d90-8b66-4fb623878f8e, 1033, 'Optimize Database', 'Optimize the
      database to improve performance.', 'In Progress', 46f8e628-d2c2-42ba-984f-29a459a3d0fc,
    04e7f6a2-2979-46e4-8d71-e80217e3aac3]
  - [c57d56ef-33fc-453b-880f-5d3ba4dc9d10, 21589, 'Create New Logo', 'Design a new
      logo for the website.', 'Not Started', f53392af-30e3-4bfc-bde8-37043951159a,
    1e63739a-dad0-4c5d-80e4-cd39594fe302]
- null

localhost:3300> box.schema.func.call('app.delete_project', require('uuid').fromstr('f53392af-30e3-4bfc-bde8-37043951159a'))
---
- res: true
  err: null
...

localhost:3300> crud.select('projects')
---
- metadata: [{'name': 'project_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}]
  rows:
  - [46f8e628-d2c2-42ba-984f-29a459a3d0fc, 1033, 'Task Management', 'Development of
      a task management system']
- null

localhost:3300> crud.select('tasks')
---
- metadata: [{'name': 'task_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}, {'name': 'status', 'type': 'string'}, {'name': 'project_id',
      'type': 'uuid'}, {'type': 'uuid', 'name': 'assigned_user_id', 'is_nullable': true}]
  rows:
  - [5043a3f6-6ffa-4d90-8b66-4fb623878f8e, 1033, 'Optimize Database', 'Optimize the
      database to improve performance.', 'In Progress', 46f8e628-d2c2-42ba-984f-29a459a3d0fc,
    04e7f6a2-2979-46e4-8d71-e80217e3aac3]
- null
...
```

Видим, что проект 'Website Update' был удален вместе со всеми задачи.

Осбенностью спейсов **projects** и **tasks** является то, что они шардируются по одинаковым значениям. Т.е. связанные между собой 
проект и задача будут находиться на одном инстансте. Это позволяет **транзакционно** удалить данные и из **projects** и из **tasks**.
Для этого на стораджах реализована API-функция ``'projects.delete_project``.

Ее код:

```lua
function(project_id)
    local proj = box.space.projects:get(project_id)
    if proj == nil then
        return false
    end

    box.atomic(function() -- атомарно удаляем и из projects и из tasks
        box.space.projects:delete(project_id)

        for _, t in box.space.tasks.index.project_id:pairs({project_id}, 'EQ') do
            box.space.tasks:delete(t.id)
        end
    end)
    return true
end
```

Для вызова функции на конкретном мастере используем модуль ``vshard``. Блок кода вызова функции
`projects.delete_project`:

```lua
local vshard_router = require('vshard.router')
local bucket_id = vshard_router.bucket_id_strcrc32(id)
local _, err = vshard_router.callrw(bucket_id, 'projects.delete_project', {id})
```

Подробнее ознакомиться с описанием логики можно в [файле миграции](./bootstrap/migrations/source/001_test.lua).

## Изменение схемы данных

Предположим, что у нас обновились требования и необходимо добавить поле **deadline(datetime)** в ``projects``, поле **due_date(datetime)** в ``tasks`` и поле
**role(string)** в ``users``. По умолчанию необходимо, чтобы в ``projects.deadline`` и в ``due_date(datetime)`` был "2999-12-31T00:00:00Z", а в 
``users.role`` было ``not set``.

``app.get_project_data`` нужно также переписать, чтобы отображались новые поля.

![Cхема данных](./images/schema2.drawio.svg)

Код миграции в файле [002_test.lua](./002_test.lua).

Миграции выполняются в лексигорафическом порядке, поэтому рекомендуется давать им нумерованные названия ("0001_my_migr.lua", "2023_12_24_migr.lua").

Подготовим данные:
```lua
localhost:3300> box.schema.func.call('__create_example_data')
```

Как выполнить миграцию:

Есть два способа, через http-api или через админку (web-ui).

### Через web-ui

1. Открываем вкладку [Code](http://localhost:8081/admin/cluster/code) на левой панели админки
2. Добавляем в ``migrations/source`` файл ``002_test.lua``
3. Копируем [данные](./002_test.lua) в этот файл
4. Жмем кнопку ``apply``
5. Конфиг должен успешно примениться.

### Через graphql-api
```bash
curl -v --raw 'http://localhost:8081/admin/api' -X POST --data '{
        "query":"mutation($sections: [ConfigSectionInput!]) {
            cluster {
                config(sections: $sections) {
                    filename
                    content
                }
            }
        }",
        "variables": {
            "sections": [{
                "filename":"migrations/source/002_test.lua",
                "content":"'"$(cat 002_test.lua | sed 's/"/\\"/g' )"'"
            }]
        }
}'
```

Теперь нужно выполнить старт миграции, в консоли выполняем ``curl -X POST localhost:8081/migrations/up`` и дожидаемся ответа ``{"applied":["002_test.lua"]}``

Проверим успешность миграции:

```lua
localhost:3300> crud.select('projects')
---
- metadata: [{'name': 'project_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}, {'type': 'datetime', 'name': 'deadline', 'is_nullable': true}]
  rows:
  - [46f8e628-d2c2-42ba-984f-29a459a3d0fc, 1033, 'Task Management', 'Development of
      a task management system', '2999-12-31T00:00:00Z']
  - [f53392af-30e3-4bfc-bde8-37043951159a, 21589, 'Website Update', 'Making changes
      to the website design and functionality', '2999-12-31T00:00:00Z']
- null
...

localhost:3300> crud.select('tasks')
---
- metadata: [{'name': 'task_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}, {'name': 'status', 'type': 'string'}, {'name': 'project_id',
      'type': 'uuid'}, {'type': 'uuid', 'name': 'assigned_user_id', 'is_nullable': true},
    {'type': 'datetime', 'name': 'due_date', 'is_nullable': true}]
  rows:
  - [5043a3f6-6ffa-4d90-8b66-4fb623878f8e, 1033, 'Optimize Database', 'Optimize the
      database to improve performance.', 'In Progress', 46f8e628-d2c2-42ba-984f-29a459a3d0fc,
    04e7f6a2-2979-46e4-8d71-e80217e3aac3, '2999-12-31T00:00:00Z']
  - [c57d56ef-33fc-453b-880f-5d3ba4dc9d10, 21589, 'Create New Logo', 'Design a new
      logo for the website.', 'Not Started', f53392af-30e3-4bfc-bde8-37043951159a,
    1e63739a-dad0-4c5d-80e4-cd39594fe302, '2999-12-31T00:00:00Z']
- null
...

localhost:3300> crud.select('users')
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true},
    {'type': 'string', 'name': 'role', 'is_nullable': true}]
  rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'john_doe', 'john.doe@example.com',
    'not set']
  - [1e63739a-dad0-4c5d-80e4-cd39594fe302, 1985, 'jane_smith', 'jane.smith@example.com',
    'not set']
- null
...
```

Видим, что новые поля добавлены и значения по умолчанию проставлены.

Проверим функцию ``app.get_project_data`` на присутствие новых полей в ответе:

```lua
localhost:3300> box.schema.func.call('app.get_project_data', require('uuid').fromstr('46f8e628-d2c2-42ba-984f-29a459a3d0fc'))
---
- res:
    tasks:
    - due_date: 2999-12-31T00:00:00Z
      status: In Progress
      user:
        email: john.doe@example.com
        name: john_doe
        role: not set
      name: Optimize Database
      description: Optimize the database to improve performance.
    deadline: 2999-12-31T00:00:00Z
    name: Task Management
    description: Development of a task management system
  err: null
...
```

Стоит отметить способ изменения функции ``app.get_project_data``:

```lua
 box.atomic(function()
    box.schema.func.drop('app.get_project_data') -- удаляем старый вариант
    box.schema.func.create('app.get_project_data',  {
      language = 'LUA',
        if_not_exists = true,
        body = [[ ... ]]
    }) -- добавляем новый вариант
end)
```

Транзакционно удаляем старый вариант и добавляем новый. Таким образом гарантируется, что не будет ситуации когда функции ``app.get_project_data`` не существует. (Подробнее узнать о том, как хранятся персистентные функции можно в спейсе ``box.space._func``)
