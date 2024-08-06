(connectors-go_balancer)=
# Балансировка запросов к роутерам через Go-коннектор

В примере демонстрируется работа с повреждённым кластером под нагрузкой.
Приложение непрерывно записывает кортежи пачками через все роутеры по очереди.
Для записи используется операция `replace`.
Если какой-либо роутер стал недоступен, трафик с него переключается на другие роутеры. 
Если роутер снова стал доступен, трафик на него возвращается.

Для мониторинга используются:

* [Prometheus](https://prometheus.io/) -- сбор и хранение метрик;
* [Grafana](https://grafana.com/) -- визуализация метрик.

```{admonition} Примечание
:class: note

Пример стенда с [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) и [InfluxDB](https://www.influxdata.com/)
приведен в разделе [Балансировщик запросов к роутерам через Java-коннектор](connectors-java_balancer).
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

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* Go;
* исходные файлы примера `go_balancer`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `go_balancer` расположен в таком архиве в директории `./doc/examples/go_balancer/`.
    
  * Отдельный архив [go_balancer.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/go_balancer/go_balancer.tar.gz), скачанный c сайта Tarantool.
  ```
 
(user_guide-go_balancer-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 3301--3306
* 8081
* 3000

Перейдите в директорию `go_balancer/tt`:

```shell
cd ./doc/examples/go_balancer/tt
```

Стенд состоит из:
- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 2 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
  - 2 координатора автоматического восстановления после сбоев (*failover coordinator*);
- кластера etcd из 3 узлов;
- клиентского приложения, подающего нагрузку;
- средств мониторинга -- [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/).

Запустите всё, кроме клиентского приложения, следующей командой:

```shell
docker compose up -d
```

После запуска должны работать все контейнеры, кроме `init_host`. Также
после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 -- веб-интерфейс TCM;
* http://localhost:3000 -- веб-интерфейс Grafana.

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

8. Выберите любой роутер из списка (например, `router-1`) и в открывшемся окне перейдите на вкладку **Terminal**.
9. Во вкладке **Terminal** введите команду `box.space`. Проверьте, что в выводе есть спейс `test` -- этот спейс создается при запуске кластера.

(user_guide-go_balancer-grafana)=
## Панель Grafana

Откройте в браузере веб-интерфейс Grafana по адресу [http://localhost:3000/dashboards](http://localhost:3000/dashboards).
В списке **Dashboards** откройте папку **General** и выберите панель **Tarantool dashboard** в выпадающем списке.
Проверьте, что графики показывают данные за последние 5 минут, а частота обновления равна 5 секундам:

![](images/grafana-panel.png)

Разверните панель **Tarantool network activity** и откройте график **Processed requests**.
Чтобы развернуть график на полный экран, нажмите на графике кнопку **...** (**Menu**) в правом верхнем углу и нажмите в выпадающем меню
кнопку **View**.
Выберите роутеры на графике, используя один из способов ниже:

* Нажмите на название `router-1` и, зажав `Shift`, нажмите на `router-2`.
* Используйте переключатель сверху (**Instances**), чтобы выбрать роутеры на уровне всего дашборда.

![](images/processed-requests-1.png)

После перейдите на панель **Tarantool operations statistics** и откройте график **REPLACE space requests**.
Выберите все узлы, кроме роутеров:

![](images/replace-1.png)

Затем перейдите на панель **CRUD module statistics** и откройте график **REPLACE success requests**:

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

Теперь проверьте, что в спейсе `test` появились данные. Для этого:

1. В TCM перейдите на вкладку **Tuples**.
2. Выберите в списке спейс `test`. Откроется новая вкладка с содержимым кортежей спейса `test`.

(user_guide-go_balancer-stop_router)=
## Имитация отказа роутера

Чтобы имитировать отказ роутера, в первом терминале выполните команду:
```shell
docker compose stop tarantool-router-1
```

Теперь в TCM во вкладке **Stateboard** узел `router-1` помечается как нездоровый (`unhealthy`).
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
docker compose start tarantool-router-1
```

В TCM во вкладке **Stateboard** видно, что узел `router-1` восстановлен.
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
