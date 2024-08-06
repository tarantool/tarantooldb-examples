# Изменение схемы данных с помощью space:format()

В этом руководстве рассказано, как разработать типовое приложение в Tarantool DB и изменить в нем схему данных, используя
метод [space:format()](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_space/format/).
В качестве примера используется база данных для системы управления проектами.
Для работы используются модули [CRUD](https://github.com/tarantool/crud) и [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/).

Руководство включает следующие шаги:

* [](user_guide-space_format-prereq)
* [](user_guide-space_format-schema)
* [](user_guide-space_format-start_example)
* [](user_guide-space_format-load_data)
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

(user_guide-space_format-start_example)=
## Запуск стенда

Для запуска и настройки кластера используются файлы из папки ``migrations``:

* `docker-compose.yml` -- описание узлов кластера;
* `config.yml` -- конфигурация и топология кластера;
* `migrations/scenario` -- директория, содержащая файлы с описанием миграций;
* `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).


Для успешного запуска должны быть свободны следующие порты:
* 3301--3304
* 8081

Перейдите в директорию примера `migrations`:

```
cd ./doc/examples/migrations/
```

Запустите стенд:

```
docker compose up -d
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
   ![tcm](images/tcm1.png)

2. В строке с кластером `Default cluster` нажмите кнопку **...** (**Actions**) справа и выберите **Edit** в выпадающем меню.
3. Переключитесь на второй экран настройки, используя кнопку **Next**.
   ![tcm](images/tcm2.png)

4. На втором экране укажите в поле **Prefix** значение `/tdb` и нажмите  **Next**.
   ![tcm](images/tcm3.png)

5. На третьем экране укажите следующие значения:
   - в поле **Username** -- `admin`;
   - в поле **Password** --  `secret-cluster-cookie`.

   ![tcm](images/tcm4.png)

6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**.
8. Выберите любой роутер из списка (например, `router-1`) и в открывшемся окне перейдите на вкладку **Terminal**.
9. Во вкладке **Terminal** введите команду `box.space`.  Проверьте, что в выводе есть спейсы `projects`, `tasks` и `users` -- эти спейсы создаются при запуске кластера.
10. Проверьте, что в запущенном кластере созданы функции `app.delete_user(user_id)` и `app.get_project_data(project_id)`.

(user_guide-space_format-load_data)=
## Загрузка и проверка данных

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

Исходный код миграции приведен в файле `001_test.lua` в директории `./migrations/scenario/` примера `migrations`.

Загрузить тестовые данные можно с помощью функции `__create_example_data`.
Функция очищает кластер и заполняет его данными из примера:

```shell
localhost:3301> box.schema.func.call('__create_example_data')
```

Чтобы проверить загруженные данные, выполните несколько базовых операций в спейсе `users`, используя модуль CRUD:

```shell
localhost:3301> crud.select('users')
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
  rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'john_doe', 'john.doe@example.com']
  - [1e63739a-dad0-4c5d-80e4-cd39594fe302, 1985, 'jane_smith', 'jane.smith@example.com']
- null
...

localhost:3301> crud.select('users', {{"==", "name", "john_doe"}})
---
- metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
  rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'john_doe', 'john.doe@example.com']
- null

localhost:3301> crud.update('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'), {{'=', 'name', "John Doe"}})
---
- rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'John Doe', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null

localhost:3301> crud.get('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'John Doe', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null

localhost:3301> crud.delete('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- rows:
  - [04e7f6a2-2979-46e4-8d71-e80217e3aac3, 23464, 'John Doe', 'john.doe@example.com']
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...
```

Чтобы вернуть данные в прежнее состояние, вызовите функцию `__create_example_data` еще раз:

```shell
localhost:3301> box.schema.func.call('__create_example_data')
```

(user_guide-space_format-check_functions)=
## Проверка пользовательских функций базы данных

Модуль [CRUD](https://github.com/tarantool/crud) упрощает работу с шардированными данными -- выполнение простых операций
чтения и записи таких данных прозрачно для пользователя.
Тем не менее, для задач, реализующих функции базы данных (`app.get_project_data(id)`, `app.delete_user(id)` и `app.delete_project(id)`),
модуля CRUD недостаточно.
Это связано с тем, что эти функции работают с несколькими спейсами и нестандартными операциями чтения и записи.

### Получение данных проекта

Для проверки функции `app.get_project_data(project_id)` верните данные в первоначальное состояние:
```shell
localhost:3301> box.schema.func.call('__create_example_data')
```

Вызовите функцию и оцените результат:
```shell
localhost:3301> box.schema.func.call('app.get_project_data', require('uuid').fromstr('46f8e628-d2c2-42ba-984f-29a459a3d0fc'))
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

Функция `app.get_project_data(project_id)` выполняет `join` из всех спейсов, используются `crud.get`, `crud.pairs`.

### Удаление пользователя

Для проверки функции `app.delete_user(user_id)` верните данные в первоначальное состояние:

```shell
localhost:3301> box.schema.func.call('__create_example_data')
```

Удалите пользователя:

```shell
localhost:3301> box.schema.func.call('app.delete_user', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- res: true
  err: null
...

localhost:3301> box.schema.func.call('app.get_project_data', require('uuid').fromstr('46f8e628-d2c2-42ba-984f-29a459a3d0fc'))
---
- res:
    tasks:
    - status: In Progress
      name: Optimize Database
      description: Optimize the database to improve performance.
    name: Task Management
    description: Development of a task management system
  err: null

localhost:3301> crud.get('users', require('uuid').fromstr('04e7f6a2-2979-46e4-8d71-e80217e3aac3'))
---
- rows: []
  metadata: [{'name': 'user_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'email', 'is_nullable': true}]
- null
...
```

В выводе функции видно, что информации о пользователе нет -- пользователь успешно удален.

Теперь во всех связанных с этим пользователем задачах нужно присвоить полю `assigned_user_id` значение `box.NULL`.
Для этого на всех хранилищах была объявлена функция ``tasks.set_box_NULL_for_user_id``.
Функция задает `box.NULL` в поле `assigned_user_id` для всех задач, у которых `assigned_user_id == user_id`, где
`user_id` -- аргумент функции.

Код функции:

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

Особенность `app.delete_user(id)` состоит в том, что спейсы  `tasks` и `users` шардируются по разным ключам.
В общем случае связанные задачи и пользователи будут находиться на разных шардах. Это значит, что нет узла, на котором бы было известно,
на каких шардах будут задачи, связанные с удаляемым пользователем.
Вызывать функцию `tasks.set_box_NULL_for_user_id` нужно на каждом мастере шарда, потому что такие задачи будут на всех 
шардах.
Для вызова функции на всех шардах используется модуль для горизонтального масштабирования [vshard](https://www.tarantool.io/ru/doc/latest/reference/reference_rock/vshard/).

Вызов функции `tasks.set_box_NULL_for_user_id` выглядит так:

```lua
local _, err, uuid = vshard_router.map_callrw('tasks.set_box_NULL_for_user_id', {user_id})
```

Полный исходный код приведен в файле миграции `./migrations/scenario/001_test.lua` примера `migrations`.

### Удаление проекта

Для проверки функции `app.delete_project(project_id)` верните данные в первоначальное состояние:

```shell
localhost:3301> box.schema.func.call('__create_example_data')
```

Просмотрите содержимое спейса `projects`. Видно, что проект `Website Update` был удален вместе со всеми задачами:

```shell
localhost:3301> crud.select('projects')
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

localhost:3301> crud.select('tasks')
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

localhost:3301> box.schema.func.call('app.delete_project', require('uuid').fromstr('f53392af-30e3-4bfc-bde8-37043951159a'))
---
- res: true
  err: null
...

localhost:3301> crud.select('projects')
---
- metadata: [{'name': 'project_id', 'type': 'uuid'}, {'name': 'bucket_id', 'type': 'unsigned'},
    {'name': 'name', 'type': 'string'}, {'type': 'string', 'name': 'description',
      'is_nullable': true}]
  rows:
  - [46f8e628-d2c2-42ba-984f-29a459a3d0fc, 1033, 'Task Management', 'Development of
      a task management system']
- null

localhost:3301> crud.select('tasks')
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

Для вызова функции на конкретном мастере используется модуль `vshard`.
Вызов функции `projects.delete_project` выглядит так:

```lua
local vshard_router = require('vshard.router')
local bucket_id = vshard_router.bucket_id_strcrc32(id)
local _, err = vshard_router.callrw(bucket_id, 'projects.delete_project', {id})
```

Полный исходный код приведен в файле миграции `./migrations/scenario/001_test.lua` примера `migrations`.

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

Код миграции приведен в файле `./migration_next/002_test.lua` примера `migrations`.

Миграции выполняются в лексикографическом порядке, поэтому им даны нумерованные названия: (`0001_my_migr.lua`, `2023_12_24_migr.lua`).

Подготовьте данные для миграции:

```lua
localhost:3301> box.schema.func.call('__create_example_data')
```

(user_guide-space_format-change_schema-migrations)=
### Выполнение миграции

Выполнить миграцию можно с помощью утилиты [tt CLI](https://www.tarantool.io/ru/doc/latest/reference/tooling/tt_cli/). Для этого:

1. В терминале поместите файлы с кодом миграций `002_test.lua` и `002_test_upgrade.lua` в папку `./migrations/scenario/`:

   ```shell
   cp -a ./migration_next/* ./migrations/scenario/ 
   ```

2. Загрузите миграции в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/reference/tooling/tt_cli/cluster/#tt-cluster-publish):

   ```shell
   tt migrations publish http://admin:secret-cluster-cookie@localhost:2379/tdb/ migrations
   ```

3. Примените миграции:

   ```shell
   docker exec migrations-tarantool-router-1-1  tt migrations up http://etcd1:2379/tdb --tarantool-cluster-username=admin --tarantool-cluster-password=secret-cluster-cookie
   ```
   
   В случае успеха вывод будет выглядеть так:

   ```shell
   • storage-1:
   /tdb/migrations/scenario/001_test.lua:
   Status: skipped, already applied
   /tdb/migrations/scenario/002_test.lua:
   Status: skipped, already applied
   /tdb/migrations/scenario/002_test_upgrade.lua:
   Status: skipped, already applied
   • router-1:
   /tdb/migrations/scenario/001_test.lua:
   Status: applied
   /tdb/migrations/scenario/002_test.lua:
   Status: applied
   /tdb/migrations/scenario/002_test_upgrade.lua:
   Status: applied
   ```

4. Проверьте, что миграция прошла успешно, выполнив операцию `crud.select()` в TCM во вкладке **Terminal**. Видно, что добавлены новые поля со значениями по умолчанию:

   ```shell
   localhost:3301> crud.select('projects')
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

   localhost:3301> crud.select('tasks')
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

   localhost:3301> crud.select('users')
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

5. Теперь проверьте функцию `app.get_project_data`. В функции должны появиться новые поля в ответе:

   ```shell
   localhost:3301> box.schema.func.call('app.get_project_data', require('uuid').fromstr('46f8e628-d2c2-42ba-984f-29a459a3d0fc'))
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

6. Теперь нужно изменить функцию ``app.get_project_data``.
   Для этого транзакционно удалите старую функцию и добавьте новую.
   Такой подход гарантирует, что не произойдет ситуации, когда функции ``app.get_project_data`` не существует.

   ```lua
    box.atomic(function()
       box.schema.func.drop('app.get_project_data') -- удаляется старый вариант
       box.schema.func.create('app.get_project_data',  {
         language = 'LUA',
           if_not_exists = true,
           body = [[ ... ]]
       }) -- добавляем новый вариант
   end)
   ```

Узнать подробнее о том, как хранятся персистентные функции, можно в спейсе [box.space._func](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_space/_func/).

(user_guide-space_format-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
