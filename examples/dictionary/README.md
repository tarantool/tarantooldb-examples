# Использование словарей

Тестовый стенд представляет собой:
* кластер Tarantool DB из двух шардов и двух роутеров
* кластер ETCD для работы файловера кластера Tarantool DB.

В примере разобрано как работать со словарями.

Дополнительные материалы по словарям - см. [здесь](../../DICTIONARY.md).

Для этого примера понадобятся:
* Docker-образ TarantoolDB ([установить](../../INSTALL.md))
* Docker compose
* [TT CLI](../../../README.md#интерфейс-командной-строки-%28cli%29)

## Запуск стенда
Предварительно должен быть установлен [docker-образ Tarantool DB](../../INSTALL.md). 

Для успешного запуска должны быть свободны порты:
* 3301 .. 3306
* 8081 .. 8086

Запуск стенда производится командой:
```shell
cd ./doc/examples/go_crud/tt
docker compose up -d
```

После запуска должны работать все контейнеры, кроме `tarantool-db-init`. Также
после запуска доступна админка кластера Tarantool DB по адресу: http://localhost:8081

Откройте админку кластера и визуально убедитесь, что нет каких либо предупреждений,
или ошибок. Сразу после старта в течении нескольких секунд могут быть предупреждения,
так как кластер поднимается.

В левой панели откройте "Space Explorer" и выберите любой узел, например `storage-1-msk`.
В нём должны существовать спейсы (таблички):
* dictionary_data
* dictionary_vclock
* money_moves

## Запись в словари
Подключимся к одному из роутеров:
```shell
./tt connect admin:secret-cluster-cookie@localhost:3301
```

Выполните на роутере следующий код:
```lua
dictionary_router.set('categories', '1', 'Магазинчики')
dictionary_router.set('categories', '2', 'Доставка еды')
dictionary_router.set('categories', '3', 'Проезд')
dictionary_router.set('categories', '4', 'Коммунальные платежи')
dictionary_router.set('categories', '5', 'Медицина')
```

> *Памятка*
> 
> Идентификатор записи в словаре строковый

Мы выполнили запись данных в словарь `categories`. Можно протестировать
запись выполнив:
```lua
dictionary_router.get('categories', '1')
```

## Подготовка нормализованных данных

Выполните следующий код:
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

Мы записали нормализованные пользовательские данные. Можно проверить запись
выполнив:
```lua
crud.get('money_moves', 1)
```

## Чтение данных с обогащением из словаря
Выполните следующую команду:
```lua
box.schema.func.call('get_money_move', 1)
```

В результате будет получена запись с добавленной информацией из словаря.

## Остановка стенда
Для остановки стенда выполните команду:
```shell
docker compose down
```
