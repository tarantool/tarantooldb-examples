# Работа с кластером Tarantool DB через модуль CRUD с помощью Java-коннектора

В примере приложение записывает кортежи в спейс пачками через выбранный роутер, а также проверяет эти записанные кортежи.

Узнать больше про Java-коннектор можно в репозитории [tarantool/tarantool-java-ee](https://github.com/tarantool/tarantool-java-ee).

Содержание:

* [](user_guide-java_crud-prereq)
* [](user_guide-java_crud-start_example)
* [](user_guide-java_crud-run_application)
* [](user_guide-java_crud-stop_example)

(user_guide-java_crud-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* Maven;
* Java версии 8+;
* исходные файлы примера `java_crud`.
  Пример находится в директории `./doc/examples/java_crud/`.

Кроме того, для загрузки Java-коннектора нужно настроить конфигурацию Maven.
Чтобы задать эту конфигурацию, используйте инструкцию [Установка клиента tarantool-java-ee](/user_guide/connectors/java/java_install.md).

(user_guide-java_crud-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны порты:
* 3301 .. 3306
* 8081 .. 8086

Перейдите в директорию `java_crud/tt`:

```shell
cd ./doc/examples/java_crud/tt
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
В примере не используется [шардирование](https://www.tarantool.io/ru/doc/latest/concepts/sharding/), поэтому модуль
`vshard` не запущен.

После этого перейдите на вкладку **Space Explorer** и выберите любой узел, например, `storage1`.
Проверьте, что на узле есть спейс `test`.

(user_guide-java_crud-run_application)=
## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `java_crud`:

```shell
cd ./doc/examples/java_crud
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

Необходимо убедиться, что в спейсе `test` появились данные.

(user_guide-java_crud-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
