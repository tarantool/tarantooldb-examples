# Пример миграции с использованием space:upgrade 

В примере будет показана миграция данных в ``Tarantool DB`` с использованием метода `space:upgrade`.
Для более глубокого понимания, рекомендуется ознакомиться с более общим [примером по разработке приложений на Tarantool DB.](../migrations/README.md).

Для примера понадобятся:
* Docker-образ Tarantool DB ([установить](../../INSTALL.md))
* docker-compose
* [TT CLI](../../../README.md#интерфейс-командной-строки-%28cli%29)

## Описание задачи

Изначально схема данных будет такой:

![Cхема_данных](./images/schema1.drawio.svg)

Далее необходимо будет внести следующие изменения:

![Cхема данных 2](./images/schema2.drawio.svg)

1. Добавить поле `assigned_manager_id` в `projects`
2. Изменить тип поля `status` в `tasks` со `string` на `number`
3. Добавить поле `due_date(datetime)` в `tasks`
4. Изменить название поля `email` на `contact` в `users`
5. Добавить поле `role` в спейс `users`

Особенностью `space:upgrade` является то, что можно вносить несовместимые изменения в формат (изменения названия поля, удаления поля и т.д.). **Запрещено менять только поля, используемые для индексации.**

## Подготовка кластера

Выполните `docker compose up --force-recreate`.

В результате поднимется кластер с такой схемой данных. ![схемой данных](./images/schema1.drawio.svg)

Далее наполним кластер данными.

Подключимся к роутеру.
```bash
tt connect admin:secret-cluster-cookie@localhost:3300
```

Вызовем процедуру для наполнения кластера данными.
```lua
box.schema.func.call('__fill_data')
```

Необходимо дождаться конца процедуры, это может занять до трех минут. В результате на каждом стордаже должно быть занято по 164MB данных. 

Можно следить за прогрессом заполнения по логам:

```bash
space_upgrade-tarantool-router-1    | 2024-02-26 05:46:50.947 [12] main/189/main/tarantool I> start to fill_data
space_upgrade-tarantool-router-1    | 2024-02-26 05:46:50.947 [12] main/189/main/tarantool I> send batch 1
...
space_upgrade-tarantool-router-1    | 2024-02-26 05:49:01.559 [12] main/189/main/tarantool I> send batch 700
space_upgrade-tarantool-router-1    | 2024-02-26 05:49:01.795 [12] main/189/main/tarantool I> data filled
```

# Описание кода миграций

Код миграции находися в файле [002_test.lua](./002_test.lua).

Сперва кратко рассмотрим метод `space:upgrade`.

`space:upgrade` принимает следующие аргументы:
- `format` - новый формат спейса. Он может конфликтовать с предыдущим, но инексируемые поля должны быть неизменными.
    Данные, записываемые в спейс, во время миграции должны удовлетвовать новому формату.
- `func` - название функции для выполнения миграций
    Функция должна быть персистенстной. Она принимает исходный tuple и возвращает отмигрированный.
    Также функция должны быть идемпотентной т.к. при чтении данных из спейса в ходе `space:upgrade`, к получаемому `tuple` применяется функция `func`, а из этого следует, что `func` может быть применена к `tuple` несколько раз. Если `func` будет неидомпотентной можно получить некорретные данные или ошибку во время миграции.
- `mode` - режим работы `space:upgrade`. Есть три режима работы `dryrun`, `upgrade`, `dryrun+upgrade`.
    - В режиме `dryrun` происходит проверка корректности миграции функция `func` выполняется на каждом `tuple`, но данные не
    изменяются.
    - В режиме `upgrade` уже выполняется обновление данных.
    - В режиме `dryrun+upgrade` сначала запускается `dryrun`, а если ошибок нет, то далее запускается `upgrade`.
- `is_async` - флаг неблокируемого выполнения `space:upgrade`.

`space:upgrade` возвращает объект `future`. По нему можно узнать статус миграции (`future:info`), отменить миграцию (`future:cancel`), или дождаться конца миграции (`future:wait`).

Более подробную информацию о методе `space:upgrade` можно узнать из [документации](https://github.com/tarantool/doc/blob/47b938004e5cadbdf24d30d7a818d928560ee623/doc/enterprise/space_upgrade.rst).

Далее перейдем непосредственно к коду миграции.

### Спейс projects
В спейсе `projects` необходимо добавить поле `assigned_manager_id` между полями `name` и `description`. 
При работе с `tuple` удобно использовать встроенную библиотеку [`box.tuple`](https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_tuple/). Она активно будет использоваться в дальнейшем.

```lua
-- задаем функцию для преобразования tuple-ов
box.schema.func.create('__migrator_projects_002', { -- рекомендуется давать функции название с номером миграции
    language = 'lua', -- указываем, что функция на Lua
    is_deterministic = true, -- указываем, что функция детерминированна
    body = [[
        function(t)
            -- т.к. добавляется новое поле, то колическо полей в tuple увеличится
            -- данная проверка делает функцию __migrator_projects_002 идемпотетнтной
            -- без этой проверки возможна была бы ситуация, когда в tuple было бы шесть или более полей
            if #t == 4 then
                -- добавляем новое поле на 4-ю позицию в tuple, между 3-им и 4-ым полем
                -- т.е. между полями `name` и `description`
                -- в качестве значения добавляем box.NULL
                -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_tuple/update/
                return t:update({{'!', 4, box.NULL}}) 
            end
            -- в случае, если `tuple` уже отмигрирован возвращаем его же
            return t
        end
    ]]
})

-- projects_migration это future с помощью которого можно отслеживать прогресс миграции
local projects_migration = box.space.projects:upgrade({
    -- название функции
    func = '__migrator_projects_002',
    -- новый формат с новыми поле assigned_manager_id
    format = {
        { name = 'project_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'assigned_manager_id', type = 'uuid', is_nullable = true },
        { name = 'description', type = 'string', is_nullable = true },
    },
    -- режим работы
    mode = 'dryrun+upgrade',
    -- вызов будет неблокирующим
    is_async = true,
})

-- сохраняем projects_migration в глобальную переменную, чтобы иметь к ней доступ из консоли tt
rawset(_G, '__projects_migration', projects_migration)
```

### Спейс tasks

В спейс `tasks` необходимо изменить тип поля `status` с `number` на `string`, а также добавить в конец поле `due_date(datetime)`.

```lua
box.schema.func.create('__migrator_tasks_002', {
    language = 'lua',
    is_deterministic = true,
    body = [[
        function(t)
            -- задаем дату по умолчанию для due_date
            local datetime = require('datetime')
            local due_date = datetime.new({year=2999, month=12, day=31})
            -- проверяем, что полей 7. Если их 7, это означает, что поле due_date добавлено не было
            if #t == 7 then
                -- для смены типа поля необходимо, его удалить и добавить новое
                -- функция `tuple:transform` подходит для этого.
                -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_tuple/transform/
                -- t:transform(5, 1, 0) удалит одно поле начиная с пятого(status) и добавит вместо него число 0
                -- update({{"!", 8, due_date}}) добавит поле в 8-ю позицию, т.е. в конец и присвоит полю значение due_date
                return t:transform(5, 1, 0):update({{"!", 8, due_date}})
            end
            return t
        end
    ]],
})

local tasks_migration = box.space.tasks:upgrade({
    func = '__migrator_tasks_002',
    format = {
        { name = 'task_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'description', type = 'string', is_nullable = true },
        -- изменили тип поля status
        { name = 'status', type = 'number' },
        { name = 'project_id', type = 'uuid' },
        { name = 'assigned_user_id', type = 'uuid', is_nullable = true },
        -- добавили новое поле due_date
        { name = 'due_date', type = 'datetime' },
    },
    mode = 'dryrun+upgrade',
    is_async = true,
})

rawset(_G, '__tasks_migration', tasks_migration)
```

### Спейс users

В спейсе `users` необходимо изменить название поля `email` на `contact`, а также добавить новое поле `role`.

```lua
box.schema.func.create('__migrator_users_002',  {
    language = 'lua',
    is_deterministic = true,
    body = [[
        function(t)
            -- проверяем, что поле `role` еще не добавлено
            if #t == 4 then
                -- добавлем новое поле на 4-ю позицию, между `name` и `contact`
                return t:update({{'!', 4, 'not set'}})
            end
            return t
        end
    ]],
})

local users_migration = box.space.users:upgrade({
    func = '__migrator_users_002',
    format = {
        { name = 'user_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        -- новое поле `role`
        { name = 'role', type = 'string' },
        -- изменяем название поля на `contact`
        { name = 'contact', type = 'string' },
    },
    mode = 'dryrun+upgrade',
    is_async = true,
})
rawset(_G, '__users_migration', users_migration)
```

## Применение миграций

Загрузим файл с миграцией в конфиг кластера. 

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

Подробнее о том как можно загрузить миграцию в конфиг описано в [примере по разработке приложений на Tarantool DB](../migrations/README.md).

Теперь нужно выполнить старт миграции, в консоли выполняем ``curl -X POST localhost:8081/migrations/up`` и дожидаемся ответа ``{"applied":["002_test.lua"]}``.

Далее подключимся к стораджу:

```
tt connect admin:secret-cluster-cookie@localhost:3301
```

Статус миграций спейсов можно посмотреть через глобальные переменные, задаваемые в миграции.

```lua
localhost:3301> __projects_migration
- owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_projects_002
  progress: 74%
  status: inprogress
  dryrun: true
localhost:3301> __tasks_migration
- status: inprogress
  progress: 1%
  owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_tasks_002
localhost:3301> __users_migration
- status: inprogress
  progress: 32%
  owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_users_002
...
```

Вначале `space:upgrade` выполняется в `dryrun` режиме и не меняет данные, если ошибок на этом этапе не будет, то далее начнется уже `upgrade` с изменением данных.

Понять выполняется `upgrade` или `dryrun` можно по флагу `dryrun: true`.

```lua
localhost:3301> __projects_migration
- owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_projects_002
  progress: 74%
  status: inprogress
  dryrun: true
```

Особенностью `space:upgrade` является то, что запросы на чтение данных из мигрируемых спейсов будут отдавать данные в нужном виде.

Можно проверить данный факт выполнив код ниже в ходе миграций, когда в `__projects_migration`, `__tasks_migration`, `__users_migration` уже не стоит флаг `dryrun: true`. 

```lua
localhost:3301> box.space.users:pairs({require('uuid').new()}, 'GE'):take_n(2):map(function(t) return t:tomap({names_only=true}) end):totable()
---
- - bucket_id: 12192
    contact: john.doe863@example.com
    role: not set
    user_id: f62c5c9a-b739-4a7d-97b9-5798281eff38
    name: john_doe 863
  - bucket_id: 11368
    contact: john.doe854@example.com
    role: not set
    user_id: f62cc684-fb92-4f7a-a6d4-132d20803bb9
    name: john_doe 854
localhost:3301> box.space.projects:pairs({require('uuid').new()}, 'GE'):take_n(2):map(function(t) return t:tomap({names_only=true}) end):totable()
---
- - bucket_id: 12580
    project_id: 45c5ee48-c725-440c-9310-fd014b6ff672
    assigned_manager_id: null
    name: Task Management 74
    description: Development of a task management system 74
  - bucket_id: 13977
    project_id: 45c62b29-49a3-4170-87f5-a5f149b00722
    assigned_manager_id: null
    name: Task Management 652
    description: Development of a task management system 652
localhost:3301> box.space.tasks:pairs({require('uuid').new()}, 'GE'):take_n(2):map(function(t) return t:tomap({names_only=true}) end):totable()
---
- - bucket_id: 9071
    project_id: f267b29a-413e-4b84-bc23-35a6b6ff101c
    task_id: 5c0c561c-3c17-4bcf-b2c2-6918708d2213
    assigned_user_id: c12d08a0-7527-45fd-8493-bf8fc2a1b50b
    status: 0
    due_date: 2999-12-31T00:00:00Z
    name: Create New Logo
    description: Design a new logo for the website.
  - bucket_id: 4293
    project_id: 9e165c07-c6e5-4495-a66e-6e70a99a3ce1
    task_id: 5c0c5e39-cbc4-40d7-8c64-435a6a19f3ed
    assigned_user_id: 3517d823-1879-497a-8005-ac4c16d94f5b
    status: 0
    due_date: 2999-12-31T00:00:00Z
    name: Create New Logo
    description: Design a new logo for the website.
```lua

По завершении миграций будет так:

```lua
localhost:3301> __projects_migration
---
- status: done
...

localhost:3301> __tasks_migration
---
- status: done
...

localhost:3301> __users_migration
---
- status: done
...
```

В логах конец миграции данных будет выглядеть так:

```bash
space_upgrade-tarantool-storage3-1  | 2024-02-26 09:13:43.048 [12] main/172/space_upgrade_516 I> space upgrade completed
space_upgrade-tarantool-storage3-1  | 2024-02-26 09:13:43.133 [12] main/173/space_upgrade_513 I> space upgrade completed
space_upgrade-tarantool-storage3-1  | 2024-02-26 09:13:43.163 [12] main/174/space_upgrade_515 I> space upgrade completed
```

Убедиться в выполнении миграций и изменении формата можно через [space-explorer](http://localhost:8081/admin/space-explorer/hosts).

`space:upgrade` предоставляет большие возможности по миграции данных и позволяет выполнять конфликтующие с текущим форматом спейса мирации данных.

Выключаем кластер `docker compose down`