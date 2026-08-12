# Миграция данных с помощью space:upgrade()

В этом руководстве описана миграция данных в Tarantool DB с помощью метода [space:upgrade()](https://www.tarantool.io/ru/doc/latest/platform/ddl_dml/migrations/space_upgrade/).
`space:upgrade()` позволяет вносить несовместимые изменения в формат спейса, например изменить название спейса или удалить его.

> [!NOTE]
> **Ограничения**
>
> Поля, которые используются для индексации, изменять нельзя.

Подробнее о миграции можно прочитать в разделе [Миграция данных](https://www.tarantool.io/docs/tdb/ru/2_x/user_guide/migrations).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Схема данных](#схема-данных)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Загрузка данных](#загрузка-данных)
* [Метод space:upgrade()](#метод-spaceupgrade)
* [Определение кода миграций](#определение-кода-миграций)
* [Запуск миграции](#запуск-миграции)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install_tt);
* исходные файлы примера `space_upgrade`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `space_upgrade` расположен в директории `examples/space_upgrade`.
>  * Отдельный архив [space_upgrade.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Fspace_upgrade&filename=space_upgrade), скачанный из этого репозитория.

## Схема данных

В примере используется база данных для системы управления проектами, которая состоит из трех спейсов: `projects` (проекты), `tasks` (задачи),
`users` (пользователи). Изначально схема этой базы данных выглядит так:

![Схема данных](images/schema1.drawio.svg)

После прохождения руководства схема данных будет изменена следующим образом:

* добавлено поле `assigned_manager_id` в спейс `projects`;
* изменен тип поля `status` в спейсе `tasks` со `string` на `number`;
* добавлено поле `due_date(datetime)` в спейс `tasks`;
* изменено название поля `email` на `contact` в спейсе `users`;
* добавлено поле `role` в спейс `users`.

После изменений схема данных будет выглядеть так:

![Схема данных 2](images/schema2.drawio.svg)

## Используемые файлы

В руководстве используются следующие файлы примера `space_upgrade`:

- `cluster/` — директория c файлами для запуска кластера Tarantool DB:
  - `config.yml` — конфигурация и топология кластера;
  - `docker-compose.yml` — описание узлов кластера Tarantool DB;
  - `migrations/scenario/` и `migration_next/` — директории, содержащие файлы с описанием миграций;
- `tools/` — директория с файлами для запуска кластера etcd и TCM:
  - `docker-compose.yml` — описание узлов кластера etcd;
  - `tcm.yml` — конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301—3304
* 8081

Перейдите в директорию примера `space_upgrade`:

```shell
cd examples/space_upgrade
```

Запустите стенд:

```shell
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `storage-1` узел `storage-1-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** введите следующую команду:

```lua
box.space
```

Проверьте, что в выводе есть спейсы `projects`, `tasks` и `users` — эти спейсы создаются при запуске кластера.

## Загрузка данных

Исходный код миграции приведен в файле `001_test.lua` в директории `./cluster/migrations/scenario/` примера `space_upgrade`.

Загрузить тестовые данные в спейсы можно с помощью утилиты tt CLI:

```shell
tt crud import \
    admin:secret-cluster-cookie@localhost:3301 \
    projects.csv:projects --header
tt crud import \
    admin:secret-cluster-cookie@localhost:3301 \
    tasks.csv:tasks --header
tt crud import \
    admin:secret-cluster-cookie@localhost:3301 \
    users.csv:users --header
```

Проверьте, что в спейсах появились данные.
Для этого в веб-интерфейсе TCM перейдите на вкладку **Tuples** и выберите в списке нужный спейс — `users`, `tasks` или `projects`.
Откроется новая вкладка с содержимым кортежей выбранного спейса.

## Метод space:upgrade()

`space:upgrade()` принимает следующие аргументы:

- `format`: новый формат спейса. Он может конфликтовать с предыдущим, но индексируемые поля должны быть неизменными.
    Данные, записываемые в спейс, должны соответствовать новому формату во время миграции.
- `func`: название функции выполнения миграций.
    Функция должна быть персистентной. Она принимает исходный кортеж, а возвращает измененный кортеж.
    Функция должна быть идемпотентной, чтобы избежать ошибки миграции или получения некорректных данных при чтении данных из спейса во время миграции,
    а из этого следует, что `func` может быть применена к `tuple` несколько раз.
  - `mode`: режим работы `space:upgrade`. Возможные значения:
    - `dryrun` — проверка корректности миграции. Функция `func` выполняется на каждом кортеже, но данные не меняются;
    - `upgrade` — обновление данных;
    - `dryrun+upgrade` — запуск проверки миграции, после которой при отсутствии ошибок выполняется `upgrade`.
- `is_async` - булевый флаг неблокируемого выполнения `space:upgrade()`.

> [!NOTE]
> Выполнение миграции через `space:upgrade()` может занимать продолжительное время.
> Чтобы избежать в процессе миграции ошибок вида `TimedOut: timed out`, выполните **одно** из действий ниже:
>
> - перед применением миграции включите асинхронный режим работы `space:upgrade()` с помощью флага `is_async = true`;
> - увеличьте для tt CLI время ожидания на завершение операции на экземпляре. Для этого при запуске миграции укажите в
>   команде tt migrations apply опцию `--execution-timeout=240`.
>   Узнать больше про эту опцию можно в [документации tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/migrations/#options).
>
> В данном руководстве используется **второй вариант** — с опцией `execution-timeout`.

`space:upgrade()` возвращает объект `future`. По нему можно узнать статус миграции (`future:info`),
отменить миграцию (`future:cancel`) или дождаться окончания миграции (`future:wait`).

Подробная информация о методе `space:upgrade()` приведена в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/platform/ddl_dml/migrations/space_upgrade/).

## Определение кода миграций

Исходный код миграции приведен в файле `cluster/migration_next/002_test.lua` примера `migrations_space_upgrade`.

### Спейс projects

В спейсе `projects` нужно добавить поле `assigned_manager_id` между полями `name` и `description`.
При работе с кортежами используется встроенная библиотека [`box.tuple`](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_tuple/).

Определите функцию для изменения кортежей:

```lua
-- Функция для преобразования кортежей в спейсе projects
box.schema.func.create('__migrator_projects_002', { -- Давайте функции название с номером миграции
    language = 'lua', -- Функция на Lua
    is_deterministic = true, -- Функция детерминированная
    body = [[
        function(t)
            if #t == 4 then
                return t:update({{'!', 4, box.NULL}})
            end
            return t
        end
    ]]
})
```

Теперь обновите формат спейса с помощью `space:upgrade()`.
`space:upgrade()` возвращает объект `future`.
Запишите этот объект в переменную `projects_migration`, чтобы отслеживать прогресс миграции:

```lua
local projects_migration = box.space.projects:upgrade({
    func = '__migrator_projects_002',
    format = {
        { name = 'project_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        -- Добавили поле assigned_manager_id
        { name = 'assigned_manager_id', type = 'uuid', is_nullable = true },
        { name = 'description', type = 'string', is_nullable = true },
    },
    mode = 'dryrun+upgrade',
    is_async = true,
})
```

Сохраните объект `projects_migration` в глобальную переменную, чтобы иметь к ней доступ из консоли tt:

```lua
rawset(_G, '__projects_migration', projects_migration)
```

### Спейс tasks

В спейсе `tasks` нужно:
- изменить тип поля `status` со `string` на `number`;
- добавить в конец поле `due_date(datetime)`.

Определите функцию для изменения кортежей:

```lua
-- Функция для преобразования кортежей в спейсе tasks
box.schema.func.create('__migrator_tasks_002', {
    language = 'lua',
    is_deterministic = true,
    body = [[
        function(t)
            -- Задана дата по умолчанию для due_date
            local datetime = require('datetime')
            local due_date = datetime.new({year=2999, month=12, day=31})
            -- Проверили количество полей. Если полей 7, это означает, что поле due_date добавлено не было
            if #t == 7 then
                -- Чтобы изменить тип поля, старое поле нужно удалить и добавить вместо него новое
                -- Для этого подходит функция `tuple:transform`
                -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_tuple/transform/
                -- t:transform(5, 1, 0) удаляет одно поле, начиная с пятого (status), и добавляет вместо него число 0
                -- update({{"!", 8, due_date}}) добавляет поле в конец, на восьмую позицию, и присваивает полю значение due_date
                return t:transform(5, 1, 0):update({{"!", 8, due_date}})
            end
            return t
        end
    ]],
})
```

Обновите формат спейса.
Запишите объект `future` в переменную `tasks_migration`:

```lua
local tasks_migration = box.space.tasks:upgrade({
    func = '__migrator_tasks_002',
    format = {
        { name = 'task_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'description', type = 'string', is_nullable = true },
        -- Изменили тип поля status
        { name = 'status', type = 'number' },
        { name = 'project_id', type = 'uuid' },
        { name = 'assigned_user_id', type = 'uuid', is_nullable = true },
        -- Добавили новое поле due_date
        { name = 'due_date', type = 'datetime' },
    },
    mode = 'dryrun+upgrade',
    is_async = true,
})
```

Сохраните объект `tasks_migration` в глобальную переменную, чтобы иметь к ней доступ из консоли tt:

```lua
rawset(_G, '__tasks_migration', tasks_migration)
```

### Спейс users

В спейсе `users` нужно:
- изменить название поля `email` на `contact`;
- добавить новое поле `role`.

Определите функцию для изменения кортежей:

```lua
-- Функция для преобразования кортежей в спейсе users
box.schema.func.create('__migrator_users_002',  {
    language = 'lua',
    is_deterministic = true,
    body = [[
        function(t)
            -- Проверили, что поле role еще не добавлено
            if #t == 4 then
                -- Добавили новое поле на четвертую позицию, между name и contact
                return t:update({{'!', 4, 'not set'}})
            end
            return t
        end
    ]],
})
```

Обновите формат спейса.
Запишите объект `future` в переменную `users_migration`:

```lua
local users_migration = box.space.users:upgrade({
    func = '__migrator_users_002',
    format = {
        { name = 'user_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        -- Добавили новое поле role
        { name = 'role', type = 'string' },
        -- Изменили название поля на contact
        { name = 'contact', type = 'string' },
    },
    mode = 'dryrun+upgrade',
    is_async = true,
})
```

Сохраните объект `users_migration` в глобальную переменную, чтобы иметь к ней доступ из консоли tt:

```lua
rawset(_G, '__users_migration', users_migration)
```

## Запуск миграции

Выполнить миграцию можно с помощью утилиты [tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/). Для этого:

1. В терминале поместите файлы из папки `migration_next` с кодом миграций `002_test.lua` в папку `./cluster/migrations/scenario/`:

   ```shell
   cd cluster
   cp -a migration_next/* migrations/scenario/
   ```

2. Загрузите миграции в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish):

   ```shell
   tt migrations publish http://admin:secret-cluster-cookie@localhost:2379/tdb/ migrations
   ```

   Узнать больше о командах `tt migrations` можно в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/migrations/).

3. Примените миграции с помощью команды `tt migrations apply`.

   > [!NOTE]
   > Выполнение миграции через `space:upgrade()` может занимать продолжительное время.
   > Чтобы избежать в процессе миграции ошибок вида `TimedOut: timed out`, выполните **одно** из действий ниже:
   >
   > - перед применением миграции включите асинхронный режим работы `space:upgrade()` с помощью флага `is_async = true`;
   > - увеличьте для tt CLI время ожидания на завершение операции на экземпляре. Для этого при запуске миграции укажите в
   >   команде tt migrations apply опцию `--execution-timeout=240`.
   >   Узнать больше про эту опцию можно в [документации tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/migrations/#options).
   >
   > В данном руководстве используется **второй вариант** — с опцией `execution-timeout`.

   ```shell
   docker compose exec tarantool-router-msk tt migrations apply http://etcd1:2379/tdb --tarantool-username=admin --tarantool-password=secret-cluster-cookie --execution-timeout=240
   cd ..
   ```

Теперь подключитесь к узлу хранилища.
Для этого в TCM откройте вкладку **Stateboard** и нажмите на набор реплик `storage-1`.
Выберите узел `storage-1-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Чтобы просмотреть статусы миграции спейса, вызовите соответствующую глобальную переменную, заданную в конфигурации:

```shell
tarantool-storage-1-msk:3301> __projects_migration
- owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_projects_002
  progress: 74%
  status: inprogress
  dryrun: true
tarantool-storage-1-msk:3301> __tasks_migration
- status: inprogress
  progress: 1%
  owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_tasks_002
tarantool-storage-1-msk:3301> __users_migration
- status: inprogress
  progress: 32%
  owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_users_002
...
```

В `space:upgrade` в режиме `dryrun+upgrade` сначала выполняется проверка (`dryrun`) данных без их изменений.
Если ошибок нет, начинается обновление данных.
На этапе проверки флаг `dryrun` принимает значение `true`:

```shell
tarantool-storage-1-msk:3301> __projects_migration
- owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_projects_002
  progress: 74%
  status: inprogress
  dryrun: true
```

При `space:upgrade()` запросы на чтение данных из мигрируемых спейсов отдают данные в нужном виде.
Проверить это можно, если выполнить код ниже во время миграций, когда в `__projects_migration`, `__tasks_migration`, `__users_migration` отсутствует флаг `dryrun: true`:

```shell
tarantool-storage-1-msk:3301> box.space.users:pairs({require('uuid').new()}, 'GE'):take_n(2):map(function(t) return t:tomap({names_only=true}) end):totable()
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
tarantool-storage-1-msk:3301> box.space.projects:pairs({require('uuid').new()}, 'GE'):take_n(2):map(function(t) return t:tomap({names_only=true}) end):totable()
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
tarantool-storage-1-msk:3301> box.space.tasks:pairs({require('uuid').new()}, 'GE'):take_n(2):map(function(t) return t:tomap({names_only=true}) end):totable()
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
```

После окончания миграций содержимое глобальных переменных с объектом `future` выглядит так:

```shell
tarantool-storage-1-msk:3301> __projects_migration
---
- status: done
...

tarantool-storage-1-msk:3301> __tasks_migration
---
- status: done
...

tarantool-storage-1-msk:3301> __users_migration
---
- status: done
...
```

Окончание миграции данных в логах выглядит так:

```bash
space_upgrade-tarantool-storage-1-msk  | 2024-02-26 09:13:43.048 [12] main/172/space_upgrade_516 I> space upgrade completed
space_upgrade-tarantool-storage-1-msk  | 2024-02-26 09:13:43.133 [12] main/173/space_upgrade_513 I> space upgrade completed
space_upgrade-tarantool-storage-1-msk  | 2024-02-26 09:13:43.163 [12] main/174/space_upgrade_515 I> space upgrade completed
```

## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
