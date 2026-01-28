(user_guide-dictionary_user_example)=
# Работа со словарём с ограниченными правами

В этом руководстве показано, как работать со словарями через отдельного пользователя
с минимально необходимыми правами.

Содержание:

- [](user_guide-dictionary_user_example-dictionary_user)
- [](user_guide-dictionary_user_example-prereq)
- [](user_guide-dictionary_user_example-start_example)
- [](user_guide-dictionary_user_example-add_data)
- [](user_guide-dictionary_user_example-read_data)
- [](user_guide-dictionary_user_example-export_import)
  - [](user_guide-dictionary_user_example-export)
  - [](user_guide-dictionary_user_example-edit_outside_cluster)
  - [](user_guide-dictionary_user_example-update_csv)
  - [](user_guide-dictionary_user_example-import)
- [](user_guide-dictionary_user_example-stop_example)

(user_guide-dictionary_user_example-dictionary_user)=
## Пользователь словарей

Для выполнения операций со словарями не требуются широкие права доступа (super-права).
Достаточно отдельного пользователя, который может:

- выполнять операции чтения, записи, обновления и удаления данных в словарях через API модуля `dictionary`;
- выгружать и загружать данные словарей с помощью команд `tt export` и `tt import`.

Пользователь словарей не имеет доступа к операциям модуля CRUD, а также к пользовательским спейсам и функциям приложения.

Для корректной работы со словарями требуется назначить такому пользователю в конфигурации роль `dictionary_api_executor`.
Роль `dictionary_api_executor` разрешает вызов методов API словаря.
Привилегии на спейсы позволяют работать с данными словарей и 
использовать команды `tt export`, `tt import` и `tt connect`.
Узнать больше: [](user_guide-dictionary_gs).

Пользователей словарей может быть несколько.
В этом руководстве такой пользователь имеет название `dictionary_user`.

```yaml
credentials:
  users:
    dictionary_user:
      password: 'secret'
      roles: [ dictionary_api_executor ]
      privileges:
        - permissions: [ read, write ]
          spaces: [ dictionary_data, dictionary_vclock ]
        - permissions: [ execute ]
          universe: true
```

(user_guide-dictionary_user_example-prereq)=
## Пререквизиты

Для выполнения примера требуются:

- установленный [Docker-образ](install_docker-image) Tarantool DB;
- приложение Docker Compose;
- утилита [tt CLI](install-install_tt);
- исходные файлы примера `dictionary_user`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `dictionary_user` расположен в таком архиве в директории `./doc/examples/dictionary_user/`.
    
  * Отдельный архив [dictionary_user.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/dictionary_user/dictionary_user.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-dictionary_user_example-start_example)=
## Запуск стенда и подключение к узлам

Для успешного запуска должны быть свободны следующие порты:

- 2379
- 3301–3308
- 8081

Перейдите в папку с примером `dictionary_user`

```shell
cd ./doc/examples/dictionary_user
```

Запустите стенд:

```shell
make start
```

Команда развернет стенд, который состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 узла [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host). 

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

Все операции со словарями в примере ниже выполняются через пользователя `dictionary_user`.

(user_guide-dictionary_user_example-add_data)=
## Запись данных в словарь

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
В примере используется подключение в терминале с помощью утилиты tt CLI:

- **Terminal 1** — подключение к одному узлу кластера для записи данных;
- **Terminal 2** — подключение к другому узлу для проверки данных.

Для добавления новых элементов словаря подключитесь к кластеру в терминале (далее -- **Terminal 1**) через пользователя словарей:

```shell
tt connect dictionary_user:secret@localhost:3301
```

В примере ниже задается словарь `categories`, который содержит категории денежных трат.
Добавьте несколько элементов с соответствующими им ключами в словарь `categories` с помощью метода [dictionary_router_set()](reference_lua-dictionary-set):

```lua
box.schema.func.call('dictionary_router_set', 'categories', '1', 'Shops')
box.schema.func.call('dictionary_router_set', 'categories', '2', 'Food delivery')
box.schema.func.call('dictionary_router_set', 'categories', '3', 'Transport')
```


(user_guide-dictionary_user_example-read_data)=
## Чтение данных с другого узла

Словари автоматически реплицируются между всеми узлами кластера. Чтобы проверить это, откройте вторую вкладку терминала (далее -- **Terminal 2**) и подключитесь к другому узлу кластера:

```shell
tt connect dictionary_user:secret@localhost:3302
```

