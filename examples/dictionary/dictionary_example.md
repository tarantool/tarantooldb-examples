(user_guide-dictionary_example)=
# Запись и получение данных в словаре

В этом руководстве показано, как записать в словарь данные, а затем получить запись из базы данных с обогащением из словаря.
Для примера используется база данных с категориями денежных трат.

Содержание:

* [](user_guide-dictionary_example-prereq)
* [](user_guide-dictionary_example-start_example)
* [](user_guide-dictionary_example-write_data)
* [](user_guide-dictionary_example-prepare_data)
* [](user_guide-dictionary_example-read_data)
* [](user_guide-dictionary_example-stop_example)

(user_guide-dictionary_example-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* исходные файлы примера `dictionary`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `dictionary` расположен в таком архиве в директории `./doc/examples/dictionary/`.
    
  * Отдельный архив [dictionary.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/dictionary/dictionary.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-dictionary_example-start_example)=
## Запуск стенда и подключение к узлу 

Для успешного запуска должны быть свободны следующие порты:

* 3301--3306
* 8081--8086

Перейдите в папку с примером `dictionary` и запустите стенд:

```shell
cd ./doc/examples/dictionary
docker compose up -d
```

Команда развернет стенд, который состоит из:
* кластера Tarantool DB (2 роутера, 2 набора реплик по 2 хранилища);
* кластера etcd для работы восстановления после сбоев (failover) кластера Tarantool DB.

После запуска должны работать все контейнеры, кроме `user-host`. 

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.

Перейдите на вкладку **Space Explorer** и выберите любой узел, например, `storage-1-msk`.
Проверьте, что на узле есть следующие спейсы:

* `dictionary_data`;
* `dictionary_vclock`;
* `money_moves`.

(user_guide-dictionary_example-write_data)=
## Запись данных в словарь

Подключитесь к одному из роутеров с помощью команды `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```
 
В примере ниже задается словарь с названием `categories`, который содержит категории денежных трат.
С помощью функции [dictionary_router_set()](reference_lua-dictionary-set) запишите несколько элементов ('Shops','Med' и другие) с соответствующими им ключами в словарь:

```lua
dictionary_router.set('categories', '1', 'Shops')
dictionary_router.set('categories', '2', 'Food delivery')
dictionary_router.set('categories', '3', 'Transport')
dictionary_router.set('categories', '4', 'Bills')
dictionary_router.set('categories', '5', 'Med')
```

```{admonition} Примечание
:class: note

Ключ элемента в словаре может быть только строкой.
```

Чтобы проверить записанные в словарь данные, используйте метод [dictionary_router_get()](reference_lua-dictionary-get), например:

```lua
dictionary_router.get('categories', '1')
```

(user_guide-dictionary_example-prepare_data)=
## Подготовка нормализованных данных

Чтобы записать нормализованные данные, выполните следующий код:

```lua
crud.replace('money_moves', {1, box.NULL, 123, require('datetime').now(), '1', false, 260.01})
crud.replace('money_moves', {2, box.NULL, 123, require('datetime').now(), '2', false, 1234.56})
crud.replace('money_moves', {2, box.NULL, 123, require('datetime').now(), '3', false, 30})
crud.replace('money_moves', {3, box.NULL, 123, require('datetime').now(), '5', false, 1176.12})
crud.replace('money_moves', {4, box.NULL, 123, require('datetime').now(), '3', false, 30})
crud.replace('money_moves', {5, box.NULL, 123, require('datetime').now(), '3', false, 35})
crud.replace('money_moves', {6, box.NULL, 123, require('datetime').now(), '4', false, 11816.86})
crud.replace('money_moves', {7, box.NULL, 123, require('datetime').now(), '3', false, 218})
crud.replace('money_moves', {8, box.NULL, 123, require('datetime').now(), '1', false, 1026.45})
crud.replace('money_moves', {9, box.NULL, 123, require('datetime').now(), '1', false, 384.32})
crud.replace('money_moves', {10, box.NULL, 123, require('datetime').now(), '2', false, 890.99})
```

Чтобы проверить записанные данные, используйте метод `crud.get()`, например:

```lua
crud.get('money_moves', 1)
```

(user_guide-dictionary_example-read_data)=
## Чтение данных с обогащением из словаря

Чтобы получить запись с добавленной информацией из словаря, выполните следующую команду:

```lua
box.schema.func.call('get_money_move', 1)
```

(user_guide-dictionary_example-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
