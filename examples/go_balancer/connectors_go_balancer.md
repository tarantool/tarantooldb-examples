# Балансировка запросов к роутерам через Go-коннектор

В примере демонстрируется работа с повреждённым кластером под нагрузкой.
Приложение непрерывно записывает кортежи пачками через все роутеры по очереди.
Для записи используется операция `replace`.
Если какой-либо роутер упал, трафик с него переключается на остальные роутеры.
Если роутер поднялся, трафик на него возвращается.

Для мониторинга используются:

* Prometheus -- сбор и хранение метрик;
* Grafana -- визуализация метрик.

```{admonition} Примечание
:class: note

Пример стенда с Telegraf и InfluxDB приведен в разделе [Балансировщик запросов к роутерам через Java-коннектор](/examples/java_balancer/connectors_java_balancer.md).
```

Содержание:

* [](user_guide-go_balancer-prereq)
* [](user_guide-go_balancer-start_example)
* [](user_guide-go_balancer-grafana)
* [](user_guide-go_balancer-increase_load)
* [](user_guide-go_balancer-stop_router)
* [](user_guide-go_balancer-start_router)
* [](user_guide-go_balancer-stop_example)

(user_guide-go_balancer-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](/install_and_upgrade/install/install_docker.md) Tarantool DB;
* приложение Docker compose;
* Go;
* исходные файлы примера `go_balancer`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-1.0.0.tar.gz`.
    Пример `go_balancer` расположен в таком архиве в директории `./doc/examples/go_balancer/`.
    
  * Отдельный архив [go_balancer.tar.gz](https://tarantool.io/ru/tarantooldb/doc/1.x/examples/go_balancer/go_balancer.tar.gz), скачанный c сайта Tarantool.
  ```
 
(user_guide-go_balancer-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны порты:

* 3301--3306;
* 8080--8086.


Перейдите в директорию `go_balancer/tt`:

```shell
cd ./doc/examples/go_balancer/tt
```

Запустите стенд:

```shell
docker compose up -d
```

Команда развернет стенд, состоящий из:
* кластера Tarantool DB (два шарда, два хранилища и два роутера);
* клиентского приложения, подающего нагрузку;
* средств мониторинга (Prometheus, Grafana).

После запуска должны работать все контейнеры, кроме `tarantool-db-init`. Также
после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8083 -- веб-интерфейс кластера Tarantool DB;
* http://localhost:8080 -- веб-интерфейс Grafana.

Теперь откройте в браузере веб-интерфейс Tarantool DB по адресу [http://localhost:8081](http://localhost:8081).
Перейдите во вкладку **Cluster** и проверьте, что отсутствуют ошибки или предупреждения.
В течение нескольких секунд после старта кластер еще поднимается, так что могут появиться предупреждения.

После этого перейдите на вкладку **Space Explorer** и выберите любой узел, например `storage1`.
Проверьте, что на узле есть спейс `test`.

(user_guide-go_balancer-grafana)=
## Панель Grafana

Откройте в Grafana панель
[Tarantool dashboard](http://localhost:8080/dashboards).
Проверьте, что графики показывают данные за последние 5 минут, а частота обновления равна 5 секундам:

![](images/grafana-panel.png)

В панели `Tarantool Network activity` откройте график `Processed requests`:

![](images/processed-requests-1.png)

Выделите роутеры. Есть два способа это сделать:
* нажмите на название `router-1` и, зажав `Shift`, нажмите на `router-2`.
* используйте переключатель сверху, чтобы выбрать роутеры на уровне всего дашборда:

![](images/select.png)

В панели `Tarantool operations statistics` откройте график `REPLACE space requests`.
Выберите все узлы, кроме роутеров:

![](images/replace-1.png)

В панели `CRUD module statistics"` откройте график `REPLACE success requests`:

![](images/crud-replace-1.png)

(user_guide-go_balancer-increase_load)=
## Увеличение нагрузки

Откройте вторую вкладку терминала.
В этой вкладке перейдите в директорию `go_balancer/go`:

```shell
cd ./doc/examples/go_balancer/go
```

Запустите клиентское приложение:

```shell
go run -tags go_tarantool_ssl_disable main.go
```

Здесь:

* `go_tarantool_ssl_disable` -- опция, отключающая поддержку TLS.
  Так как для поддержки TLS требуется установленный OpenSSL 3.x, для простоты в примере поддержка TLS отключена.

На графиках теперь заметно, что нагрузка растет:
* растет число обработанных запросов на роутерах:

  ![](images/processed-requests-2.png)

* растет число операций `replace` в единицу времени:

  ![](images/replace-2.png)

Включите отображение графиков хранилищ и оцените их:

![](images/crud-replace-2.png)

В веб-интерфейсе Tarantool DB откройте вкладку **Space Explorer** и проверьте, что в хранилищах появились данные.

(user_guide-go_balancer-stop_router)=
## Имитация отказа роутера

Чтобы имитировать отказ роутера, в первом терминале выполните команду:
```shell
docker compose stop tarantool-router1
```

Теперь в веб-интерфейсе Tarantool DB во вкладке **Cluster** узел `tarantool-router1` помечается как нездоровый (`unhealthy`).
График запросов изменится так:

![](images/processed-requests-3.png)

Нагрузка на второй роутер увеличилась вдвое.
График для второго роутера выглядит так:

![](images/processed-requests-4.png)

Роста нагрузки на этом графике нет.
График прерывается, так как роутер не работает и метрики с него не поступают.
Количество операций `replace` при этом не изменилось:

![](images/replace-3.png)

Кол-во операций `crud-replace` на рабочем роутере возросло:

![](images/crud-replace-3.png)

(user_guide-go_balancer-start_router)=
## Восстановление роутера

Для запуска первого роутера выполните следующую команду:

```shell
docker compose start tarantool-router1
```

В веб-интерфейсе Tarantool DB во вкладке **Cluster** видно, что узел `tarantool-router1` восстановлен.
Нагрузка на второй роутер уменьшилась вдвое, появились данные по нагрузке с первого:

![](images/processed-requests-5.png)

Число операций `replace` не изменилось:

![](images/replace-4.png)

Кол-во операций `crud-replace` на один роутер снизилось:

![](images/crud-replace-4.png)

(user_guide-go_balancer-stop_example)=
## Остановка стенда

Для остановки стенда:

* В первом терминале выполните команду:

    ```shell
    docker compose down
    ```
  
* Во втором терминале выполните команду `Ctrl + Z`.
