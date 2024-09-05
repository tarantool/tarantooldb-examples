# Замена автокодировщика на свой алгоритм с помощью Go-коннектора

В примере приложение записывает кортежи пачками в спейс через выбранный роутер.
После записи приложение читает добавленные кортежи.
За счёт замены автокодировщика в MsgPack на свой алгоритм производительность записи в примере повышена на 20%.
В качестве примера производится также чтение записанных значений и их декодирование
собственным алгоритмом.

Содержание:

* [](user_guide-go_encoder-prereq)
* [](user_guide-go_encoder-space)
* [](user_guide-go_encoder-start_example)
* [](user_guide-go_encoder-run_application)
* [](user_guide-go_encoder-stop_example)

(user_guide-go_encoder-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `go_custom_encoder`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `go_custom_encoder` расположен в таком архиве в директории `./doc/examples/go_custom_encoder/`.
    
  * Отдельный архив [go_custom_encoder.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/go_custom_encoder/go_custom_encoder.tar.gz), скачанный c сайта Tarantool.
  ```
 
(user_guide-go_encoder-space)=
## Формат спейса

Формат спейса в приложении и в кластере отличается.
В приложении указаны только пользовательские поля:

```{literalinclude} go/main.go
:start-at: type TestRecord
:end-before: func (c *TestRecord) EncodeMsgpack
:language: go
:dedent:
```

В базе данных в этом спейсе есть дополнительное поле `bucket_id` -- ключ шардирования:

```{literalinclude} tt/migrations/scenario/001_test.lua
:start-at: box.schema.space.create
:end-before: helpers.register_sharding_key
:language: lua
:dedent:
```

При кодировании данных в поле `bucket_id` записывается `nil`.
При декодировании поле `bucket_id` пропускается.

(user_guide-go_encoder-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301--3306
* 8081

Перейдите в директорию `go_custom_encoder/tt`:

```shell
cd ./doc/examples/go_custom_encoder/tt
```

Стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 1 набор реплик на 2 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
  - 2 координатора автоматического восстановления после сбоев (*failover coordinator*);

- кластера etcd из 3 узлов;
- клиентского приложения, подающего нагрузку.

Запустите всё, кроме клиентского приложения, следующей командой:

```shell
make start
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
   - в поле **Password** --  `secret-cluster-cookie`.
    
6. Нажмите **Update**, чтобы сохранить новые настройки кластера. При успешном обновлении в веб-интерфейсе появится сообщение `Cluster updated successfully`.
7. В веб-интерфейсе перейдите на вкладку **Stateboard**. После применения настроек кластер будет выглядеть так:

   ![](images/tcm-stateboard.png)

8. Выберите любой роутер из списка, например `router-1`, и в открывшемся окне перейдите на вкладку **Terminal**.
9. Во вкладке **Terminal** введите команду `box.space`. Проверьте, что в выводе есть спейс `test` -- этот спейс создается при запуске кластера.

(user_guide-go_encoder-run_application)=
## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `go_custom_encoder/go`:

```shell
cd ./doc/examples/go_custom_encoder/go
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
Recorded via crud in batches of 10000 records in 120.924997ms - auto-encoder
Recorded via crud in batches of 10000 records in 96.016347ms - custom-encoder
Rows verified
```

Теперь проверьте, что в спейсе `test` появились данные. Для этого:

1. В TCM перейдите на вкладку **Tuples**.
2. Выберите в списке спейс `test`. Откроется новая вкладка с содержимым кортежей спейса `test`.

(user_guide-go_encoder-stop_example)=
## Остановка стенда

Для остановки стенда:

* В первом терминале выполните команду:

  ```shell
  make stop
  ```
  
* Во втором терминале выполните команду `Ctrl + Z`.

