# Работа напрямую с экземпляром Tarantool DB через Go-коннектор

В примере операции выполняются напрямую с конкретным экземпляром.
Такой подход может увеличить производительность, но требует дополнительной
экспертизы -- понимания внутреннего устройства кластера Tarantool DB и принципа его работы.

В этом примере показано, как выполнять операции напрямую с конкретным экземпляром:
приложение записывает по одному кортежу напрямую в спейс, а также выполняет чтение.
Чтобы удобно просматривать содержимое спейсов, в примере используется роль [space-explorer](reference-roles-space-explorer).
Другие роли в этом примере не используются.

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
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `go_directly` расположен в таком архиве в директории `./doc/examples/go_directly/`.
    
  * Отдельный архив [go_directly.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/go_directly/go_directly.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-go_directly-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны порты:
* 3301
* 8081

Перейдите в директорию `go_directly/tt`:

```shell
cd ./doc/examples/go_directly/tt
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

Остановить стенд можно так:

```shell
docker compose down
```
