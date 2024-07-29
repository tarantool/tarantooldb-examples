# Работа напрямую с экземпляром Tarantool DB через Go-коннектор

В примере операции выполняются напрямую с конкретным экземпляром.
Такой подход может увеличить производительность, но требует дополнительной
экспертизы -- понимания внутреннего устройства кластера Tarantool DB и принципа его работы.

В этом примере показано, как выполнять операции напрямую с конкретным экземпляром:
приложение записывает по одному кортежу напрямую в спейс, а также выполняет чтение данных.

Узнать больше про Go-коннектор можно в репозитории [tarantool/go-tarantool](https://pkg.go.dev/github.com/tarantool/go-tarantool/v2).

Содержание:

* [](user_guide-go_directly-prereq)
* [](user_guide-go_directly-start_example)
* [](user_guide-go_directly-run_application)
* [](user_guide-go_directly-stop_example)

(user_guide-go_directly-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* исходные файлы примера `go_directly`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `go_directly` расположен в таком архиве в директории `./doc/examples/go_directly/`.
    
  * Отдельный архив [go_directly.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/go_directly/go_directly.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-go_directly-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301--3302
* 8081

Перейдите в директорию `go_directly/tt`:

```shell
cd ./doc/examples/go_directly/tt
```

Запустите стенд:

```shell
docker compose up -d
```

Команда развернет стенд, состоящий из:
* кластера Tarantool DB (1 роутер-хранилище, 1 TCM);
* кластера etcd из 3 узлов;
* клиентского приложения, подающего нагрузку.

После запуска должны работать все контейнеры, кроме `init_host`.
Также после запуска становится доступен пользовательский интерфейс http://localhost:8081 -- веб-интерфейс кластера Tarantool DB (TCM).

Получите пароль для входа в веб-интерфейс Tarantool DB:
```shell
docker compose logs tcm-1 | grep "super admin"
```

Откройте веб-интерфейс в браузере по адресу [http://localhost:8081](http://localhost:8081).
Для входа используйте логин `admin` и пароль, полученный с помощью предыдущей команды.

Чтобы настроить кластер:

1. В веб-интерфейсе перейдите на вкладку **Clusters**.
2. В строке с кластером `Default cluster` нажмите кнопку **...** (**Actions**) справа и выберите **Edit** в выпадающем меню.
3. Переключитесь на второй экран настройки, используя кнопку **Next**.
4. На втором экране укажите в поле **Prefix** значение `/tdb` и нажмите  **Next**.
5. На третьем экране укажите следующие значения:
   - в поле **Username** -- `admin`;
   - в поле **Password** --  `secret-cluster-cookie`.
    
6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**. 
8. Выберите любой роутер из списка (например, `router-1`) и в открывшемся окне перейдите на вкладку **Terminal**.
9. В терминале введите команду `box.space`. Проверьте, что в выводе есть спейс `test` -- этот спейс создается при запуске кластера.

(user_guide-go_directly-run_application)=
## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `go_directly/go`:

```shell
cd ./doc/examples/go_directly/go
```

Запустите Go-приложение:

```shell
go run -tags go_tarantool_ssl_disable main.go
```

Здесь:

* `go_tarantool_ssl_disable` -- опция, отключающая поддержку TLS.
  Так как для поддержки TLS требуется установленный OpenSSL 3.x, для простоты в примере поддержка TLS отключена.

Вывод после окончания работы приложения выглядит так:

```
Directly recorded 10000 rows one at a time in 670.147941ms
Tuples [{{} 1 77 WjishcEWgbUGSerPYtkmAhtSrRYXmyYaXDyScIFcRCpFwIMYpGZwrZbYRSBUdPAP}]
```

Необходимо убедиться, что в спейсе `test` появились данные.

(user_guide-go_directly-stop_example)=
## Остановка стенда

Для остановки стенда:

* В первом терминале выполните команду:

    ```shell
    docker compose down
    ```
  
* Во втором терминале выполните команду `Ctrl + Z`.

