(user_guide-binary_data_example)=
# Запись и получение бинарных данных

В этом руководстве показано, как записать бинарные данные в шардированный спейс с помощью модуля CRUD, а затем прочитать записанные файлы.

Для хранения бинарных данный используйте тип `string`. Подробнее о строковом типе данных можно узнать в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/platform/ddl_dml/value_store/#index-box-string).

Содержание:

* [](user_guide-binary_data_example-prereq)
* [](user_guide-binary_data_example-start_example)
* [](user_guide-binary_data_example-write_data)
* [](user_guide-binary_data_example-read_data)
* [](user_guide-binary_data_example-about_size)
* [](user_guide-binary_data_example-stop_example)

(user_guide-binary_data_example-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `binary_data`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `binary_data` расположен в таком архиве в директории `./doc/examples/binary_data/`.
    
  * Отдельный архив [binary_data.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/binary_data/binary_data.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-binary_data_example-start_example)=
## Запуск стенда и подключение к узлу 

Для успешного запуска должны быть свободны следующие порты:

* 3301--3308
* 8081, 8082

Перейдите в папку с примером `binary_data`:

```shell
cd ./doc/examples/binary_data
```

Запустите стенд:

```shell
cd tt
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

В TCM откройте вкладку **Tuples**. Убедитесь, что в списке есть спейс `my_files`.

(user_guide-binary_data_example-write_data)=
## Запись бинарных данных

Чтобы продемонстрировать запись бинарных данных в шардированный спейс, в примере используется приложение на языке Go.

Откройте вторую вкладку локального терминала и перейдите в директорию с приложением:
```shell
cd ./doc/examples/binary_data/go
```

Запустите Go-приложение:

```shell
go run main.go
```

Программа читает все файлы из папки `go/images` и записывает их в Tarantool DB с помощью модуля CRUD.
Чтобы проверить записанные данные, в TCM перейдите на вкладку **Tuples** и выберите в списке спейс `my_files`.
Откроется новая вкладка с содержимым кортежей спейса `my_files`.

(user_guide-binary_data_example-read_data)=
## Чтение бинарных данных

Запущенная Go-программа является также веб-сервером, слушающим порт 8082. По запросу в браузере программа получает из запроса
запрашиваемое имя файла. После этого по имени файла выполняется запрос в базу данных. Бинарные данные, которые извлечены при этом из базы данных,
отображаются браузером в качестве картинки согласно прикреплённому заголовку. Пример запроса:
```
http://localhost:8082/Dunkan.jpg
```

(user_guide-binary_data_example-about_size)=
## Размер бинарных данных

Если размер бинарных данных большой, увеличьте максимально возможный размер кортежа перед запуском экземпляра. Задать такой размер можно с помощью переменной окружения `TT_MEMTX_MAX_TUPLE_SIZE`.

(user_guide-binary_data_example-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в первом локальном терминале следующую команду:

```shell
make stop
```
