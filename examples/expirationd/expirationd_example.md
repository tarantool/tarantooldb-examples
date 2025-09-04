(user_guide-expirationd_example)=
# Автоматическое удаление устаревших кортежей из спейса

В этом руководстве описано, как настроить параметры устаревания данных в конфигурации,
чтобы автоматически удалять все кортежи в спейсе, которые старше заданного времени.
Подробнее о модуле `expirationd` можно узнать в разделе [Устаревание данных](user_guide-expirationd).

Руководство включает следующие шаги:

* [](user_guide-expirationd_example-prereq)
* [](user_guide-expirationd_example-start_example)
* [](user_guide-expirationd_example-migration)
* [](user_guide-expirationd_example-add_data)
* [](user_guide-expirationd_example-config)
* [](user_guide-expirationd_example-stop_example)

(user_guide-expirationd_example-prereq)=
## Пререквизиты

Для выполнения примера требуются:
* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* исходные файлы примера `expirationd`.

  ```{note}
  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `expirationd` расположен в таком архиве в директории `./doc/examples/expirationd/`.
    
  * Отдельный архив [expirationd.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/expirationd/expirationd.tar.gz), скачанный c сайта Tarantool.
  ```
  
(user_guide-expirationd_example-start_example)=
## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты:

* 2379
* 3301--3308
* 8081

Перейдите в папку с примером `expirationd`:

```shell
cd ./doc/examples/expirationd/
```

Запустите кластер:

```shell
make start
```

Запущенный стенд состоит из:
- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- кластера etcd из 3 узлов;
- одного узла [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

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

(user_guide-expirationd_example-migration)=
## Описание миграции

В руководстве используется миграция из файла `./cluster/migrations/scenario/001_test.lua` примера `expirationd`.
В этой миграции создан спейс `messages` со следующим форматом:

```{literalinclude} cluster/migrations/scenario/001_test.lua
:start-after: local function apply()
:end-before: helpers.register_sharding_key
:language: lua
:dedent:
```

Необходимо удалять все записи в спейсе старше заданного количества секунд. Количество секунд задается в конфигурации.

Смотрите также: [](user_guide-expirationd_user_logic).

(user_guide-expirationd_example-add_data)=
## Подключение к узлу и загрузка тестовых данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:

- в веб-интерфейсе TCM;
- в терминале с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:
	
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
Кортежи будут удалены спустя заданное в настройках время -- 15 секунд.

(user_guide-expirationd_example-config)=
## Конфигурация устаревания данных

В конфигурации кластера присутствует следующая секция:

```{literalinclude} cluster/config.yml
:start-at: roles_cfg
:end-at: time_create_field
:language: yaml
:dedent:
```

Здесь:
  
* `task_name1` -- название задачи по устареванию данных;
  * `space` -- название спейса, по которому идет поиск устаревших кортежей;
  * `options.args` -- дополнительные опции конфигурации:
    * `lifetime_in_seconds` -- время жизни кортежа в секундах;
    * `time_create_field` -- название поля, по которому проверяется время жизни кортежа.
    
Полное описание опций конфигурации `expirationd` приведено в соответствующем разделе [Справочника по конфигурации](configuration_reference-expirationd).

(user_guide-expirationd_example-stop_example)=
## Остановка кластера

Чтобы остановить кластер, выполните в локальном терминале следующую команду:

```shell
make stop
```

