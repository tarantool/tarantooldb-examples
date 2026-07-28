# Запись и получение данных в словаре

В этом руководстве показано, как записать в словарь данные, а затем получить запись из базы данных с обогащением из словаря.
Для примера используется база данных с категориями денежных трат.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда и подключение к узлу](#запуск-стенда-и-подключение-к-узлу)
* [Запись данных в словарь](#запись-данных-в-словарь)
* [Подготовка нормализованных данных](#подготовка-нормализованных-данных)
* [Чтение данных с обогащением из словаря](#чтение-данных-с-обогащением-из-словаря)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* исходные файлы примера `dictionary`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `dictionary` расположен в директории `examples/dictionary`.
>  * Отдельный архив [dictionary.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fdictionary&filename=dictionary), скачанный из этого репозитория.

## Запуск стенда и подключение к узлу

Для успешного запуска должны быть свободны порты:

* 3301—3306;
* 8081—8086.

Перейдите в папку с примером `dictionary` и запустите стенд:

```shell
cd examples/dictionary
docker compose up -d
```

Команда развернет стенд, который состоит из:
* кластера Tarantool DB из двух шардов и двух роутеров;
* кластера etcd для работы восстановления после сбоев (failover) кластера Tarantool DB.

После запуска должны работать все контейнеры, кроме `user-host`.

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.

Перейдите на вкладку **Space Explorer** и выберите любой узел, например `storage-1-msk`.
Проверьте, что на узле есть следующие спейсы:

* `dictionary_data`;
* `dictionary_vclock`;
* `money_moves`.

## Запись данных в словарь

Подключитесь к одному из роутеров с помощью команды `tt connect`:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

В примере ниже задается словарь с названием `categories`, который содержит категории денежных трат.
С помощью функции [dictionary_router.set()](https://www.tarantool.io/docs/tdb/ru/1_x/reference/api_reference/dictionary#reference_lua-dictionary_router-set) запишите несколько элементов ('Shops','Med' и другие) с соответствующими им ключами в словарь:

```lua
dictionary_router.set('categories', '1', 'Shops')
dictionary_router.set('categories', '2', 'Food delivery')
dictionary_router.set('categories', '3', 'Transport')
dictionary_router.set('categories', '4', 'Bills')
dictionary_router.set('categories', '5', 'Med')
```

> [!NOTE]
> Ключ элемента в словаре может быть только строкой.

Чтобы проверить записанные в словарь данные, используйте метод [dictionary_router.get()](https://www.tarantool.io/docs/tdb/ru/1_x/reference/api_reference/dictionary#reference_lua-dictionary_router-get):

```lua
dictionary_router.get('categories', '1')
```

## Подготовка нормализованных данных

Чтобы записать нормализованные данные, выполните следующий код:

```lua
crud.replace('money_moves', {1, box.NULL, 123, require('datetime').now(), '1', false, 260.01})
crud.replace('money_moves', {2, box.NULL, 123, require('datetime').now(), '2', false, 1234.56})
crud.replace('money_moves', {3, box.NULL, 123, require('datetime').now(), '5', false, 1176.12})
crud.replace('money_moves', {4, box.NULL, 123, require('datetime').now(), '3', false, 30})
crud.replace('money_moves', {5, box.NULL, 123, require('datetime').now(), '3', false, 35})
crud.replace('money_moves', {6, box.NULL, 123, require('datetime').now(), '4', false, 11816.86})
crud.replace('money_moves', {7, box.NULL, 123, require('datetime').now(), '3', false, 218})
crud.replace('money_moves', {8, box.NULL, 123, require('datetime').now(), '1', false, 1026.45})
crud.replace('money_moves', {9, box.NULL, 123, require('datetime').now(), '1', false, 384.32})
crud.replace('money_moves', {10, box.NULL, 123, require('datetime').now(), '2', false, 890.99})
```

Чтобы проверить записанные данные, используйте метод `crud.get()`:

```lua
crud.get('money_moves', 1)
```

## Чтение данных с обогащением из словаря

Чтобы получить запись с добавленной информацией из словаря, выполните следующую команду:

```lua
box.schema.func.call('get_money_move', 1)
```

## Остановка стенда

Чтобы остановить стенд, выполните следующую команду:

```shell
docker compose down
```
