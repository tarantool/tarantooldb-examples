# Автоматическое удаление устаревших кортежей из спейса

Доступно с версии 1.2.0.

В этом руководстве описано, как настроить параметры устаревания данных в конфигурации,
чтобы автоматически удалять все кортежи в спейсе, которые старше заданного времени.
Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/expirationd).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск кластера](#запуск-кластера)
* [Описание миграции](#описание-миграции)
* [Подключение к узлу и загрузка тестовых данных](#подключение-к-узлу-и-загрузка-тестовых-данных)
* [Конфигурация устаревания данных](#конфигурация-устаревания-данных)
* [Остановка кластера](#остановка-кластера)

## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [TT CLI](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install_tt);
* исходные файлы примера `expirationd`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `expirationd` расположен в директории `examples/expirationd`.
>  * Отдельный архив [expirationd.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fexpirationd&filename=expirationd), скачанный из этого репозитория.

## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd`:

```shell
cd examples/expirationd
```

Запустите кластер:

```shell
docker compose up -d
```

## Описание миграции

В руководстве используется миграция из файла `./bootstrap/migrations/source/001_test.lua` примера `expirationd`.
В этой миграции создан спейс `test` со следующим форматом:

```lua
local s = box.schema.space.create('test', {if_not_exists = true})
s:format({
    { name = 'id', type = 'number' },
    { name = 'bucket_id', type = 'unsigned' },
    { name = 'dt', type = 'datetime' },
    { name = 'data', type = 'any' },
})
s:create_index('pk', { parts = {'id'}, if_not_exists = true})
s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
```

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

Смотрите также: [Проверка устаревших кортежей в спейсе с помощью пользовательских функций](../expirationd_user_logic/README.md).

## Подключение к узлу и загрузка тестовых данных

Подключитесь к экземпляру, используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Добавьте тестовые данные в спейс:

```lua
crud.insert_object('test', {id = 1, dt = require('datetime').now(), data = 'too'})
crud.insert_object('test', {id = 2, dt = require('datetime').now(), data = 'foo'})
crud.insert_object('test', {id = 3, dt = require('datetime').now(), data = 'bar'})
```

Посмотреть записи можно в веб-интерфейсе во вкладке **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)).
Записи будут удалены спустя заданное в настройках время — 15 секунд.

## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:

```yaml
expirationd:
  task_name1:
    space: test
    options:
      args:
        lifetime_in_seconds: 15
        time_create_field: dt
```

Здесь:

* `task_name1` — название задачи по устареванию данных;
  * `space` — название спейса, по которому идет поиск устаревших кортежей;
  * `options.args` — дополнительные опции конфигурации:
    * `lifetime_in_seconds` — время жизни кортежа в секундах;
    * `time_create_field` — название поля, по которому проверяется время жизни кортежа.

Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](https://www.tarantool.io/docs/tdb/ru/1_x/reference/configuration_reference#configuration_reference-expirationd).

## Остановка кластера

Чтобы остановить кластер, выполните следующую команду:

```shell
docker compose down
```
