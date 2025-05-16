(user_guide-expirationd_universal_func)=
# Проверка устаревших кортежей с помощью универсальной функции

Доступно с версии [1.2.0](releases-changelog_1.2.0).

В этом руководстве описано, как включить роль `expirationd` и настроить параметры устаревания данных в конфигурации,
чтобы удалять из спейсов все кортежи, которые старше заданного времени.
В отличие от примера [expirationd](user_guide-expirationd_example), здесь для проверки и обработки устаревших кортежей во всех спейсах используется одна универсальная функция `is_tuple_expired`.

Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](user_guide-expirationd).

Руководство включает следующие шаги:

* [](user_guide-expirationd_universal_func-prereq)
* [](user_guide-expirationd_universal_func-start_example)
* [](user_guide-expirationd_universal_func-migration)
* [](user_guide-expirationd_universal_func-add_data)
* [](user_guide-expirationd_universal_func-config)
* [](user_guide-expirationd_universal_func-stop_example)

(user_guide-expirationd_universal_func-prereq)=
## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* утилита [TT CLI](install-install_tt);
* исходные файлы примера `expirationd_universal_func`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:
  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `expirationd_universal_func` расположен в таком архиве в директории `./doc/examples/expirationd_universal_func/`.
    
  * Отдельный архив [expirationd_universal_func.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/expirationd_universal_func/expirationd_universal_func.tar.gz), скачанный c сайта Tarantool.
  ```
  
(user_guide-expirationd_universal_func-start_example)=
## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd_universal_func`:

``` shell
cd ./doc/examples/expirationd_universal_func/
```

Запустите кластер:

``` shell
docker compose up -d
```

(user_guide-expirationd_universal_func-migration)=
## Описание миграции

В руководстве используется миграция из файла `./bootstrap/migrations/source/001_test.lua` примера `expirationd_universal_func`.
В этой миграции:
- созданы три спейса: `space_too`, `space_foo`, `space_bar`;
- создана персистентная универсальная функция `is_tuple_expired`, проверяющая устаревание данных в спейсах;
- созданы тестовые функции для генерации данных:
   - `generate_data_start` -- запуск фоновой записи тестовых данных в спейсы;
   - `generate_data_stop` -- остановка фоновой записи тестовых данных в спейсы.

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

(user_guide-expirationd_universal_func-add_data)=
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

(user_guide-expirationd_universal_func-config)=
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
2. Создайте файл `expiration.yml`. В нем будет задана конфигурация устаревания данных.

    ![add_config](expirationd_config.png)

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
    
    * `space_too_expiration` -- название задачи по устареванию данных;
      * `space` -- название спейса, по которому идет поиск устаревших кортежей;
      * `is_expired` -- название функции, которая получает кортеж и проверяет его срок жизни;
      * `is_master_only` -- экспирация запущена только на master-узлах;
      * `options` -- дополнительные опции конфигурации:
        * `tuples_per_iteration` -- количество кортежей, которое проверяется за одну итерацию;
        * `args` -- дополнительные аргументы, передаваемые в функцию `is_tuple_expired`;
          * `seconds` -- количество секунд, после истечения которых кортеж считается устаревшим;
          * `date_field_name` -- название поля с меткой времени.
    
    Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](configuration_reference-expirationd).

4. Нажмите кнопку **Apply**.
5. Убедитесь, что количество сгенерированных кортежей начинает сокращаться.
   Для этого откройте веб-интерфейс Tarantool DB на вкладке **Space explorer** ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)) и выберите произвольное хранилище.

(user_guide-expirationd_universal_func-stop_example)=
## Остановка кластера

Чтобы остановить кластер, выполните следующую команду:

```shell
docker compose down
```
