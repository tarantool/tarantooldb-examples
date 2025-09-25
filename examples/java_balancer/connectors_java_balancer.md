(connectors-java_balancer)=
# Балансировка запросов к роутерам через Java-коннектор

В примере демонстрируется работа с повреждённым кластером под нагрузкой.
Приложение непрерывно записывает кортежи пачками через все роутеры по очереди.
Для записи используется операция `replace`.
Если какой-либо роутер упал, трафик с него переключается на остальные роутеры.
Если роутер поднялся, трафик на него возвращается.

Для мониторинга используются:

* [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) -- сбор метрик;
* [InfluxDB](https://www.influxdata.com/) -- хранение метрик;
* [Grafana](https://grafana.com/) -- визуализация метрик.

```{admonition} Примечание
:class: note

Пример стенда с [Prometheus](https://prometheus.io/) приведен в разделе [Балансировщик запросов к роутерам через Go-коннектор](connectors-go_balancer).
```

Содержание:

* [](user_guide-java_balancer-prereq)
* [](user_guide-java_balancer-start_example)
* [](user_guide-java_balancer-grafana)
* [](user_guide-java_balancer-increase_load)
* [](user_guide-java_balancer-stop_router)
* [](user_guide-java_balancer-start_router)
* [](user_guide-java_balancer-stop_example)

(user_guide-java_balancer-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* Maven;
* Java версии 8+;
* конфигурация Maven -- для загрузки Java-коннектора.
  Чтобы задать эту конфигурацию, используйте инструкцию [Установка клиента tarantool-java-ee](user_guide-connectors-install_java);
* исходные файлы примера `java_balancer`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `java_balancer` расположен в таком архиве в директории `./doc/examples/java_balancer/`.
    
  * Отдельный архив [java_balancer.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/java_balancer/java_balancer.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-java_balancer-start_example)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3000
* 3301--3306
* 8081
* 8086
* 9090

Перейдите в директорию `java_balancer`:

```shell
cd ./doc/examples/java_balancer
```

Стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 2 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);

- кластера etcd из 3 узлов;
- клиентского приложения, подающего нагрузку;
- средств мониторинга -- Telegraf, InfluxDB, Grafana.

Запустите всё, кроме клиентского приложения, командой:

```shell
make start
```

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host). Также
после запуска доступны следующие пользовательские интерфейсы:
* http://localhost:8081 -- веб-интерфейс TCM;
* http://localhost:3000 -- веб-интерфейс Grafana.

Для входа в веб-интерфейс TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.
Выберите в наборе реплик `router-msk` узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.
Во вкладке **Terminal** проверьте наличие спейса `test`:

```lua
box.space
```

Спейс `test` должен присутствовать в выводе, он создается при запуске кластера.

(user_guide-java_balancer-grafana)=
## Панель Grafana

Откройте в браузере веб-интерфейс Grafana по адресу [http://localhost:3000/dashboards](http://localhost:3000/dashboards).
В списке **Dashboards** откройте папку **General** и выберите панель **Tarantool 3 dashboard** в выпадающем списке.
Проверьте, что графики показывают данные за последние 5 минут, а частота обновления равна 5 секундам:

![](images/grafana-panel.png)

Разверните панель **Tarantool network activity** и откройте график **Processed requests**.
Чтобы развернуть график на полный экран, нажмите на графике кнопку **...** (**Menu**) в правом верхнем углу и нажмите в выпадающем меню
кнопку **View**.
Выберите роутеры на графике, используя один из способов ниже:

* Нажмите на название `router-msk` и, зажав `Shift`, нажмите на `router-spb`.
* Используйте переключатель сверху (**Instances**), чтобы выбрать роутеры на уровне всего дашборда.

![](images/pr-1.png)

После перейдите на панель **Tarantool operations statistics** и откройте график **REPLACE space requests**.
Выберите все узлы, кроме роутеров:

![](images/replace-1.png)

(user_guide-java_balancer-increase_load)=
## Увеличение нагрузки

Откройте вторую вкладку локального терминала.
В этой вкладке перейдите в директорию `java_balancer`:

```shell
cd ./doc/examples/java_balancer
```

Запустите клиентское приложение:

```shell
mvn clean compile
mvn exec:java -Dexec.mainClass="org.example.App"
```

На графиках теперь заметна растущая нагрузка:
* растет число обработанных запросов на роутерах:
  
  ![](images/pr-2.png)

* растет число операций `replace` в единицу времени:

  ![](images/replace-2.png)

Проверьте, что в спейсе `test` появились данные.
Для этого в веб-интерфейсе TCM перейдите на вкладку **Tuples** и выберите в списке спейс `test`.
Откроется новая вкладка с содержимым кортежей спейса `test`.

(user_guide-java_balancer-stop_router)=
## Имитация отказа роутера

В первом терминале перейдите в директорию `cluster`:

```shell
cd cluster
```

Чтобы имитировать отказ роутера, выполните следующую команду:
```shell
docker compose stop tarantool-router-msk
```

Теперь в TCM во вкладке **Stateboard** узел `router-msk` отмечен серым -- это значит, что он отключен.
График запросов изменится так:

![](images/pr-3.png)

Нагрузка на второй роутер увеличилась вдвое.
График для второго роутера выглядит так:

![](images/pr-4.png)

Роста нагрузки на этом графике нет.
График прерывается, так как роутер не работает и метрики с него не поступают.
Количество операций `replace` при этом не изменилось:

![](images/replace-3.png)

(user_guide-java_balancer-start_router)=
## Восстановление роутера

Для запуска первого роутера выполните следующую команду в директории `cluster`:

```shell
docker compose start tarantool-router-msk
```

В TCM во вкладке **Stateboard** видно, что узел `router-msk` восстановлен.
Нагрузка на второй роутер уменьшилась вдвое, появились данные по нагрузке с первого:

![](images/pr-5.png)

Число операций `replace` не изменилось:

![](images/replace-4.png)

(user_guide-java_balancer-stop_example)=
## Остановка стенда

Для остановки стенда:

* В первом локальном терминале вернитесь в директорию `java_balancer`:

  ```shell
  cd ./doc/examples/java_balancer
  ```

  Выполните следующую команду:

  ```shell
  make stop
  ```
  
* Во втором локальном терминале выполните команду `Ctrl + Z`.
