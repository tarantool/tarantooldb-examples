# Работа с кластером Tarantool DB через модуль CRUD с помощью Java-коннектора

В примере приложение записывает кортежи в спейс пачками через выбранный роутер, а также проверяет эти записанные кортежи.

Узнать больше про Java-коннектор можно в репозитории [tarantool/tarantool-java-ee](https://github.com/tarantool/tarantool-java-ee).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Запуск приложения](#запуск-приложения)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* Maven;
* Java версии 8+;
* установленный Java-коннектор версии 1.1.3. Для установки используйте инструкцию [Установка клиента tarantool-java-ee](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/connectors/java/java_install);
* исходные файлы примера `java_crud`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `java_crud` расположен в директории `examples/java_crud`.
>  * Отдельный архив [java_crud.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Fjava_crud&filename=java_crud), скачанный из этого репозитория.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301–3308
* 8081

Перейдите в директорию `java_crud`:

```shell
cd examples/java_crud
```

Стенд состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
- клиентского приложения, подающего нагрузку.

Запустите стенд:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`


В TCM откройте вкладку **Stateboard**. После применения настроек кластер будет выглядеть так:

![Вкладка Stateboard в TCM](images/tcm-stateboard.png)

Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```lua
box.space
```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `java_crud`:

```shell
cd examples/java_crud
```

Запустите Java-приложение:

```shell
mvn clean compile
mvn exec:java -Dexec.mainClass="org.example.App"
```

Вывод после окончания работы приложения выглядит так:

```
Records inserted via CRUD in batches of 10000 records in 1106 ms
Rows verified
```

Теперь проверьте, что в спейсе `test` появились данные.
Для этого в TCM перейдите на вкладку **Tuples** и выберите в списке спейс `test`.
Откроется новая вкладка с содержимым кортежей спейса `test`.

## Остановка стенда

Чтобы остановить стенд, в локальном терминале выполните следующую команду:

```shell
make stop
```
