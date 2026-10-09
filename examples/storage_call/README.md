# Вызов функций на хранилищах с помощью CRUD

В этом руководстве показано, как создать персистентные функции и вызвать их
на хранилищах через `crud.storage_call()` и `crud.storage_call_many()`.
Клиент подключается к роутеру, а CRUD направляет вызов на нужное хранилище.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Используемые файлы](#используемые-файлы)
* [Запуск стенда](#запуск-стенда)
* [Создание спейса и подключение к узлу](#создание-спейса-и-подключение-к-узлу)
* [Подготовка данных](#подготовка-данных)
* [Одиночный вызов](#одиночный-вызов)
* [Пакетный вызов](#пакетный-вызов)
* [Вызов с ограниченными правами](#вызов-с-ограниченными-правами)
* [Повтор вызова](#повтор-вызова)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB с CRUD 1.8.0 или новее;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt);
* исходные файлы примера `storage_call`.

> [!NOTE]
> Есть два способа получить исходные файлы примера:
> * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>   Пример `storage_call` расположен в директории `examples/storage_call`.
> * Отдельный архив [storage_call.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fstorage_call&filename=storage_call), скачанный из этого репозитория.

## Используемые файлы

В руководстве используются следующие файлы примера `storage_call`:

* `Makefile` — запуск и остановка стенда;
* `cluster/` — директория с файлами для запуска кластера Tarantool DB:
  * `config.yml` — конфигурация кластера и пользователь с ограниченными правами;
  * `docker-compose.yml` — описание узлов кластера и применение миграции;
  * `migrations/scenario/001_accounts.lua` — миграция, создающая спейс `accounts`, хранимые функции и права доступа к ним;
* `tools/` — директория с файлами для запуска etcd и TCM:
  * `docker-compose.yml` — описание узлов etcd и TCM;
  * `tcm.yml` — конфигурация [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/reference/tooling/tcm/).

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3305
* 8081

Перейдите в директорию примера `storage_call`:

```shell
cd examples/storage_call
```

Запустите стенд через Docker Compose:

```shell
make start
```

Команда развернёт стенд, состоящий из:

* кластера Tarantool DB:
  * 1 роутера;
  * 2 набора реплик по 2 хранилища;
* кластера etcd из 3 узлов;
* 1 узла [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).
Контейнер `init_host` должен успешно завершиться после создания сегментов и применения миграции.
Проверить его вывод можно командой:

```shell
docker compose -f cluster/docker-compose.yml logs init_host
```

Чтобы войти в TCM, откройте [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

* **Username**: `admin`
* **Password**: `secret`

## Создание спейса и подключение к узлу

При запуске стенда применяется миграция
[`001_accounts.lua`](cluster/migrations/scenario/001_accounts.lua).
Она создаёт шардированный спейс `accounts` и две хранимые функции.
`app.get_balance` возвращает баланс счёта, а `app.credit_account` увеличивает
его на указанную сумму и возвращает новый баланс. Изменение выполняется
атомарно. Тела обеих функций сохранены в `box.func`, поэтому функции доступны
после перезапуска хранилища; для них задано `setuid = false`.

Подключиться к роутеру `router-1` можно двумя способами:

* В TCM откройте вкладку **Stateboard**, выберите набор реплик `router-1`, затем узел `router-1` и вкладку **Terminal**.
* В терминале подключитесь с помощью tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Далее выполняйте команды в терминале роутера.

## Подготовка данных

Создайте два счёта. Значение `box.NULL` в позиции `bucket_id` CRUD заменит
вычисленным идентификатором сегмента:

```lua
crud.insert('accounts', {101, box.NULL, 100})
crud.insert('accounts', {202, box.NULL, 200})
```

Функция, объявленная только в `_G`, для `storage_call` не подходит: её нужно
зарегистрировать в `box.func` с сохранённым телом.

## Одиночный вызов

Вызовите функцию чтения, указав спейс и первичный ключ. CRUD вычислит сегмент
по правилу шардирования спейса `accounts`:

```lua
result, err = crud.storage_call('app.get_balance', {101}, {
    space_name = 'accounts',
    key = {101},
})
result.returns[1], err
```

Вывод:

```yaml
---
- 100
- null
...
```

Аргумент `101` передан функции через `args`; `space_name` и `key` служат только
для маршрутизации и в аргументы автоматически не добавляются.

Теперь увеличьте баланс. Изменение внутри функции выполняется в `box.atomic()`:

```lua
result, err = crud.storage_call('app.credit_account', {101, 25}, {
    space_name = 'accounts',
    key = {101},
})
result.returns[1], err
```

Вывод:

```yaml
---
- 125
- null
...
```

Если идентификатор сегмента уже известен, можно указать его напрямую:

```lua
account, err = crud.get('accounts', 101)
bucket_id = account.rows[1][2]
result, err = crud.storage_call('app.get_balance', {101}, {
    bucket_id = bucket_id,
})
result.returns[1], err
```

Вывод:

```yaml
---
- 125
- null
...
```

## Пакетный вызов

`crud.storage_call_many()` принимает массив вызовов. У каждого элемента свои
имя функции, аргументы и маршрут:

```lua
calls = {
    {
        func_name = 'app.credit_account',
        args = {101, 5},
        space_name = 'accounts', key = {101},
    },
    {
        func_name = 'app.credit_account',
        args = {202, 10},
        space_name = 'accounts', key = {202},
    },
    {
        func_name = 'app.credit_account',
        args = {999, 1},
        space_name = 'accounts', key = {999},
    },
}

result, err = crud.storage_call_many(calls, {timeout = 2})
```

Посмотрите результаты успешных вызовов:

```lua
result.results[1].returns[1], result.results[2].returns[1]
```

Вывод:

```yaml
---
- 130
- 210
...
```

Третий вызов завершился ошибкой: счёта с идентификатором `999` нет.
Выведем класс ошибки, её сообщение без служебных деталей и общую ошибку пакета:

```lua
item_error = result.results[3].error
item_error.class_name, item_error.err:match('Account 999 not found'), err
```

Вывод:

```yaml
---
- StorageCallError
- Account 999 not found
- null
...
```

`results[i]` соответствует `calls[i]`, даже если вызовы попали на разные
хранилища. Ошибка третьего элемента не отменяет первые два. Ошибка всего
пакета возвращается отдельно в `err`; в таком случае частичные результаты
не возвращаются.

## Вызов с ограниченными правами

До этого вызовы выполнялись под `admin`. В конфигурации стенда есть пользователь
`storage_call_reader`: он может вызвать `crud.storage_call()` и
`crud.storage_call_many()` через `lua_call`, но не имеет права `execute` на
`universe`. Миграция даёт ему право на чтение спейсов `accounts` и `_bucket`,
а из целевых функций — на вызов только `app.get_balance`.

Право на публичные методы задано в `cluster/config.yml`:

```yaml
credentials:
  users:
    storage_call_reader:
      password: 'secret'
      privileges:
        - permissions: [execute]
          lua_call: [crud.storage_call, crud.storage_call_many]
```

Миграция выдаёт права после создания спейса и функции:

```lua
box.schema.user.grant('storage_call_reader', 'read', 'space',
    'accounts', {if_not_exists = true})
box.schema.user.grant('storage_call_reader', 'execute', 'function',
    'app.get_balance', {if_not_exists = true})
if box.space._bucket ~= nil then
    box.schema.user.grant('storage_call_reader', 'read', 'space',
        '_bucket', {if_not_exists = true})
end
```

В терминале роутера, открытом под `admin`, подключитесь к тому же роутеру от
имени этого пользователя. Используйте `bucket_id`, полученный в разделе
«Одиночный вызов». Команда выполняется внутри контейнера, поэтому для
подключения нужен адрес сервиса `tarantool-router-1:3301`, а не `127.0.0.1:3301`:

```lua
conn = require('net.box').connect('tarantool-router-1:3301', {
    user = 'storage_call_reader', password = 'secret',
})
conn:wait_connected()
```

Вывод:

```yaml
---
- true
...
```

Вызовите функцию чтения:

```lua
result, err = conn:call('crud.storage_call', {
    'app.get_balance', {101}, {bucket_id = bucket_id},
})
result.returns[1], err
```

Вывод:

```yaml
---
- 130
- null
...
```

Чтение разрешено. Попытка вызвать функцию изменения баланса отклоняется,
поскольку пользователю не выдано право `execute` на `app.credit_account`:

```lua
result, err = conn:call('crud.storage_call', {
    'app.credit_account', {101, 1}, {bucket_id = bucket_id},
})
result, err.err
```

Вывод:

```yaml
---
- null
- 'Failed to execute function "app.credit_account": Execute access to function ''app.credit_account''
  is denied for user ''storage_call_reader'''
...
```

В пакетном вызове ошибка доступа относится только к запрещённому элементу:

```lua
batch, err = conn:call('crud.storage_call_many', {{
    {func_name = 'app.get_balance', args = {101}, bucket_id = bucket_id},
    {func_name = 'app.credit_account', args = {101, 1}, bucket_id = bucket_id},
}})
batch.results[1].returns[1], err
```

Вывод:

```yaml
---
- 130
- null
...
```

Ошибка второго элемента не остановила первый вызов:

```lua
batch.results[2].error.err
```

Вывод:

```yaml
---
- 'Failed to execute function "app.credit_account": Execute access to function ''app.credit_account''
  is denied for user ''storage_call_reader'''
...
```

Закройте соединение:

```lua
conn:close()
```

Публичные методы CRUD доступны по праву `lua_call`; записи
`box.func['crud.storage_call']` для них не требуются. Целевая функция,
напротив, должна быть зарегистрирована в `box.func`, а вызывающему
пользователю нужны `execute` на неё и права на используемые ею спейсы.

## Повтор вызова

Тайм-аут клиента не отменяет уже запущенную функцию. Если ответ потерян,
изменение могло сохраниться. `app.credit_account` в этом учебном примере
не защищена от повторного применения: не повторяйте её автоматически после
неоднозначной ошибки. В рабочей изменяющей функции используйте идентификатор
операции и сохраняйте его вместе с изменением.

Подробнее об API: [`crud.storage_call()` и `crud.storage_call_many()`](https://www.tarantool.io/docs/tdb/ru/3_x/reference/api_reference/crud#reference_lua-crud_storage_call).

## Остановка стенда

```shell
make stop
```
