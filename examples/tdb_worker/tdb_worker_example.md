(admin_guide-tdb_worker)=
# Пример реализации tdb-worker на Go


Доступно с версии 3.1.0.

В этом руководстве показано, как разрабатывать приложения Go-воркеров для работы с Tarantool DB с помощью библиотек из экосистемы Tarantool.
Воркер -- это программа на языке Go, которая:

- использует библиотеки из экосистемы Tarantool для работы с кластером и централизованным хранилищем конфигурации;
- хранит свою конфигурацию в централизованном хранилище конфигурации -- etcd или
  хранилище на основе Tarantool (*Tarantool-based configuration storage*, далее -- TBCS).

Использование воркера позволяет:

- вынести сложную логику по работе с данными отдельно от Tarantool;
- предоставить удобные интерфейсы доступа к данным;
- интегрировать экземпляры воркера с кластером Tarantool DB -- например при развертывании через ATE и взаимодействии через веб-интерфейс TCM.

```{admonition} Примечание
:class: note

Запуск с помощью Docker Compose является вспомогательным и используется для тестирования и демонстрации
в примерах документации. Для целевого развертывания используйте [инсталлятор Ansible Tarantool Enterprise](admin_guide-deploy_ate).
```

Содержание:

* [](admin_guide-tdb_worker-prereq)
* [](admin_guide-tdb_worker-start_example)
* [](admin_guide-tdb_worker-files)
* [](admin_guide-tdb_worker-build_worker)
* [](admin_guide-tdb_worker-run_worker)
* [](admin_guide-tdb_worker-cluster_interaction)
* [](admin_guide-tdb_worker-monitoring)
* [](admin_guide-tdb_worker-stop_example)

