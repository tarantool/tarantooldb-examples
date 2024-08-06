# Работа с кластером Tarantool DB через модуль CRUD с помощью Go-коннектора

В примере приложение записывает кортежи в спейс пачками через выбранный роутер, а также выполняет чтение данных.
Для взаимодействия в целях универсальности используется тип `interface{}`. Это означает, что значения после чтения нужно преобразовывать в нужный тип.
Для примера показано преобразование в число.

Узнать больше про Go-коннектор можно в репозитории [tarantool/go-tarantool](https://pkg.go.dev/github.com/tarantool/go-tarantool/v2/crud).

Содержание:

* [](user_guide-go_crud-prereq)
* [](user_guide-go_crud-start_example)
* [](user_guide-go_crud-run_application)
* [](user_guide-go_crud-stop_example)

(user_guide-go_crud-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `go_crud`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `go_crud` расположен в таком архиве в директории `./doc/examples/go_crud/`.
    
  * Отдельный архив [go_crud.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/go_crud/go_crud.tar.gz), скачанный c сайта Tarantool.
  ```
 
(user_guide-go_crud-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301--3306
* 8081

Перейдите в директорию `go_crud/tt`:

```shell
cd ./doc/examples/go_crud/tt
```

Стенд состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 2 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
  - 2 координатора автоматического восстановления после сбоев (*failover coordinator*);

- кластера etcd из 3 узлов;
- клиентского приложения, подающего нагрузку.

Запустите всё, кроме клиентского приложения, следующей командой:

```shell
docker compose up -d
```

После запуска должны работать все контейнеры, кроме `init_host`.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Получить пароль для входа в TCM можно так:
```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте TCM в браузере по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

Чтобы настроить кластер:

1. В веб-интерфейсе перейдите на вкладку **Clusters**.
2. В строке с кластером `Default cluster` нажмите кнопку **...** (**Actions**) справа и выберите **Edit** в выпадающем меню.
3. Переключитесь на второй экран настройки, используя кнопку **Next**.
4. На втором экране укажите в поле **Prefix** значение `/tdb` и нажмите  **Next**.
5. На третьем экране укажите следующие значения:
   - в поле **Username** -- `admin`;
   - в поле **Password** -- `secret-cluster-cookie`.
    
6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**. После применения настроек кластер будет выглядеть так:

   ![](images/tcm-stateboard.png)

8. Выберите любой роутер из списка (например, `router-1`) и в открывшемся окне перейдите на вкладку **Terminal**.
9. Во вкладке **Terminal** введите команду `box.space`. Проверьте, что в выводе есть спейс `test` -- этот спейс создается при запуске кластера.

(user_guide-go_crud-run_application)=
## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `go_crud/go`:

```shell
cd ./doc/examples/go_crud/go
```

Запустите Go-приложение:

```shell
go run -tags go_tarantool_ssl_disable main.go
```

Здесь:

* `go_tarantool_ssl_disable` -- опция, отключающая поддержку TLS.
  Так как для поддержки TLS требуется установленный OpenSSL 3.x, для простоты в примере поддержка TLS отключена.

Вывод после окончания работы приложения выглядит так:

```shell
Recorded via crud in batches of 10000 records in 147.229874ms
Rows verified
```

Теперь проверьте, что в спейсе `test` появились данные. Для этого:

1. В TCM перейдите на вкладку **Tuples**.
2. Выберите в списке спейс `test`. Откроется новая вкладка с содержимым кортежей спейса `test`.

(user_guide-go_crud-stop_example)=
## Остановка стенда

Для остановки стенда:

* В первом терминале выполните команду:

    ```shell
    docker compose down
    ```
  
* Во втором терминале выполните команду `Ctrl + Z`.