Проверьте записанные в словарь данные с помощью метода [dictionary_router_get()](reference_lua-dictionary-get):

```lua
box.schema.func.call('dictionary_router_get', 'categories', '1')
box.schema.func.call('dictionary_router_get', 'categories', '2')
box.schema.func.call('dictionary_router_get', 'categories', '3')
```

Видно, что изменения словаря автоматически синхронизируются между всеми узлами кластера.

(user_guide-dictionary_user_example-export_import)=
## Выгрузка и загрузка словаря через утилиту tt CLI

Экспорт и импорт словарей можно использовать:

- для переноса словарей между окружениями;
- при восстановлении словарей из резервной копии;
- для массового редактирования данных вне кластера.

(user_guide-dictionary_user_example-export)=
### Экспорт словаря

Выполните экспорт системных спейсов словарей, используя **один** из способов ниже
(пример для узла хранилища `localhost:3303`):

- ```shell
  tt export localhost:3303 dictionary_data:dictionary_data.csv \
  --username dictionary_user --password secret --header
  ```

- ```shell
  tt export dictionary_user:secret@localhost:3303 \
    dictionary_data:dictionary_data.csv --header
  ```

(user_guide-dictionary_user_example-edit_outside_cluster)=
### Редактирование данных вне кластера

Выгрузка словарей через `tt export` используется в тех случаях, когда требуется
работать с содержимым словаря **вне кластера**, без прямого доступа к Tarantool.

Типовые сценарии:

* **Массовое наполнение или правка словаря** -- при добавлении или изменении большого количества записей;

* **Перенос словарей между окружениями** -- например, перенос из тестового окружения в staging или production без копирования прикладных данных;

* **Восстановление словарей из резервной копии** -- в случае потери данных или необходимости отката содержимого словаря
  к известному состоянию;

* **Подготовка данных в изолированной среде** -- 
  если редактирование словаря должно происходить без доступа к кластеру
  (например, на локальной машине или в CI).

Во всех этих сценариях словарь выгружается в виде CSV-файлов,
редактируется вне кластера, а затем загружается обратно с помощью `tt import`.

(user_guide-dictionary_user_example-update_csv)=
### Обогащение CSV-файла словаря

После экспорта файл `dictionary_data.csv` можно дополнить новыми записями.
Добавьте в словарь несколько новых категорий:

```csv
categories,4,Entertainment,11111111-1111-1111-1111-111111111111,1766583269000000000,00000000000000000000000000000000
categories,5,Health,22222222-2222-2222-2222-222222222222,1766583269000000001,00000000000000000000000000000000
categories,6,Education,33333333-3333-3333-3333-333333333333,1766583269000000002,00000000000000000000000000000000
categories,7,Subscriptions,44444444-4444-4444-4444-444444444444,1766583269000000003,00000000000000000000000000000000
```

Таким образом можно массово дополнить словарь вне кластера,
а затем загрузить обновлённые данные обратно с помощью `tt import`.

Полученные CSV-файлы можно отредактировать вручную,
например добавить новые строки или изменить существующие значения.
Этот шаг выполняется **вне Tarantool** и не требует доступа к кластеру.

```{note}
При редактировании CSV-файлов вручную **не рекомендуется** менять существующие
значения `uuid` и `vclock`, если нет полного понимания последствий такого решения.
```


(user_guide-dictionary_user_example-import)=
### Импорт обновлённых данных

После редактирования файлов загрузите их обратно в кластер, используя **один** из способов ниже
(пример для другого узла хранилища `localhost:3306`):

- ```shell
  tt import localhost:3306 --username dictionary_user \
    --password secret dictionary_data.csv:dictionary_data --header
  ```

- ```shell
  tt import dictionary_user:secret@localhost:3306 \
    dictionary_data.csv:dictionary_data --header
  ```

Чтобы проверить загруженные данные словаря, подключитесь к любому узлу кластера. В примере используется подключение к узлу из **Terminal 1**:

```shell
tt connect dictionary_user:secret@localhost:3301
```

Затем проверьте записанные в словарь данные:

```lua
box.schema.func.call('dictionary_router_get', 'categories', '4')
box.schema.func.call('dictionary_router_get', 'categories', '5')
box.schema.func.call('dictionary_router_get', 'categories', '6')
box.schema.func.call('dictionary_router_get', 'categories', '7')
```

Обновлённые значения доступны на всех узлах кластера.

(user_guide-dictionary_user_example-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
