# Работа напрямую с экземпляром Tarantool DB через Java-коннектор

В примере операции выполняются напрямую с конкретным экземпляром.
Такой подход может увеличить производительность, но требует дополнительной
экспертизы — понимания внутреннего устройства кластера Tarantool DB и принципа его работы.

В этом примере показано, как выполнять операции напрямую с конкретным экземпляром:
приложение записывает по одной строке напрямую в спейс, а также выполняет чтение.
Чтобы удобно просматривать содержимое спейсов, в примере используется роль [space-explorer](https://www.tarantool.io/docs/tdb/ru/1_x/reference/roles#reference-roles-space-explorer).
Другие роли в этом примере не используются.

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
* исходные файлы примера `java_directly`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `java_directly` расположен в директории `examples/java_directly`.
>  * Отдельный архив [java_directly.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fjava_directly&filename=java_directly), скачанный из этого репозитория.

Кроме того, для загрузки Java-коннектора нужно настроить конфигурацию Maven.
Чтобы задать эту конфигурацию, используйте инструкцию [Установка клиента tarantool-java-ee](https://www.tarantool.io/docs/tdb/ru/1_x/user_guide/connectors/java/java_install).

## Запуск стенда

Для успешного запуска должны быть свободны порты:
* 3301
* 8081

Перейдите в директорию `java_directly/tt`:

```shell
cd examples/java_directly/tt
```

Запустите стенд:

```shell
docker compose up -d
```

Команда развернет стенд с одним экземпляром Tarantool DB.
После запуска должны работать все контейнеры, кроме `tarantool-db-init`.

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.
В примере не используется [шардирование](https://www.tarantool.io/ru/doc/2.11/concepts/sharding/), поэтому модуль
`vshard` не запущен.

После этого перейдите на вкладку **Space Explorer** и выберите любой узел, например `storage1`.
Проверьте, что на узле есть спейс `test`.

## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `java_directly`:

```shell
cd examples/java_directly
```

Запустите Java-приложение:

```shell
mvn clean compile
mvn exec:java -Dexec.mainClass="org.example.App"
```

Вывод после окончания работы приложения выглядит так:

```shell
Directly recorded 10000 rows one at a time in 483 milliseconds
Tuples: [[1, 4677746723089159966, aHRDJPQVkTEBttESWzzUH]]
```

Необходимо убедиться, что в спейсе `test` появились данные.

## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
