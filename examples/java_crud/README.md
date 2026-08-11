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

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* Maven;
* Java версии 8+;
* установленный [tarantool-java-ee версии 1.3.1](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/connectors/java/java_install).
* исходные файлы примера `java_crud`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `java_crud` расположен в директории `examples/java_crud`.
>  * Отдельный архив [java_crud.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fjava_crud&filename=java_crud), скачанный из этого репозитория.

Кроме того, для загрузки Java-коннектора нужно настроить конфигурацию Maven.
Чтобы задать эту конфигурацию, используйте инструкцию [Установка клиента tarantool-java-ee](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/connectors/java/java_install).

## Запуск стенда

Для успешного запуска должны быть свободны порты:
* 3301—3306;
* 8081—8086.

Перейдите в директорию `java_crud/tt`:

```shell
cd examples/java_crud/tt
```

Запустите стенд:

```shell
docker compose up -d
```

Команда развернет кластер Tarantool DB, состоящий из двух шардов и двух роутеров.
После запуска должны работать все контейнеры, кроме `tarantool-db-init`.

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.

После этого перейдите на вкладку **Space Explorer** и выберите любой узел, например `storage1`.
Проверьте, что на узле есть спейс `test`.

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

```shell
Records inserted via CRUD in batches of 10000 records in 1106 ms
Rows verified
```

Необходимо убедиться, что в спейсе `test` появились данные.

## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
