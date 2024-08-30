(user_guide-expirationd_example)=
# Проверка устаревших кортежей в спейсе

В этом руководстве описано, как настроить параметры устаревания данных в конфигурации,
чтобы удалять все кортежи в спейсе, которые старше заданного времени.

Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](user_guide-expirationd).

Руководство включает следующие шаги:

* [](user_guide-expirationd_example-prereq)
* [](user_guide-expirationd_example-start_example)
* [](user_guide-expirationd_example-migration)
* [](user_guide-expirationd_example-add_data)
* [](user_guide-expirationd_example-config)
* [](user_guide-expirationd_example-functions)
* [](user_guide-expirationd_example-stop_example)

(user_guide-expirationd_example-prereq)=
## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* утилита [TT CLI](install-install_tt);
* исходные файлы примера `expirationd`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `expirationd` расположен в таком архиве в директории `./doc/examples/expirationd/`.
    
  * Отдельный архив [expirationd.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/expirationd/expirationd.tar.gz), скачанный c сайта Tarantool.
  ```
  
(user_guide-expirationd_example-start_example)=
## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd`:

```shell
cd ./doc/examples/expirationd/
```

Запустите кластер:

```shell
docker compose up -d
```

(user_guide-expirationd_example-migration)=
## Описание миграции

В руководстве используется миграция из файла `./bootstrap/migrations/source/001_test.lua` примера `expirationd`.
В этой миграции создан спейс `messages` со следующим форматом:

```{literalinclude} bootstrap/migrations/source/001_test.lua
:start-after: -- создание спейса messages
:end-before: utils.register_sharding_key
:language: lua
:dedent:
```

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

Смотрите также: [](user_guide-expirationd_user_logic).

(user_guide-expirationd_example-add_data)=
## Подключение к узлу и загрузка тестовых данных

Подключитесь к экземпляру, используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Создайте тестовые данные в спейсе:

```lua
crud.insert_object('test', {id = 1, dt = require('datetime').now(), data = 'too'})
crud.insert_object('test', {id = 2, dt = require('datetime').now(), data = 'foo'})
crud.insert_object('test', {id = 3, dt = require('datetime').now(), data = 'bar'})
```

Посмотреть записи можно в веб-интерфейсе во вкладке **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)).
Через заданное в настройках время (15 секунд) записи будут удалены.

(user_guide-expirationd_example-config)=
## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:
   
```yaml
task_name1:
  space: test
  options:
    args:
      lifetime_in_seconds: 5
      time_create_field: dt
```

Здесь:
  
* `task_name1` -- название задачи по устареванию данных;
  * `space` -- название спейса, по которому идет поиск устаревших кортежей;
  * `options.args` -- дополнительные опции конфигурации:
    * `lifetime_in_seconds` -- время жизни записи (кортежа) в секундах;
    * `time_create_field` -- проверяемое поле.
    
Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](configuration_reference-expirationd).

(user_guide-expirationd_example-stop_example)=
## Остановка кластера

Чтобы остановить кластер, выполните следующую команду:

```shell
docker compose down
```