(admin_guide-tdb_worker-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* утилита `etcdctl`;
* компилятор Go;
* исходные файлы примера `tdb_worker`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `tdb_worker` расположен в таком архиве в директории `./doc/examples/tdb_worker/`.
    
  * Отдельный архив [tdb_worker.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/tdb_worker/tdb_worker.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-tdb_worker-start_example)=
## Запуск стенда

Перейдите в директорию примера `tdb_worker`:

```shell
cd ./doc/examples/tdb_worker/
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:

- кластера Tarantool DB (2 роутера, 2 набора реплик по 3 хранилища);
- кластера etcd из 3 узлов для хранения конфигурации;
- 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- средств мониторинга -- [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

(admin_guide-tdb_worker-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `tdb_worker`:

* `cluster/config.yml` — конфигурация и топология кластера;
* `cluster/docker-compose.yml` — описание узлов кластера Tarantool DB;
* `docker-compose-worker.yml` — описание узлов воркера;
* `main.go` — исходный код воркера;
* `http-server-1-config.yml` — конфигурация первого воркера;
* `http-server-2-config.yml` — конфигурация второго воркера.

(admin_guide-tdb_worker-build_worker)=
## Сборка воркера

Исходный код воркера хранится в файле `main.go` в примере `tdb_worker`.

Для сборки воркера выполните команду ниже:

```shell
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/http-server ./main.go
```

Конфигурация воркера хранится в файлах `http-server-1-config.yml`, `http-server-2-config.yml` и загружается в хранилище конфигурации
(в примере это etcd) при запуске стенда.

Прочитать её можно так:

```shell
ETCDCTL_API=3 etcdctl get --prefix '/tdb-workers/'
```

Сама конфигурация выглядит так:

```yaml
/tdb-workers/tdb/instances/127.0.0.1/http-server-1
type: nontarantool
instrumentation: # опции для мониторинга
    url:            worker-1:9080
    metrics_url:    /metrics
    metrics_format: "prometheus"
    liveness_url:   /alive
    info_url:       /info
    binary:         ./bin/http-server
config: # произвольная конфигурация воркера
    addr:                       0.0.0.0:10000
    tarantool_cluster_prefix:   /tdb/config/all
    tarantool_user:             admin
    tarantool_pass:             secret-cluster-cookie
```


Описание конфигурации приведено в соответствующем разделе [справочника](configuration_reference-worker).

У каждого воркера конфигурация хранится по отдельному ключу:

* `/tdb-workers/tdb` — префикс для хранения конфигураций экземпляров воркеров;
* `127.0.0.1` — адрес хоста воркера (*ansible host*);
* `http-server-1` — имя воркера.

Префикс для конфигурации воркеров можно задать через веб-интерфейс TCM. Для этого:

1. В TCM перейдите на вкладку **Clusters** и нажмите на кнопку
вызова меню **...** (**Actions**) справа от нужного кластера (в примере это кластер **Tarantool DB Cluster**).
2. В выпадающем меню выберите пункт **Edit** и перейдите на вкладку настроек **Config storage connection**, нажав кнопку **Next**.
3. На вкладке **Config storage connection** введите название префикса в поле **Workers prefix**.

![edit_prefix](./images/edit_cluster.png)

(admin_guide-tdb_worker-run_worker)=
## Запуск воркера

Для старта воркера обязательны следующие переменные окружения:

- `TDB_WORKER_NAME=http-server-1` — имя воркера. Тип: `string`;
- `TDB_WORKER_HOST_NAME=127.0.0.1` — название хоста, на котором расположен воркер.  Тип: `string`.
- `TDB_WORKER_CONFIG_ETCD_PREFIX=/tdb-workers/tdb/instances` — путь префикса в централизованном хранилище конфигурации etcd, который указывает расположение конфигурации воркеров. Тип: `string`.

Также можно указать дополнительные параметры для подключения, аналогичные параметрам для Tarantool:

- `TDB_WORKER_CONFIG_ETCD_USERNAME` — имя пользователя для подключения к централизованному хранилищу конфигурации etcd. Тип: `string`. Значение по умолчанию: `""`;
- `TDB_WORKER_CONFIG_ETCD_PASSWORD` — пароль для подключения к централизованному хранилищу конфигурации etcd. Тип: `string`. Значение по умолчанию: `""`;
- `TDB_WORKER_CONFIG_ETCD_ENDPOINTS=http://etcd1:2379` — список узлов централизованного хранилища конфигурации для подключения, узлы указываются через запятую. Тип: `array`;

Также можно указать опции SSL-подключения:

- `TDB_WORKER_CONFIG_ETCD_SSL_VERIFY_PEER` -- наличие проверки peer-сертификата etcd. Тип: `boolean`.  Значение по умолчанию: `false`;
- `TDB_WORKER_CONFIG_ETCD_SSL_VERIFY_HOST` -- наличие проверки master-сертификата etcd. Тип: `boolean`.  Значение по умолчанию: `false`;
- `TDB_WORKER_CONFIG_ETCD_SSL_CA_PATH` -- путь к доверенному CA-сертификату, используемому для установки соединения с etcd. Тип: `string`;
- `TDB_WORKER_CONFIG_ETCD_SSL_CERT` -- путь к клиентскому SSL-сертификату, используемому для установки соединения с etcd. Тип: `string`;
- `TDB_WORKER_CONFIG_ETCD_SSL_KEY` -- путь к клиентскому SSL-ключу, используемому для установки соединения с etcd. Тип: `string`.

Для TBCS используются cхожие параметры, но с другим префиксом.
- `TDB_WORKER_CONFIG_STORAGE_PREFIX`
- `TDB_WORKER_CONFIG_STORAGE_ENDPOINTS`

Подробнее см. документацию по настройке [etcd](https://www.tarantool.io/en/doc/latest/reference/configuration/configuration_reference/#config-etcd) и [config‑storage](https://www.tarantool.io/en/doc/latest/reference/configuration/configuration_reference/#config-storage).

Если зайти в TCM по адресу [http://localhost:8081](http://localhost:8081), на вкладке **Stateboard** вы увидите секцию с воркерами:
![gray_workers](./images/workers_gray.png)
Сейчас эти узлы отключены, поэтому они подсвечены серым цветом.
Если нажать на такой узел, в открывшемся окне  будет видно, что узел имеет статус `no-connection`:

![empty_worker](./images/workers_empty.png)


Запустите воркеры:

```shell
docker compose -f docker-compose-worker.yml up -d worker-1 worker-2
```

Проверьте логи:

```shell
docker compose -f docker-compose-worker.yml logs
```

В логах должны появиться следующие строки:

```
worker-1-1  | http-server-1 /tdb-workers/tdb/instances/127.0.0.1
worker-1-1  | 2026-01-29T11:36:39Z INFO /home/user/tarantooldb/doc/examples/tdb_worker/main.go:213 "starting http server" addr=0.0.0.0:10000
worker-1-1  | 2026-01-29T11:36:39Z INFO /home/user/tarantooldb/doc/examples/tdb_worker/main.go:194 "starting instrumentation server" addr=worker-1:9080
worker-2-1  | http-server-2 /tdb-workers/tdb/instances/127.0.0.1
worker-2-1  | 2026-01-29T11:36:39Z INFO /home/user/tarantooldb/doc/examples/tdb_worker/main.go:213 "starting http server" addr=0.0.0.0:10001
worker-2-1  | 2026-01-29T11:36:39Z INFO /home/user/tarantooldb/doc/examples/tdb_worker/main.go:194 "starting instrumentation server" addr=worker-2:9081
```

В TCM воркеры будут отображаться так:

![green_workers](./images/workers_green.png)

Воркер запускает два простых HTTP‑сервера:
- сервер для доступа к спейсу `bands`;
- сервер для мониторинга и интеграции с TCM.

Добавьте новые кортежи в спейс `bands`:

```shell
curl -X POST http://127.0.0.1:10000/api/bands -d '{"id":1,"band_name":"name", "year":2024}'
curl -X POST http://127.0.0.1:10001/api/bands -d '{"id":2,"band_name":"name-2", "year":2025}'
```

Теперь прочитайте записанные кортежи:

```shell
curl http://127.0.0.1:10000/api/bands/1
curl http://127.0.0.1:10000/api/bands/2
```

Ответ:
```json
{"id":1,"band_name":"name","year":2024}
{"id":2,"band_name":"name-2","year":2025}
```

(admin_guide-tdb_worker-cluster_interaction)=
## Взаимодействие с кластером Tarantool DB

Воркер использует библиотеку `go‑discovery`, которая позволяет реагировать на изменения конфигурации кластера и динамически обновлять группу соединений. Это позволяет добавлять и удалять узлы без перезапуска воркера.

В коде это реализовано следующим образом:

1. Создание группы соединений для подключения к кластеру Tarantool DB:

    ```go
    // Create pool for tarantool DB cluster.
    pool, err := pool.NewPool(
        dial.NewNetDialerFactory(
            workerCfg.Config.TarantoolUser,
            workerCfg.Config.TarantoolPass,
            tarantool.Opts{
                Timeout: 5 * time.Second,
            },
        ),
        pool.NewRoundRobinBalancer(),
    )
    ```

2. Подписка на изменения конфигурации (узлы с ролью `roles.crud‑router`):

    ```go
    // The scheduler will watch for updates from etcd.
    etcdWatcher := scheduler.NewEtcdWatch(
        clientv3,
        workerCfg.Config.TarantoolClusterPrefix,
    )
    defer etcdWatcher.Stop()

    disc := discoverer.NewFilter(
        // The base discoverer gets a list of instance configurations from
        // etcd.
        discoverer.NewEtcd(clientv3,
            strings.TrimSuffix(
                workerCfg.Config.TarantoolClusterPrefix,
                "/config/all",
            ),
        ),
    )

    // The Subscriber will send instance configurations into the pool
    // on updates.
    etcdSubscriber := subscriber.NewFilter(
        subscriber.NewSchedule(etcdWatcher, disc),
        // etcdSubscriber will track new crud-routers in cluster configuration
        filter.RolesContain{
            Roles: []string{"roles.crud-router"},
        },
    )
    ```

Подробная информация приведена в документации [go‑discovery](https://github.com/tarantool/go-discovery).

### Работа с библиотекой go‑discovery

1. В веб‑интерфейсе TCM перейдите на вкладку **Configuration** и раскомментируйте конфигурацию для узла `router‑brn`:

    ```yaml
    router-brn:
        leader: router-brn
        instances:
         router-brn:
           iproto:
             listen:
               - uri: tarantool-router-brn:3301
             advertise:
               client: tarantool-router-brn:3301
    ```

2. Нажмите **Save** и затем **Apply**, чтобы сохранить и применить новую конфигурацию кластера.
3. В журнале событий воркера появится сообщение об отсутствии подключения к узлу `router‑brn`.
4. Запустите экземпляр `router‑brn`:

    ```shell
    docker compose -f docker-compose-worker.yml up -d tarantool-router-brn
    ```

5. Теперь запросы будут распределяться и на `router‑brn`.
6. Для дополнительной проверки можно закомментировать конфигурации экземпляров `router‑msk` и `router‑spb`, а затем остановить соответствующие контейнеры.

    ```shell
        docker compose -f cluster/docker-compose.yml down tarantool-router-msk
        docker compose -f cluster/docker-compose.yml down tarantool-router-spb
    ```
    Воркер продолжит работать, используя оставшиеся роутеры.

Возможность реагировать на изменения конфигурации и реконфигурировать группу соединений значительно повышает гибкость воркера.

Также обратите внимание на библиотеку [go-tlog](https://github.com/tarantool/go-tlog) -- это обертка пакета `slog`, которая позволяет воркеру писать логи в том же формате, что и Tarantool. Такой подход полезен для анализа логов.

(admin_guide-tdb_worker-monitoring)=
## Мониторинг состояния воркера и интеграция с TCM

Воркер предоставляет три адреса обработчика запроса (*endpoints*) для отслеживания своего состояния и интеграции с TCM:

- [/healthcheck](admin_guide-tdb_worker-healthcheck) -- проверка работоспособности узла воркера;
- [/metrics](admin_guide-tdb_worker-metrics) -- метрики экземпляра воркера;
- [/info](admin_guide-tdb_worker-info) -- общая информация о воркере.

Задавать эти адреса обработчика запроса необязательно, но они позволяют TCM взаимодействовать с воркером.
Хранение конфигурации в централизованном хранилище конфигурации, формат конфигурации и указание таких адресов обработчика запроса позволяют успешно интегрировать воркер в поставку вместе с Tarantool DB.

(admin_guide-tdb_worker-healthcheck)=
### Проверка работоспособности воркера

Запрос возвращает в ответе один из следующих HTTP-статусов:

- `200` с телом ответа `{"status":"alive"}` -- узел воркера здоров, все проверки завершены успешно;
- `500` с телом ответа `{"status":"dead", "details":{"error": "error_message"}}` -- воркер недоступен, описание проблем приведено в поле `details`. Пример ответа: `{"status":"dead", "details":{"tdb_unreachable":"failed to connect to host.private:3301"}}`;
- `520` с телом ответа `{"status":"degraded", "details":{"error": "error_message"}}` -- в работе воркера возникли проблемы, их описание приведено в поле `details`. Пример ответа: `{"status":"degraded", "details":{"memory":"memory limit reached"}}`.

Значение в ответе определяет, каким цветом подсвечен узел воркера в TCM:

* `alive` -- зелёный;
* `dead` -- красный;
* `degraded` -- жёлтый.

(admin_guide-tdb_worker-metrics)=
### Метрики

Адрес обработчика запроса `/metrics` отдаёт метрики в формате Prometheus:

```shell
curl http://127.0.0.1:9080/metrics | head -n 5
curl http://127.0.0.1:9081/metrics | head -n 5
```

Чтобы просмотреть метрики воркера в TCM, перейдите на вкладку **Stateboard**, нажмите на соответствующий узел, и в открывшемся окне перейдите на вкладку **Metrics**: 

![metrics](./images/worker_metrics.png)

Подробная информация о мониторинге в Tarantool DB и доступных метриках приведена в разделе [](admin_guide-monitoring).

(admin_guide-tdb_worker-info)=
### Информация о воркере

Адрес обработчика запроса `/info` предоставляет общую информацию о воркере:

```shell
curl http://127.0.0.1:9080/info
```

Формат ответа выглядит так:

```json
{
  "version": "1.0.0",
  "uptime_seconds": 362349.44,
  "memory_usage_bytes": 209213124,
  "extra_info": {
    "env": "staging",
    "my_custom": "foo-bar"
  }
}
```

Чтобы просмотреть информацию о воркере в TCM, перейдите на вкладку **Stateboard** и нажмите на соответствующий узел. Откроется окно **Details**: 

![info](./images/worker_info.png)


(admin_guide-tdb_worker-stop_example)=
## Остановка стенда

Для остановки стенда выполните в локальном терминале команды ниже:

```shell
make stop
docker compose -f docker-compose-worker.yml down
```
