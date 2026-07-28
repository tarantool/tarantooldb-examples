# Запуск кластеров Tarantool DataBase с TCF и настройка репликатора

В этом руководстве показано, как запустить два независимых кластера Tarantool DB в Docker в связке с [Tarantool Clusters Federation](https://www.tarantool.io/ru/clustersfederation/doc/latest/) (TCF)
и настроить работу репликатора между кластерами.

> [!NOTE]
> TCF поддерживает репликацию шардированных данных в спейсах с асинхронным режимом репликации.
> Это означает, что передача [словарей](https://www.tarantool.io/docs/tdb/ru/3_x/user_guide/dictionary) через TCF недоступна.

Для работы Tarantool Clusters Federation необходимы:

* активный кластер Tarantool DB — с него идет чтение реплицируемых данных;
* пассивный кластер Tarantool DB — на него идет запись реплицируемых данных;
* [etcd](https://etcd.io/) — для восстановления после сбоя (failover) кластеров Tarantool DB;
* репликатор TCF — бинарные файлы `tcf-destination` и `tcf-gateway`.
  Инструкция о том, как получить эти файлы, приведена ниже, в секции [Запуск стенда](#запуск-стенда).

Содержание:

* [Пререквизиты](#пререквизиты)
* [Запуск стенда](#запуск-стенда)
* [Описание миграции](#описание-миграции)
* [Репликация данных с первого кластера на второй](#репликация-данных-с-первого-кластера-на-второй)
* [Изменение направления межкластерной репликации](#изменение-направления-межкластерной-репликации)
* [Репликация данных со второго кластера на первый](#репликация-данных-со-второго-кластера-на-первый)
* [Отключение стенда](#отключение-стенда)

## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](https://www.tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB;
* архив для развёртывания TCF версии 0.7.0.
  Архив можно скачать в личном кабинете tarantool.io, в разделе [tcf/release/](https://www.tarantool.io/ru/accounts/customer_zone/packages/tcf/release);
* приложение Docker Compose;
* исходные файлы примера `tarantool_clusters_federation`;

> [!NOTE]
>  Есть два способа получить исходные файлы примера:
>  * Репозиторий [github.com/tarantool/tarantooldb-examples](https://github.com/tarantool/tarantooldb-examples/tree/release-3x/master).
>    Пример `tarantool_clusters_federation` расположен в директории `examples/tarantool_clusters_federation`.
>  * Отдельный архив [tarantool_clusters_federation.zip](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Ftarantool%2Ftarantooldb-examples%2Ftree%2Frelease-3x%2Fmaster%2Fexamples%2Ftarantool_clusters_federation&filename=tarantool_clusters_federation), скачанный из этого репозитория.

## Запуск стенда

Перейдите в директорию с примером:

```shell
cd examples/tarantool_clusters_federation
```

Загрузите в эту директорию архив для развёртывания TCF и распакуйте его в новой папке `tcf_archive`:

```shell
mkdir tcf_archive
tar -xzvf tcf-<VERSION>.tar.gz --directory tcf_archive
```

Здесь:

- `VERSION` — версия продукта.

Пример: `tcf-0.7.0.tar.gz`.

Скопируйте в директорию `tcf` бинарные файлы `tcf-destination` и `tcf-gateway` из созданной директории `tcf_archive`:

```shell
cp tcf_archive/tcf-destination tcf && cp tcf_archive/tcf-gateway tcf
```

Для запуска примера не требуются архив с TCF и другие файлы из директории `tcf_archive`, так что их можно удалить:

```shell
rm -r tcf_archive
rm -r tcf-<VERSION>.tar.gz
```

Теперь запустите стенд:

```shell
make start
```

После запуска кластера становится доступен веб-интерфейс Tarantool Cluster Manager.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

Проверить состояние кластеров можно в TCM. Для этого выберите нужный кластер (`Tarantool DB Cluster 1` или `Tarantool DB Cluster 2`) в выпадающем списке **Clusters** над вкладкой **Stateboard**.
Перейдите на вкладку **Stateboard**. Всё настроено правильно, если узлы в кластере подсвечены зеленым цветом.

Запущенный стенд состоит из:
* двух кластеров Tarantool DB. Каждый кластер содержит 2 роутера и 2 набора реплик по 3 хранилища;
* кластера etcd из трех узлов;
* 1 [Tarantool Cluster Manager](https://www.tarantool.io/docs/tdb/ru/3_x/getting_started#getting_started-tcm) (TCM);
* сервиса репликатора Tarantool Clusters Federation.

На запущенном стенде настроена репликация из [**активного кластера 1**](http://localhost:8001) в [**пассивный кластер 2**](http://localhost:8002).
Настройки TCF доступны в веб-интерфейсе TCM по адресу [http://localhost:8081](http://localhost:8081) на вкладке **TCF**.
Подробная информация о доступных [опциях конфигурации TCF](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_yaml/) и [настройке TCF через веб-интерфейс](https://www.tarantool.io/ru/clustersfederation/doc/latest/references/configuration_reference_cluster_ui/)
приведена в документации Tarantool Clusters Federation.

## Описание миграции
В примере создан спейс `writers` со следующим форматом:

```lua
local space = box.schema.space.create('writers')

space:format({
    {name = 'id', type = 'number'},
    {name = 'bucket_id', type = 'number'},
    {name = 'name', type = 'string'},
    {name = 'age', type = 'number'},
})

space:create_index('primary', {parts = {'id'}})
space:create_index('bucket_id', {parts = {'bucket_id'}})
```

## Репликация данных с первого кластера на второй

Подключитесь к роутеру `router-msk` в кластере 1 через TCM. Для этого:

1. В TCM выберите кластер `Tarantool DB Cluster 1` в выпадающем списке **Clusters** над вкладкой **Stateboard**.
2. Перейдите на вкладку **Stateboard**.
3. Нажмите на набор реплик `router-msk`.
4. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Во вкладке **Terminal** добавьте в спейс новый кортеж:

```lua
crud.insert_object('writers', {
    id = 1,
    name = 'Haruki Murakami',
    age = 75
}, {
    noreturn = true
})
```

Проверьте, что в спейсе появились данные.
Для этого в TCM перейдите на вкладку **Tuples** и выберите в списке спейс `writers`.
В открывшейся вкладке видно, что в спейс добавлен новый кортеж `Haruki Murakami`.

Теперь переключитесь на второй кластер (`Tarantool DB Cluster 2`) в левом верхнем меню TCM.
Откройте вкладку **Tuples** и убедитесь, что репликация на первый кластер прошла успешно — в спейсе `writers` тоже появился новый кортеж.

## Изменение направления межкластерной репликации

В TCF один кластер имеет активный *статус* и принимает все запросы от приложения.
Второй кластер имеет пассивный статус и содержит копию данных активного кластера.

Проверьте статус первого кластера:
```
http://localhost:8001/tcf/status
active
```

Проверьте статус второго кластера:
```
http://localhost:8002/tcf/status
passive
```

Чтобы нарушить состояние первого кластера, остановите один из его узлов хранилища:
```
cd ../ && docker compose -f cluster1/docker-compose.yml stop cluster1-storage-1-msk
```

Теперь снова проверьте статусы кластеров:
```shell
http://localhost:8001/tcf/status
passive
http://localhost:8002/tcf/status
active
```

Видно, что направление репликации переключилось — теперь второй кластер стал активным, а первый — пассивным.

Восстановите работу экземпляра в первом кластере:
```shell
docker compose -f cluster1/docker-compose.yml start cluster1-storage-1-msk
```

## Репликация данных со второго кластера на первый

Подключитесь к роутеру `router-msk` во втором кластере через TCM. Для этого:

1. В TCM выберите кластер `Tarantool DB Cluster 2` в выпадающем списке **Clusters** над вкладкой **Stateboard**.
2. Перейдите на вкладку **Stateboard**.
3. Нажмите на набор реплик `router-msk`.
4. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Во вкладке **Terminal** добавьте в спейс новый кортеж:

```shell
crud.insert_object('writers', {
    id = 2,
    name = 'Eiji Mikage',
    age = 41
}, {
    noreturn = true
})
```

Проверьте, что в спейсе появились данные.
Для этого в TCM перейдите на вкладку **Tuples** и выберите в списке спейс `writers`.
В открывшейся вкладке видно, что в спейс добавлен новый кортеж `Eiji Mikage`.

Теперь переключитесь на первый кластер (`Tarantool DB Cluster 1`) в левом верхнем меню TCM.
Откройте вкладку **Tuples** и убедитесь, что репликация на первый кластер прошла успешно — в спейсе `writers` тоже появился новый кортеж.

## Отключение стенда

Чтобы отключить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
