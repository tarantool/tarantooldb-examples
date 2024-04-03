# Работа напрямую с экземпляром Tarantool DB через Java-коннектор

В примере операции выполняются напрямую с конкретным экземпляром.
Такой подход может увеличить производительность, но требует дополнительной
экспертизы -- понимания внутреннего устройства кластера Tarantool DB и принципа его работы.

В этом примере показано, как выполнять операции напрямую с конкретным экземпляром:
приложение записывает по одной строке напрямую в спейс, а также выполняет чтение.
Чтобы удобно просматривать содержимое спейсов, в примере используется роль [space-explorer](reference-roles-space-explorer).
Другие роли в этом примере не используются.

Узнать больше про Java-коннектор можно в репозитории [tarantool/tarantool-java-ee](https://github.com/tarantool/tarantool-java-ee).

Содержание:

* [](user_guide-java_directly-prereq)
* [](user_guide-java_directly-start_example)
* [](user_guide-java_directly-run_application)
* [](user_guide-java_directly-stop_example)

(user_guide-java_directly-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* Maven;
* Java версии 8+;
* исходные файлы примера `java_directly`.
  Пример находится в директории `./doc/examples/java_directly/`.

Кроме того, для загрузки Java-коннектора нужно настроить конфигурацию Maven.
Чтобы задать эту конфигурацию, используйте инструкцию [Установка клиента tarantool-java-ee](/user_guide/connectors/java/java_install.md).

(user_guide-java_directly-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны порты:
* 3301
* 8081

Перейдите в директорию `java_directly/tt`:

```shell
cd ./doc/examples/java_directly/tt
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
В примере не используется [шардирование](https://www.tarantool.io/ru/doc/latest/concepts/sharding/), поэтому модуль
`vshard` не запущен.

После этого перейдите на вкладку **Space Explorer** и выберите любой узел, например, `storage1`.
Проверьте, что на узле есть спейс `test`.

(user_guide-java_directly-run_application)=
## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `go_directly/go`:

```shell
cd ./doc/examples/java_directly
```

Запустите Java-приложение:

```shell
mvn clean compile
mvn exec:java -Dexec.mainClass="org.example.App"
```

Вывод после окончания работы приложения выглядит так:

```
Directly recorded 10000 rows one at a time in 483 milliseconds
Tuples: [[1, 4677746723089159966, aHRDJPQVkTEBttESWzzUH]]
```

Необходимо убедиться, что в спейсе `test` появились данные.

(user_guide-java_directly-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```

