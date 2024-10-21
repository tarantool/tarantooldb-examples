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

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* Maven;
* Java версии 8+;
* установленный Java-коннектор версии 1.1.3. Для установки используйте инструкцию [Установка клиента tarantool-java-ee](user_guide-connectors-install_java);
* исходные файлы примера `java_crud`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `java_crud` расположен в таком архиве в директории `./doc/examples/java_crud/`.
    
  * Отдельный архив [java_crud.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/java_crud/java_crud.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-java_crud-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301--3306
* 8081

Перейдите в директорию `java_crud`:

```shell
cd ./doc/examples/java_crud
```

Стенд состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- клиентского приложения, подающего нагрузку.

Запустите стенд:

```shell
cd tt && make start
```

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`


В TCM откройте вкладку **Stateboard**. После применения настроек кластер будет выглядеть так:

![](/images/tcm-stateboard.png)

Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```lua
box.space
```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

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

Теперь проверьте, что в спейсе `test` появились данные.
Для этого в TCM перейдите на вкладку **Tuples** и выберите в списке спейс `test`.
Откроется новая вкладка с содержимым кортежей спейса `test`.

(user_guide-java_crud-stop_example)=
## Остановка стенда

Чтобы остановить стенд, в локальном терминале выполните следующие команды:

```shell
cd tt && make stop
```
