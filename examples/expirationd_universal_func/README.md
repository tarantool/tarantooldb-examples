# Проверка устаревших кортежей с помощью универсальной функции

Доступно с версии [1.2.0](https://www.tarantool.io/docs/tdb/ru/1_x/releases/changelog#releases-changelog_1_2_0).

В этом руководстве описано, как включить роль `expirationd` и настроить параметры устаревания данных в конфигурации,
чтобы удалять из спейсов все кортежи, которые старше заданного времени.
В отличие от примера [expirationd](../expirationd/README.md), здесь для проверки и обработки устаревших кортежей во всех спейсах используется одна универсальная функция `is_tuple_expired`.

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
* исходные файлы примера `expirationd_universal_func`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `expirationd_universal_func` расположен в директории `examples/expirationd_universal_func`.
>  * Отдельный архив [expirationd_universal_func.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fexpirationd_universal_func&filename=expirationd_universal_func), скачанный из этого репозитория.

## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd_universal_func`:

```shell
cd examples/expirationd_universal_func
```

Запустите кластер:

```shell
docker compose up -d
```

## Описание миграции

В руководстве используется миграция из файла `./bootstrap/migrations/source/001_test.lua` примера `expirationd_universal_func`.
В этой миграции:
- созданы три спейса: `space_too`, `space_foo`, `space_bar`;
- создана персистентная универсальная функция `is_tuple_expired`, проверяющая устаревание данных в спейсах;
- созданы тестовые функции для генерации данных:
   - `generate_data_start` — запуск фоновой записи тестовых данных в спейсы;
   - `generate_data_stop` — остановка фоновой записи тестовых данных в спейсы.

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

## Подключение к узлу и загрузка тестовых данных

Подключитесь к экземпляру, используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

```shell
tt connect admin:secret-cluster-cookie@localhost:3300
```

Загрузите тестовые данные в спейсы, используя функцию `generate_data_start`:

```lua
localhost:3300> box.schema.func.call('generate_data_start')
```

Для примера достаточно 100-200 записей в спейсе.
Посмотреть количество записей можно в веб-интерфейсе во вкладке **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)).

Когда записей в спейсе станет достаточно, отключите генерацию данных с помощью функции `generate_data_stop`:

```lua
localhost:3300> box.schema.func.call('generate_data_stop')
```

## Конфигурация устаревания данных

Включите роль `expirationd` на хранилищах. Это можно сделать двумя способами:

* в терминале с помощью следующей команды:

  ```shell
  curl -sd @activate_expirationd.json http://localhost:8081/admin/api | jq
  ```
* в веб-интерфейсе Tarantool DB.
  Для этого перейдите на вкладку **Cluster**, выберите нужный набор реплик, например `tarantool-storage1`, и нажмите на значок карандаша (**Edit replica set**).
  В открывшемся окне редактирования выберите роль `expirationd` в секции **Roles**.

Теперь задайте конфигурацию для `expirationd`.
Для этого:

1. В веб-интерфейсе Tarantool DB перейдите на вкладку **Code** ([http://localhost:8081/admin/cluster/code](http://localhost:8081/admin/cluster/code)).
2. Создайте файл `expirationd.yml`. В нем будет задана конфигурация устаревания данных.

    ![Конфигурация устаревания данных](expirationd_config.png)

3. Добавьте в файл следующую конфигурацию:

    ```yaml
    space_too_expiration:
        space: space_too
        is_expired: is_tuple_expired
        is_master_only: true
        options:
            tuples_per_iteration: 100
            args:
                seconds: 5
                date_field_name: create_date
    space_foo_expiration:
        space: space_foo
        is_expired: is_tuple_expired
        is_master_only: true
        options:
            tuples_per_iteration: 100
            args:
                seconds: 5
                date_field_name: dt
    space_bar_expiration:
        space: space_bar
        is_expired: is_tuple_expired
        is_master_only: true
        options:
            tuples_per_iteration: 100
            args:
                seconds: 5
                date_field_name: create_at
    ```

    Здесь:

    * `space_too_expiration` — название задачи по устареванию данных;
      * `space` — название спейса, по которому идет поиск устаревших кортежей;
      * `is_expired` — название функции, которая получает кортеж и проверяет его срок жизни;
      * `is_master_only` — экспирация запущена только на master-узлах;
      * `options` — дополнительные опции конфигурации:
        * `tuples_per_iteration` — количество кортежей, которое проверяется за одну итерацию;
        * `args` — дополнительные аргументы, передаваемые в функцию `is_tuple_expired`;
          * `seconds` — количество секунд, после истечения которых кортеж считается устаревшим;
          * `date_field_name` — название поля с меткой времени.

    Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](https://www.tarantool.io/docs/tdb/ru/1_x/reference/configuration_reference#configuration_reference-expirationd).

4. Нажмите кнопку **Apply**.
5. Убедитесь, что количество сгенерированных кортежей начинает сокращаться.
   Для этого откройте веб-интерфейс Tarantool DB на вкладке **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)) и выберите произвольное хранилище.

## Остановка кластера

Чтобы остановить кластер, выполните следующую команду:

```shell
docker compose down
```
