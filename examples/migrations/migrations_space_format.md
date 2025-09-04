# Изменение схемы данных с помощью space:format()

В этом руководстве рассказано, как разработать типовое приложение в Tarantool DB и изменить в нем схему данных, используя
метод [space:format()](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_space/format/).
В качестве примера используется база данных для системы управления проектами.
Для работы используются модули [CRUD](https://github.com/tarantool/crud) и [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/).

Руководство включает следующие шаги:

* [](user_guide-space_format-prereq)
* [](user_guide-space_format-schema)
* [](user_guide-space_format-files)
* [](user_guide-space_format-start_example)
* [](user_guide-space_format-load_data)
* [](user_guide-space_format-check_data)
* [](user_guide-space_format-check_functions)
* [](user_guide-space_format-change_schema)
* [](user_guide-space_format-stop_example)

(user_guide-space_format-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* исходные файлы примера `migrations`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `migrations` расположен в таком архиве в директории `./doc/examples/migrations/`.
    
  * Отдельный архив [migrations.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/migrations/migrations.tar.gz), скачанный c сайта Tarantool.
  ```
 
(user_guide-space_format-schema)=
## Схема данных

В качестве примера приведена база данных для системы управления проектами, которая состоит из трех спейсов: `projects` (проекты), `tasks` (задачи),
`users` (пользователи).
Схема этой базы данных выглядит так:

![Схема данных](images/schema1.drawio.svg)

Здесь:

* Спейсы `projects` и `tasks` имеют одинаковый [ключ шардирования](https://www.tarantool.io/ru/doc/latest/concepts/sharding/) `project_id` и находятся на одном экземпляре.
* Спейс `users` имеет ключ шардирования `user_id`.

Особенности базы данных:
* Задач на проекте больше, чем пользователей.
* При удалении проекта нужно удалить и связанные с ним задачи.
  Это удобно делать, если все записи находятся на одном экземпляре.

```{admonition} Примечание
:class: note
При выборе ключа шардирования учитывайте предметную область и предполагаемое API.
```

Для работы с данными в примере используются методы модуля CRUD.
Дополнительно будет реализовано следующее API:

- `app.delete_user(user_id)` -- удаление пользователя. У всех задач, связанных с этим пользователем, в поле `assigned_user_id` должен быть выставлен `box.NULL`;
- `app.delete_project(project_id)` -- удаление проекта и все связанных с ним задач;
- `app.get_project_data(project_id)` -- получение проекта и всех связанных с ним задач и пользователей.

(user_guide-space_format-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `migrations`:

- `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  - `config.yml` -- конфигурация и топология кластера;
  - `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  - `migrations/scenario/` и `migration_next/` -- директории, содержащие файлы с описанием миграций;
- `tools/` -- директория с файлами для запуска кластера etcd и TCM:
  - `docker-compose.yml` -- описание узлов кластера etcd;
  - `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

(user_guide-space_format-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301--3308
* 8081

Перейдите в директорию примера `migrations`:

```
cd ./doc/examples/migrations/
```

Запустите стенд:

```
make start
```

Команда развернет стенд, состоящий из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик узел `storage-1-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** введите следующую команду:

```lua
box.space
```

Проверьте, что в выводе есть спейсы `projects`, `tasks` и `users` -- эти спейсы создаются при запуске кластера.
Кроме того, проверьте, что в запущенном кластере созданы функции `app.delete_user(user_id)` и `app.get_project_data(project_id)`.

(user_guide-space_format-load_data)=
## Загрузка данных

Исходный код миграции приведен в файле `001_test.lua` в директории `./cluster/migrations/scenario/` примера `migrations`.

Загрузить тестовые данные в спейсы можно с помощью утилиты tt CLI:

```shell
tt crud import \
	admin:secret-cluster-cookie@localhost:3301 \
	examples_data_projects.csv:projects \
	--header
tt crud import \
	admin:secret-cluster-cookie@localhost:3301 \
	examples_data_users.csv:users \
	--header
tt crud import \
	admin:secret-cluster-cookie@localhost:3301 \
	examples_data_tasks.csv:tasks \
	--header
```

(user_guide-space_format-check_data)=
## Проверка загруженных данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера. Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:
	
1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Чтобы проверить загруженные данные, выполните в TCM во вкладке **Terminal** несколько базовых операций в спейсе `users`, используя модуль CRUD:

```shell
tarantool-router-msk:3301> crud.select('users')
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
  rows:
  - [cccccccc-0000-0000-0000-000000000001, 24745, 'John Doe', 'john.doe@example.com']
  - [cccccccc-0000-0000-0000-000000000002, 24093, 'Jane Smith', 'jane.smith@example.com']
  - [cccccccc-0000-0000-0000-000000000003, 19072, 'Michael Brown', 'michael.brown@example.com']
  - [cccccccc-0000-0000-0000-000000000004, 13957, 'Emily Davis', 'emily.davis@example.com']
  - [cccccccc-0000-0000-0000-000000000005, 22248, 'David Wilson', 'david.wilson@example.com']
  - [cccccccc-0000-0000-0000-000000000006, 16356, 'Emma Johnson', 'emma.johnson@example.com']
  - [cccccccc-0000-0000-0000-000000000007, 24657, 'James Martinez', 'james.martinez@example.com']
  - [cccccccc-0000-0000-0000-000000000008, 4437, 'Olivia Garcia', 'olivia.garcia@example.com']
  - [cccccccc-0000-0000-0000-000000000009, 23784, 'Robert Rodriguez', 'robert.rodriguez@example.com']
  - [cccccccc-0000-0000-0000-00000000000a, 23932, 'Ava Martinez', 'ava.martinez@example.com']
- null
...

tarantool-router-msk:3301> crud.select('users', {{"==", "name", "John Doe"}})
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
  rows:
  - [cccccccc-0000-0000-0000-000000000001, 24745, 'John Doe', 'john.doe@example.com']
- null
...

tarantool-router-msk:3301> crud.update('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'),
 {{'=', 'name', "John Doevelyn"}})
---
- rows: []
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...

tarantool-router-msk:3301> crud.update('users', require('uuid').fromstr('cccccccc-0000-0000-0000-000000000001'),
 {{'=', 'name', "John Doevelyn"}})
---
- rows:
  - [cccccccc-0000-0000-0000-000000000001, 24745, 'John Doevelyn', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...

tarantool-router-msk:3301> crud.get('users', require('uuid').fromstr('cccccccc-0000-0000-0000-000000000001'))
---
- rows:
  - [cccccccc-0000-0000-0000-000000000001, 24745, 'John Doevelyn', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...

tarantool-router-msk:3301> crud.delete('users', require('uuid').fromstr('cccccccc-0000-0000-0000-000000000001'))
---
- rows:
  - [cccccccc-0000-0000-0000-000000000001, 24745, 'John Doevelyn', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...
```

(user_guide-space_format-check_functions)=
## Проверка пользовательских функций базы данных

Модуль [CRUD](https://github.com/tarantool/crud) упрощает работу с шардированными данными -- выполнение простых операций
чтения и записи таких данных прозрачно для пользователя.
Тем не менее, для задач, реализующих функции базы данных (`app.get_project_data(id)`, `app.delete_user(id)` и `app.delete_project(id)`),
модуля CRUD недостаточно.
Это связано с тем, что эти функции работают с несколькими спейсами и нестандартными операциями чтения и записи.

(user_guide-space_format-check_functions-get)=
### Получение данных проекта

В TCM во вкладке **Terminal** вызовите функцию и оцените результат:

```shell
localhost:3301> box.schema.func.call('app.get_project_data', require('uuid').fromstr('aaaaaaaa-0000-0000-0000-000000000001'))
---
- res:
    tasks:
    - status: In Progress
      user:
        name: Jane Smith
        email: jane.smith@example.com
      name: Optimize Database
      description: Optimize the database to improve performance.
    - status: Not Started
      user:
        name: Michael Brown
        email: michael.brown@example.com
      name: Create New Logo
      description: Design a new logo for the website.
    name: Task Management
    description: Development of a task management system
  err: null
```

В выводе видны данные проекта `Task Management` и двух задач из этого проекта.
Функция `app.get_project_data(project_id)` выполняет `join` из всех спейсов, используются `crud.get`, `crud.pairs`.

(user_guide-space_format-check_functions-replace)=
### Замена пользователя

Предположим, что во всех задачах, связанных с некоторым пользователем, нужно присвоить полю `assigned_user_id` 
другого пользователя.
Для этой цели на всех хранилищах объявлена функция `tasks.replace_user`.
Функция задает новое значение в поле `assigned_user_id` для всех задач, у которых `assigned_user_id == user_id`, где
`user_id` -- аргумент функции.

Код функции:

```lua
function(current_user_id, new_user_id)
    local fiber = require('fiber')
    local every_100 = 0
    for _, t in box.space.tasks.index.assigned_user_id:pairs({current_user_id}, 'EQ') do
        box.space.tasks:update(t.task_id, {{'=', 'assigned_user_id', new_user_id}})
        
        every_100 = every_100 + 1
        if every_100 == 100 then
            every_100 = 0
            fiber.yield()
        end
    end
    return true
end
```

Особенность такой замены состоит в том, что спейсы  `tasks` и `users` шардируются по разным ключам.
В общем случае связанные задачи и пользователи будут находиться на разных наборах реплик.
Это значит, что нет узла, на котором бы было известно, на каких наборах реплик будут задачи, связанные с удаляемым пользователем.
Вызывать функцию `tasks.replace_user` нужно на каждом мастере набора реплик, потому что такие задачи будут на всех наборах реплик.
Для вызова функции на всех наборах реплик используется модуль для горизонтального масштабирования [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/).

В примере ниже функция `tasks.replace_user` заменяет пользователя `Jane Smith` на `Ava Martinez`:

```lua
vshard.router.map_callrw('tasks.replace_user', {
    require('uuid').fromstr('cccccccc-0000-0000-0000-000000000002'),
    require('uuid').fromstr('cccccccc-0000-0000-0000-00000000000a')
})
```

В TCM во вкладке **Terminal** просмотрите ещё раз данные проекта `Task Management` :

```shell
localhost:3301> box.schema.func.call('app.get_project_data', require('uuid').fromstr('aaaaaaaa-0000-0000-0000-000000000001'))
---
- res:
    tasks:
    - status: In Progress
      user:
        name: Ava Martinez
        email: ava.martinez@example.com
      name: Optimize Database
      description: Optimize the database to improve performance.
    - status: Not Started
      user:
        name: Michael Brown
        email: michael.brown@example.com
      name: Create New Logo
      description: Design a new logo for the website.
    name: Task Management
    description: Development of a task management system
  err: null
```

Видно, что в проекте на задачах пользователь `Jane Smith` изменен на `Ava Martinez`.

Полный исходный код функции `tasks.replace_user` приведен в файле миграции `./cluster/migrations/scenario/001_test.lua` примера `migrations`.

(user_guide-space_format-check_functions-delete)=
### Удаление проекта

Удалите проект `Task Management`:

```shell
tarantool-router-msk:3301> box.schema.func.call('app.delete_project',
    require('uuid').fromstr('aaaaaaaa-0000-0000-0000-000000000001')
    )
---
- res: true
  err: null
...
```

Просмотрите содержимое спейса `projects`.
Видно, что проект `Task Management` был удален вместе со всеми задачами:

```shell
tarantool-router-msk:3301> box.schema.func.call('app.get_project_data',
    require('uuid').fromstr('aaaaaaaa-0000-0000-0000-000000000001')
    )
---
- res: []
  err: null
...
```

Спейсы `projects` и `tasks` шардируются по одинаковым значениям.
Это означает, что связанные между собой проект и задача находятся на одном экземпляре.
Такой подход позволяет транзакционно удалить данные из `projects` и `tasks`.
Для этого на хранилищах реализована API-функция `projects.delete_project`.

Код функции:

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

Для вызова функции на конкретном мастер-узле используется модуль `vshard`.
Вызов функции `projects.delete_project` через модуль `vshard` в коде `app.delete_project` выглядит так:

```lua
local vshard_router = require('vshard.router')
local bucket_id = vshard_router.bucket_id_strcrc32(project_id)
local _, err = vshard_router.callrw(bucket_id, 'projects.delete_project', {project_id})
```

Полный исходный код функции `projects.delete_project` приведен в файле миграции `./cluster/migrations/scenario/001_test.lua` примера `migrations`.

(user_guide-space_format-change_schema)=
## Изменение схемы данных

Предположим, что теперь нужно изменить схему данных, добавив в нее новые поля:

* `deadline (datetime)` в спейс `projects`;
* `due_date (datetime)` в спейс `tasks`;
* `role (string)` в спейс `users`.

По умолчанию в полях `projects.deadline` и `due_date(datetime)` должно быть значение `2999-12-31T00:00:00Z`, а в поле
`users.role` -- значение `not set`.
Функцию `app.get_project_data` нужно также переписать, чтобы отображались новые поля.

Новая схема данных будет выглядеть так:

![Схема данных](images/schema2.drawio.svg)

Код миграции приведен в файле `./cluster/migration_next/002_test.lua` примера `migrations`.

Миграции выполняются в лексикографическом порядке, поэтому им даны нумерованные названия: (`0001_my_migr.lua`, `2023_12_24_migr.lua`).

(user_guide-space_format-change_schema-migrations)=
### Выполнение миграции

Выполнить миграцию можно с помощью утилиты [tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/). Для этого:

1. В терминале поместите файлы из папки `migration_next` с кодом миграций `002_test.lua` и `002_test_upgrade.lua` в папку `./cluster/migrations/scenario/`:

   ```shell
   cd cluster
   cp -a migration_next/* migrations/scenario/ 
   ```

2. Загрузите миграции в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish):

   ```shell
   tt migrations publish http://admin:secret-cluster-cookie@localhost:2379/tdb/ migrations
   ```

   Узнать больше о командах `tt migrations` можно в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/migrations/).

3. Примените миграции:

   ```shell
   docker compose exec tarantool-router-msk tt migrations apply http://etcd1:2379/tdb --tarantool-username=admin --tarantool-password=secret-cluster-cookie
   cd ..
   ```
   
   В случае успеха вывод будет выглядеть так:

   ```shell
   • router-msk:              
   •     001_test.lua: skipped, already applied
   •     002_test.lua: successfully applied
   •     002_test_upgrade.lua: successfully applied
   • router-spb:              
   •     001_test.lua: skipped, already applied
   •     002_test.lua: successfully applied
   •     002_test_upgrade.lua: successfully applied
   • storage-1:               
   •     001_test.lua: skipped, already applied
   •     002_test.lua: successfully applied
   •     002_test_upgrade.lua: successfully applied
   • storage-2:               
   •     001_test.lua: skipped, already applied
   •     002_test.lua: successfully applied
   •     002_test_upgrade.lua: successfully applied
   ```

4. Проверьте, что миграция прошла успешно.
   Для этого в TCM во вкладке **Terminal** выполните функцию `app.get_project_data`.
   В функции должны появиться новые поля в ответе:

    ```shell
    tarantool-router-msk:3301> box.schema.func.call('app.get_project_data', require('uuid').fromstr('aaaaaaaa-0000-0000-0000-000000000002'))
    ---
    - res:
        tasks:
        - due_date: 2999-12-31T00:00:00Z
          status: In Progress
          user:
            email: not set
            name: Emily Davis
            role: emily.davis@example.com
          name: Develop User Authentication
          description: Implement user authentication for the mobile app.
        - due_date: 2999-12-31T00:00:00Z
          status: Not Started
          user:
            email: not set
            name: David Wilson
            role: david.wilson@example.com
          name: Design Marketing Materials
          description: Create brochures and flyers for the campaign.
        deadline: 2999-12-31T00:00:00Z
        name: Website Update
        description: Making changes to the website design and functionality
      err: null
    ...
    ```

5. Обратите внимание, что в миграции происходит обновление функции `app.get_project_data`.
   Для этого транзакционно удаляется старая функция и добавляется новая.
   Такой подход гарантирует, что не произойдет ситуации, когда функции `app.get_project_data` не существует:

   ```lua
    box.atomic(function()
       box.schema.func.drop('app.get_project_data') -- удаляется старый вариант
       box.schema.func.create('app.get_project_data',  {
         language = 'LUA',
           if_not_exists = true,
           body = [[ ... ]]
       }) -- добавляется новый вариант
   end)
   ```

Узнать подробнее о том, как хранятся персистентные функции, можно в спейсе [box.space._func](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_space/_func/).

(user_guide-space_format-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
