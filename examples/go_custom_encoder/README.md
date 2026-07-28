# Замена автокодировщика на свой алгоритм с помощью Go-коннектора

В примере приложение записывает кортежи пачками в спейс через выбранный роутер.
После записи приложение читает добавленные кортежи.
За счёт замены автокодировщика в MsgPack на свой алгоритм производительность записи в примере повышена на 20%.
В качестве примера производится также чтение записанных значений и их декодирование
собственным алгоритмом.

Содержание:

* [Пререквизиты](#пререквизиты)
* [Формат спейса](#формат-спейса)
* [Запуск стенда](#запуск-стенда)
* [Запуск приложения](#запуск-приложения)
* [Остановка стенда](#остановка-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/2_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `go_custom_encoder`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-2x/master).
>    Пример `go_custom_encoder` расположен в директории `examples/go_custom_encoder`.
>  * Отдельный архив [go_custom_encoder.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-2x%2Fmaster%2Fexamples%2Fgo_custom_encoder&filename=go_custom_encoder), скачанный из этого репозитория.

## Формат спейса

Формат спейса в приложении и в кластере отличается.
В приложении указаны только пользовательские поля:

```go
type TestRecord struct {
	Id  uint64 `json:"id"`
	Too uint64 `json:"too"`
	Foo string `json:"foo"`
}
```

В базе данных в этом спейсе есть дополнительное поле `bucket_id` — ключ шардирования:

```lua
box.schema.space.create('test', {
    if_not_exists = true,
    format = {
        { name = 'id', type = 'number' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'too', type = 'number' },
        { name = 'foo', type = 'string' },
    },
})
s:create_index('pk', { parts = {'id'}, if_not_exists = true})
s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
```

При кодировании данных в поле `bucket_id` записывается `nil`.
При декодировании поле `bucket_id` пропускается.

## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:
* 3301—3306
* 8081

Перейдите в директорию `go_custom_encoder/tt`:

```shell
cd examples/go_custom_encoder/tt
```

Стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластера etcd из 3 узлов;
- 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/2_x/getting_started#getting_started-tcm) (TCM);
- клиентского приложения, подающего нагрузку.

Запустите всё, кроме клиентского приложения, следующей командой:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](../up_with_docker_compose/README.md#контейнер-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**. После применения настроек кластер будет выглядеть так:

![Вкладка Stateboard в TCM](images/tcm-stateboard.png)

Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```lua
box.space
```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

## Запуск приложения

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `go_custom_encoder/go`:

```shell
cd examples/go_custom_encoder/go
```

Запустите Go-приложение:

```shell
go run -tags go_tarantool_ssl_disable main.go
```

Здесь:

* `go_tarantool_ssl_disable` — опция, отключающая поддержку TLS.
  Так как для поддержки TLS требуется установленный OpenSSL 3.x, для простоты в примере поддержка TLS отключена.

Вывод после окончания работы приложения выглядит так:

```shell
Recorded via crud in batches of 10000 records in 120.924997ms - auto-encoder
Recorded via crud in batches of 10000 records in 96.016347ms - custom-encoder
Rows verified
```

Проверьте, что в спейсе `test` появились данные.
Для этого в веб-интерфейсе TCM перейдите на вкладку **Tuples** и выберите в списке спейс `test`.
Откроется новая вкладка с содержимым кортежей спейса `test`.

## Остановка стенда

Для остановки стенда:

* В первом терминале выполните команду:

  ```shell
  make stop
  ```

* Во втором терминале выполните команду `Ctrl + Z`.
