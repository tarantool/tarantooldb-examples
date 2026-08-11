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

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/1_x/install_and_upgrade/install/install_docker) Tarantool DB;
* приложение Docker Compose;
* исходные файлы примера `go_custom_encoder`.

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-1x/master).
>    Пример `go_custom_encoder` расположен в директории `examples/go_custom_encoder`.
>  * Отдельный архив [go_custom_encoder.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-1x%2Fmaster%2Fexamples%2Fgo_custom_encoder&filename=go_custom_encoder), скачанный из этого репозитория.

## Формат спейса

Формат спейса в приложении и в кластере отличаются.
В приложении указаны только пользовательские поля:
```go
type TestRecord struct {
    Id  uint64 `json:"id"`
    Too uint64 `json:"too"`
    Foo string `json:"foo"`
}
```

В базе данных в этом спейсе есть дополнительное поле `bucket_id`, используемое для шардинга:
```lua
box.space.test:format({
    { name = 'id', type = 'number' },
    { name = 'bucket_id', type = 'unsigned' }, -- << --
    { name = 'too', type = 'number' },
    { name = 'foo', type = 'string' },
})
```

При кодировании данных во втором поле записывается `nil`, а при декодировании это поле пропускается.

## Запуск стенда

Для успешного запуска должны быть свободны порты:
* 3301—3306;
* 8081—8086.

Перейдите в директорию `go_custom_encoder/tt`:

```shell
cd examples/go_custom_encoder/tt
```

Запустите стенд:

```shell
docker compose up -d
```

Команда развернет стенд, состоящий из кластера Tarantool DB (два шарда и два роутера).
После запуска должны работать все контейнеры, кроме `tarantool-db-init`.

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.

После этого перейдите на вкладку **Space Explorer** и выберите любой узел, например `storage-A-1`.
Проверьте, что на узле есть спейс `test`.

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

Необходимо убедиться, что в спейсе `test` появились данные.

## Остановка стенда

Остановить стенд можно так:

```shell
docker compose down
```
