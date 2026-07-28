# Автоматическое удаление устаревших кортежей из спейса

В этом руководстве описано, как настроить параметры устаревания данных в конфигурации,
чтобы автоматически удалять все кортежи в спейсе, которые старше заданного времени.
Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](https://www.tarantool.io/docs/tdb/ru/2_x/user_guide/expirationd).

Руководство включает следующие шаги:

* [Пререквизиты](#пререквизиты)
* [Запуск кластера](#запуск-кластера)
* [Описание миграции](#описание-миграции)
* [Подключение к узлу и загрузка тестовых данных](#подключение-к-узлу-и-загрузка-тестовых-данных)
* [Конфигурация устаревания данных](#конфигурация-устаревания-данных)
* [Остановка кластера](#остановка-кластера)

## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install_tt);
* исходные файлы примера `expirationd`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `expirationd` расположен в директории `examples/expirationd`.
>  * Отдельный архив [expirationd.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Fexpirationd&filename=expirationd), скачанный из этого репозитория.

## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 2379
* 3301 .. 3308
* 8081

Перейдите в папку с примером `expirationd`:

```shell
cd examples/expirationd
```

Запустите кластер:

```shell
make start
```

Запущенный стенд состоит из:
- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- кластера etcd из 3 узлов;
- одного узла [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `messages`:

```lua
box.space
```

Спейс `messages` должен присутствовать в выводе, он создается при запуске кластера.

## Описание миграции

В руководстве используется миграция из файла `./cluster/migrations/scenario/001_test.lua` примера `expirationd`.
В этой миграции создан спейс `messages` со следующим форматом:

```lua
local s = box.schema.space.create('messages', {if_not_exists = true})
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

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** — через TCM. Для этого:

1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Во вкладке **Terminal** добавьте тестовые данные в спейс:

```lua
crud.insert_object('messages', {id = 1, dt = require('datetime').now(), data = 'too'})
crud.insert_object('messages', {id = 2, dt = require('datetime').now(), data = 'foo'})
crud.insert_object('messages', {id = 3, dt = require('datetime').now(), data = 'bar'})
```

Чтобы просмотреть кортежи в спейсе `messages`, в веб-интерфейсе TCM перейдите на вкладку **Tuples** и выберите в списке спейс `messages`.
Откроется новая вкладка с содержимым кортежей спейса `messages`.
Кортежи будут удалены спустя заданное в настройках время — 15 секунд.

## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:

```yaml
roles_cfg:
  roles.expirationd:
    task_name1:
      space: messages
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

Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](https://www.tarantool.io/docs/tdb/ru/2_x/reference/configuration_reference#configuration_reference-expirationd).

## Остановка кластера

Чтобы остановить кластер, выполните в локальном терминале следующую команду:

```shell
make stop
```
