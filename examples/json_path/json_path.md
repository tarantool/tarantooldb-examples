(user_guide-json_path)=
# JSON-пути

В этом руководстве показано, как обновлять данные в спейсе через [JSON-пути](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/json_paths/).

Содержание:

* [](user_guide-json_path-prereq)
* [](user_guide-json_path-start_example)
* [](user_guide-json_path-files)
* [](user_guide-json_path-work_with_data)
* [](user_guide-json_path-stop_example)

(user_guide-json_path-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `json_path`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `json_path` расположен в таком архиве в директории `./doc/examples/json_path/`.
    
  * Отдельный архив [json_path.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/json_path/json_path.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-json_path-start_example)=
## Запуск стенда

Перейдите в директорию примера `json_path`:

```shell
cd ./doc/examples/json_path/
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 1 роутер-хранилище;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `router-storage-1` узел `router-storage-1` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```box.space```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

(user_guide-json_path-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `json_path`:

* `cluster/` -- директория c файлами для запуска кластера Tarantool DB:
  * `config.yml` -- конфигурация и топология кластера;
  * `docker-compose.yml` -- описание узлов кластера Tarantool DB;
  * `migrations/scenario` -- директория, содержащая файлы с описанием [миграций](user_guide-migrations);
* `tools/` -- директория с файлами для запуска кластера etcd и TCM:
  * `docker-compose.yml` -- описание узлов кластера etcd;
  * `tcm.yml` -- конфигурация для запуска [Tarantool Cluster Manager](https://www.tarantool.io/ru/doc/latest/tooling/tcm/).

(user_guide-json_path-work_with_data)=
## Работа с данными

В примере создан спейс `test` со следующим форматом:

```{literalinclude} cluster/migrations/scenario/001_test.lua
:start-at: local space_test
:end-before: return true
:language: lua
:dedent:
```

Чтобы подключиться к роутеру, в веб-интерфейсе TCM перейдите на вкладку **Stateboard**.
В наборе реплик `router-storage-1` выберите роутер `router-storage-1` и в открывшемся окне перейдите на вкладку **Terminal**.

Создайте кортеж и добавьте его в спейс `test`:

```lua
s = box.space.test
t = { 1, 1, {  key1 = 'value', key2 = 10 }, { 2, 3 , { key3 = 20 }}}
t = s:replace(t)
```

Проверьте, что в спейсе появились данные.
Для этого в TCM перейдите на вкладку **Tuples** и выберите в списке спейс `test`.
В открывшейся вкладке видно, что в спейс добавлен новый кортеж.

Чтобы заменить значение одного ключа на другое, обновите в кортеже значение поля `users.key1`:

```lua
s:update({1}, {{'=', 'users.key1', 'new_value'}})
```

Вывод будет выглядеть так:

```shell
---
- [1, 1, {'key1': 'new_value', 'key2': 10}, [2, 3, {'key3': 20}]]
...
```

Теперь увеличьте на 1 значение второго элемента из массива `authors`.
Массив `authors` имеет формат `{ name = 'authors', type = 'array' }`. Сейчас в массив записано значение `[2, 3, {'key3': 20}]`.

```lua
s:update({1}, {{'+', 'authors[2]', 1}})
```

Вывод будет выглядеть так:

```shell
---
- [1, 1, {'key1': 'new_value', 'key2': 10}, [2, 4, {'key3': 20}]]
...
```

Теперь добавьте данные в кортеж внутри спейса по ключу:

```lua
s:update({1}, {{'!', 'payload', 'inserted_value'}})
```

В схеме уже есть поле `payload` со следующим форматом: `{ name = 'payload', type = 'string', is_nullable = true }`.

Вывод выглядит так:
```shell
---
- [1, 1, {'key1': 'new_value', 'key2': 10}, [2, 4, {'key3': 20}], 'inserted_value']
...
```

Теперь удалите из кортежа значение поля `users.key2` и добавьте в поле `authors` новый ключ `key4`:

```lua
s:update({1}, {{'#', '[3].key2', 1}, {'=', '[4][3].key4', 'value4'}})
```

Вывод выглядит так:

```shell
---
- [1, 1, {'key1': 'new_value'}, [2, 4, {'key3': 20, 'key4': 'value4'}], 'inserted_value']
...
```

После обновите значение кортежа и просмотрите результат:

```lua
s:upsert({1, 1, {k = 'v'}, {}}, {{'#', '[3].key1', 1}})
s:select{}
```

Вывод выглядит так:

```shell
---
- - [1, 1, {}, [2, 4, {'key3': 20, 'key4': 'value4'}], 'inserted_value']
...
```

(user_guide-json_path-stop_example)=
## Остановка кластера

Чтобы остановить кластер, выполните в локальном терминале следующую команду:

```shell
make stop
```
