(user_guide-expirationd)=
# Устаревание данных

Модуль [`expirationd`](https://github.com/tarantool/expirationd) позволяет контролировать время жизни кортежей в спейсе и
обрабатывать кортежи, время жизни которых истекло.

Модуль работает в фоновом режиме и выполняет:
- обход заданных спейсов по индексу с заданной периодичностью;
- проверяет срок жизни кортежа с помощью функции `is_tuple_expired`;
- удаляет устаревшие записи.

В Tarantool DB модуль доступен в виде технологической роли [expirationd](reference-roles-expirationd).

```{admonition} Важно
:class: warning

Персистентные функции, которые нужны для работы модуля, нужно объявить перед применением конфигурации для роли `expirationd`.
Это означает, что сначала применяют миграции с функциями, а затем включают роли. 
```

В этом руководстве описано, как включить роль `expirationd` и настроить параметры устаревания данных в конфигурации,
чтобы удалять все кортежи в спейсе, которые старше заданного времени.

Руководство включает следующие шаги:

* [](user_guide-expirationd-prereq)
* [](user_guide-expirationd-start_example)
* [](user_guide-expirationd-migration)
* [](user_guide-expirationd-add_data)
* [](user_guide-expirationd-config)
* [](user_guide-expirationd-functions)
* [](user_guide-expirationd-stop_example)

(user_guide-expirationd-prereq)=
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
    Пример `expirationd` расположен в таком архиве в директории `./doc/examples/expirationd_universal_func/`.
    
  * Отдельный архив [expirationd.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/expirationd_universal_func/expirationd.tar.gz), скачанный c сайта Tarantool.
  ```
  
(user_guide-expirationd-start_example)=
## Запуск кластера и подключение к узлу

Для успешного запуска кластера должны быть свободны следующие порты:

* 3300 .. 3304
* 8080 .. 8084

Перейдите в папку с примером `expirationd_universal_func` и запустите кластер:

``` shell
cd ./doc/examples/expirationd_universal_func/
docker compose up -d
```

Подключитесь к экземпляру, используя команду `tt connect`.
Команда открывает интерактивную консоль Tarantool, позволяющую работать с базой данных:

``tt connect admin:secret-cluster-cookie@localhost:3300``

(user_guide-expirationd-migration)=
## Описание миграции

В руководстве используется миграция из файла `./bootstrap/migrations/source/001_test.lua` примера `expirationd_universal_func`.
В этой миграции:
- создаётся три спейса:
  - space_too
  - space_foo
  - space_bar
- создаётся персистентная функция проверяющая устаревание данных -- `is_tuple_expired`;
- создаются тестовые функции для генерации данных -- `generate_data_start`, `generate_data_stop`.

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

(user_guide-expirationd-add_data)=
## Загрузка тестовых данных

Для демонстрации работы модуля `expirationd` используются следующие функции:

* `generate_data_start` -- запуск фоновой записи тестовых данных в спейсы;
* `generate_data_stop` -- остановка фоновой записи тестовых данных в спейсы.

После подключения к узлу добавьте тестовые данные, вызвав функцию `_start_messages_stream`:

```lua
localhost:3300> box.schema.func.call('generate_data_start')
```

Посмотреть количество записей можно с помощью модуля [space-explorer](http://localhost:8081/admin/space-explorer/hosts).


(user_guide-expirationd-config)=
## Конфигурация устаревания данных

Включите роль `expirationd` на хранилищах. Это можно сделать двумя способами:

* в терминале с помощью следующей команды:

  ```bash
  curl -sd @activate_expirationd.json http://localhost:8081/admin/api | jq
  ```
* в веб-интерфейсе во вкладке **Cluster** открыть окно редактирования хранилищ (**Edit replica set**) и выбрать эту роль в секции **Roles**.

Теперь задайте конфигурацию для `expirationd`.
Сделать это можно через веб-интерфейс Tarantool DB по адресу [http://localhost:8081/admin/cluster/code](http://localhost:8081/admin/cluster/code):

1. В веб-интерфейсе Tarantool DB перейдите на вкладку **Code**.
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
          * `seconds` -- через сколько секунд тапл будет считаться устаревшим;
          * `date_field_name` -- название поля с меткой времени.
    
    Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Cправочника по конфигурации](configuration_reference-expirationd).

4. Нажмите кнопку **Apply**:


После применения конфигурации можно убедиться через веб-интерфейс ([http://localhost:8081/admin/space-explorer/hosts](http://localhost:8081/admin/space-explorer/hosts)) 
во вкладке **Space explorer** , что сгенерированные данные начинают сокращаться.

## Остановка кластера

Чтобы остановить кластер, выполните следующую команду:

```shell
docker compose down
```
