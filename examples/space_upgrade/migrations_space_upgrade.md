# Миграция данных с помощью space:upgrade()

В этом руководстве описана миграция данных в Tarantool DB с помощью метода [space:upgrade()](https://www.tarantool.io/ru/doc/latest/enterprise/space_upgrade/).
`space:upgrade()` позволяет вносить несовместимые изменения в формат спейса, например изменить название спейса или удалить его.

```{admonition} Ограничения
:class: note

Поля, которые используются для индексации, изменять нельзя.
```

Подробнее о миграции можно прочитать в разделе [Миграция данных](user_guide-migrations).

Руководство включает следующие шаги:

* [](user_guide-space_upgrade-prereq)
* [](user_guide-space_upgrade-schema)
* [](user_guide-space_upgrade-start_example)
* [](user_guide-space_upgrade-load_data)
* [](user_guide-space_upgrade-description)
* [](user_guide-space_upgrade-migration_code)
* [](user_guide-space_upgrade-run_migration)
* [](user_guide-space_upgrade-stop_example)

(user_guide-space_upgrade-prereq)=
## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* исходные файлы примера `space_upgrade`. 

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `space_upgrade` расположен в таком архиве в директории `./doc/examples/space_upgrade/`.

  * Отдельный архив [space_upgrade.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/space_upgrade/space_upgrade.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-space_upgrade-schema)=
## Схема данных

В примере используется база данных для системы управления проектами, которая состоит из трех спейсов: `projects` (проекты), `tasks` (задачи),
`users` (пользователи). Изначально схема этой базы данных выглядит так:

![Схема_данных](images/schema1.drawio.svg)

После прохождения руководства схема данных будет изменена следующим образом:

* добавлено поле `assigned_manager_id` в спейс `projects`;
* изменен тип поля `status` в спейсе `tasks` со `string` на `number`;
* добавлено поле `due_date(datetime)` в спейс `tasks`;
* изменен название поля `email` на `contact` в спейсе `users`;
* добавлено поле `role` в спейс `users`.

После изменений схема данных будет выглядеть так:

![Схема данных 2](images/schema2.drawio.svg)

(user_guide-space_upgrade-start_example)=
## Запуск стенда

Для запуска и настройки кластера используются файлы из папки ``space_upgrade``:

* `docker-compose.yml` -- описание узлов кластера;
* `config.yml` -- конфигурация и топология кластера;
* `migrations/scenario` -- директория, содержащая файлы с описанием миграций;
* `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/tooling/tcm/).


Для успешного запуска должны быть свободны следующие порты:
* 3301--3304
* 8081

Перейдите в директорию примера `space_upgrade`:

```
cd ./doc/examples/space_upgrade/
```

Запустите стенд:

```
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
  - 1 роутер;
  - 1 набор реплик на 2 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
  - 2 координатора автоматического восстановления после сбоев (*failover coordinator*);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме `init_host`.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Получить пароль для входа в TCM можно так:
```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте TCM в браузере по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

Чтобы настроить кластер:

1. В веб-интерфейсе перейдите на вкладку **Clusters**.
2. В строке с кластером `Default cluster` нажмите кнопку **...** (**Actions**) справа и выберите **Edit** в выпадающем меню.
3. Переключитесь на второй экран настройки, используя кнопку **Next**.
4. На втором экране укажите в поле **Prefix** значение `/tdb` и нажмите  **Next**.
5. На третьем экране укажите следующие значения:
    - в поле **Username** -- `admin`;
    - в поле **Password** --  `secret-cluster-cookie`.

6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**.
8. Выберите любой роутер из списка, например `router-1`, и в открывшемся окне перейдите на вкладку **Terminal**.
9. Во вкладке **Terminal** введите команду `box.space`.  Проверьте, что в выводе есть спейсы `projects`, `tasks` и `users` -- эти спейсы создаются при запуске кластера.
В запущенном кластере создана первоначальная схема данных:

   ![схема данных](images/schema1.drawio.svg)

(user_guide-space_upgrade-load_data)=
## Подключение к кластеру и загрузка данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- В терминале на вашем ПК с помощью команды `tt connect`:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

- В веб-интерфейсе TCM.

Подключитесь к роутеру `router-1`, используя **первый способ** -- через TCM. Для этого:
	
1. Перейдите на вкладку **Stateboard**.
2. Выберите роутер `router-1` и в открывшемся окне перейдите на вкладку **Terminal**.

Загрузите данные в кластер с помощью утилиты TT CLI:

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

(user_guide-space_upgrade-description)=
## Метод space:upgrade()

`space:upgrade()` принимает следующие аргументы:

- `format`: новый формат спейса. Он может конфликтовать с предыдущим, но индексируемые поля должны быть неизменными.
    Данные, записываемые в спейс, должны соответствовать новому формату во время миграции.
- `func`: название функции выполнения миграций.
    Функция должна быть персистентной. Она принимает исходный кортеж, а возвращает измененный кортеж.
    Функция должна быть идемпотентной, чтобы избежать ошибки миграции или получения некорректных данных при чтении данных из спейса во время миграции.
а из этого следует, что `func` может быть применена к `tuple` несколько раз.
  - `mode`: режим работы `space:upgrade`. Возможные значения:
    - `dryrun` -- проверка корректности миграции. Функция `func` выполняется на каждом кортеже, но данные не меняются;
    - `upgrade` -- обновление данных;
    - `dryrun+upgrade` -- запуск проверки миграции, после которой при отсутствии ошибок выполняется `upgrade`.
- `is_async` - булевый флаг неблокируемого выполнения `space:upgrade`.

`space:upgrade` возвращает объект `future`. По нему можно узнать статус миграции (`future:info`), отменить миграцию (`future:cancel`) или дождаться окончания миграции (`future:wait`).

Подробная информация о методе `space:upgrade` приведена в [документации Tarantool Enterprise](https://www.tarantool.io/ru/doc/latest/enterprise/space_upgrade/).

(user_guide-space_upgrade-migration_code)=
## Определение кода миграций

Исходный код миграции приведен в файле `002_test.lua` в директории `./migration_next/` примера `migrations_space_upgrade`.

### Спейс projects

В спейсе `projects` нужно добавить поле `assigned_manager_id` между полями `name` и `description`. 
При работе с кортежами используется встроенная библиотека [`box.tuple`](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_tuple/).

Определите функцию для изменения кортежей:

```lua
-- функция для преобразования кортежей
box.schema.func.create('__migrator_projects_002', { -- давайте функции название с номером миграции
    language = 'lua', -- функция на Lua
    is_deterministic = true, -- функция детерминированная
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

В спейс `tasks` нужно изменить тип поля `status` с `number` на `string`, а также добавить в конец поля `due_date(datetime)`.

Определите функцию для изменения кортежей:

```lua
box.schema.func.create('__migrator_tasks_002', {
    language = 'lua',
    is_deterministic = true,
    body = [[
        function(t)
            -- задана дата по умолчанию для due_date
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
```

Сохраните объект `tasks_migration` в глобальную переменную, чтобы иметь к ней доступ из консоли tt:

```lua
rawset(_G, '__tasks_migration', tasks_migration)
```

### Спейс users

В спейсе `users` нужно изменить название поля `email` на `contact`, а также добавить новое поле `role`.


```lua
box.schema.func.create('__migrator_users_002',  {
    language = 'lua',
    is_deterministic = true,
    body = [[
        function(t)
            -- проверяем, что поле `role` еще не добавлено
            if #t == 4 then
                -- добавляем новое поле на 4-ю позицию, между `name` и `contact`
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
        -- новое поле `role`
        { name = 'role', type = 'string' },
        -- изменяем название поля на `contact`
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

(user_guide-space_upgrade-run_migration)=
## Запуск миграции

1. Поместите файл с кодом миграций `002_test.lua` в папку `./migrations/scenario/`:

   ```shell
   cp -a ./migration_next/* ./migrations/scenario/ 
   ```

2. Загрузите миграции в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish):

   ```shell
   tt migrations publish http://admin:secret-cluster-cookie@localhost:2379/tdb/ migrations
   ```

3. Примените миграции:

   ```shell
   docker exec migrations-tarantool-router-1-1  tt migrations up http://etcd1:2379/tdb --tarantool-cluster-username=admin --tarantool-cluster-password=secret-cluster-cookie
   ```

4. Подключитесь к узлу хранилища в TCM на вкладке **Stateboard** и откройте вкладку **Terminal**.
   Чтобы просмотреть статусы миграции спейса, вызовите соответствующую глобальную переменную, заданную в конфигурации:

    ```shell
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

В `space:upgrade` в режиме `dryrun+upgrade` сначала выполняется проверка (`dryrun`) данных без их изменений.
Если ошибок нет, начинается обновление данных.
На этапе проверки флаг `dryrun` принимает значение `true`:

```shell
localhost:3301> __projects_migration
- owner: baf5b6ba-d594-4b80-856e-02e1f05de5c7
  func: __migrator_projects_002
  progress: 74%
  status: inprogress
  dryrun: true
```

При `space:upgrade()` запросы на чтение данных из мигрируемых спейсов отдают данные в нужном виде.
Проверить это можно, если выполнить код ниже во время миграций, когда в `__projects_migration`, `__tasks_migration`, `__users_migration` отсутствует флаг `dryrun: true`:

```shell
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
```


После окончания миграций содержимое глобальных переменных с объектом `future` выглядит так:

```shell
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

Окончание миграции данных в логах выглядит так:

```bash
space_upgrade-tarantool-storage3-1  | 2024-02-26 09:13:43.048 [12] main/172/space_upgrade_516 I> space upgrade completed
space_upgrade-tarantool-storage3-1  | 2024-02-26 09:13:43.133 [12] main/173/space_upgrade_513 I> space upgrade completed
space_upgrade-tarantool-storage3-1  | 2024-02-26 09:13:43.163 [12] main/174/space_upgrade_515 I> space upgrade completed
```

(user_guide-space_upgrade-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
make stop
```
