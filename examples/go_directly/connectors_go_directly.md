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

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `go_directly`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `go_directly` расположен в таком архиве в директории `./doc/examples/go_directly/`.
    
  * Отдельный архив [go_directly.tar.gz](https://tarantool.io/ru/tarantooldb/doc/2.x/examples/go_directly/go_directly.tar.gz), скачанный c сайта Tarantool.
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

Стенд состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- клиентского приложения, подающего нагрузку.

Запустите всё, кроме клиентского приложения, следующей командой:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**. После применения настроек кластер будет выглядеть так:

![](./images/tcm-stateboard.png)

Нажмите на набор реплик `storage-1`, чтобы просмотреть экземпляры в нем. Обратите внимание, что все экземпляры
кластера в этом наборе реплик являются лидерами. Это означает, что набор реплик работает
в режиме [мультимастер](https://www.tarantool.io/en/doc/latest/platform/replication/repl_architecture/#replication-roles).

Выберите любой узел и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```lua
box.space
```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

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

Проверьте, что в спейсе `test` появились данные.
Для этого в веб-интерфейсе TCM в окне выбранного узла нажмите на кнопку
вызова меню **...** (**Actions**):
![](./images/gui_btn_actions.png)

В выпадающем меню выберите пункт **Explorer**. Здесь приведены список спейсов всех типов,
которые есть на данном экземпляре кластера, включая нешардированные спейсы.
В открывшемся списке выберите спейс `test`. Убедитесь, что спейс содержит
данные.

Проверьте этот спейс на других узлах и убедитесь, что репликация работает
исправно.

(user_guide-go_directly-stop_example)=
## Остановка стенда

Для остановки стенда:

* В первом терминале выполните команду:

    ```shell
    make stop
    ```
  
* Во втором терминале выполните команду `Ctrl + Z`.

