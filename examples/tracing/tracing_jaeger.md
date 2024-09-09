(user_guide-tracing_jaeger)=
# Трассировка с использованием Jaeger

В этом руководстве описано, как настроить трассировку функций, а также просмотреть и оценить результаты трассировки
в веб-интерфейсе [Jaeger](https://www.jaegertracing.io/).

Подробнее о модуле `tracing` можно узнать в разделе [Оценка производительности](user_guide-tracing).

Руководство включает следующие шаги:

* [](user_guide-tracing_jaeger-prereq)
* [](user_guide-tracing_jaeger-start_example)
* [](user_guide-tracing_jaeger-set_config)
* [](user_guide-tracing_jaeger-connect)
* [](user_guide-tracing_jaeger-tracing_result)
* [](user_guide-tracing_jaeger-stop_example)

(user_guide-tracing_jaeger-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленный [Docker-образ](install_docker-image) Tarantool DB;
* приложение Docker Compose;
* утилита [tt CLI](install-install_tt);
* сервис для сбора данных трассировки [Jaeger](https://www.jaegertracing.io/);
* исходные файлы примера `tracing`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-2.0.0.tar.gz`.
    Пример `tracing` расположен в таком архиве в директории `./doc/examples/tracing/`.
    
  * Отдельный архив [tracing.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/tracing/tracing.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-tracing_jaeger-start_example)=
## Запуск стенда

Перейдите в директорию примера `tracing`:

```
cd ./doc/examples/tracing/
```

Запустите стенд:

```shell
make start
```

Запущенный стенд состоит из:
- кластера Tarantool DB:
   - 1 роутер;
   - 2 набора реплик по 1 хранилищу;
- кластера etcd из 3 узлов;
- 1 узла [Tarantool Cluster Manager](getting_started-tcm) (TCM).
- сервиса Jaeger для сбора данных трассировки.

После запуска должны работать все контейнеры, кроме  [init_host](admin_guide-deploy_docker_compose-init_host).

Также после запуска кластера становится доступен веб-интерфейс TCM.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:
- **Username**: `admin`
- **Password**: `secret`

(user_guide-tracing_jaeger-set_config)=
## Определение конфигурации

В примере указаны следующие параметры трассировки:

```{literalinclude} cluster/config.yml
:start-at: roles_cfg
:end-at: spans_limit
:language: yaml
:dedent:
```

Здесь:

* `enabled` -- включает трассировку;
* `global_sample_rate` -- глобальный коэффициент частоты трассировки запросов, при значении `0` запросы не трассируются;
* `sample_rates` -- коэффициенты частоты трассировки для заданных сегментов (spans);
* `base_url` -- URL-адрес сервера, куда отправляются данные трассировки;
* `api_method` -- HTTP-метод, который используется для отправки данных трассировки на сервер;
* `report_interval` -- интервал в секундах между отправкой данных трассировки на сервер;
* `spans_limit` -- максимальное количество сегментов (span) трассировки, которые могут быть сохранены локально
на экземпляре Tarantool перед отправкой во внешнюю систему хранения результатов трассировки.

По умолчанию сегменты (span) трассировки не засекают время выполнения участков кода.
Время выполнения участков кода засекается, если выполнено одно из следующих условий:

* В контексте указан параметр `sample: true`.
* Название родительского сегмента трассировки будет `get_token_router` или `debug_1`.
Вероятность замера времени для нового сегмента при этом будет равна 1/N (1/2 и 1 соответственно).

Параметры `tracing.base_url`, `tracing.api_method`, `tracing.report_interval` и tracing.`spans_limit` отвечают за
отправку результатов трассировки в сторонний сервис Jaeger.

Полное описание опций конфигурации `tracing` приведено в соответствующем разделе [Справочника по конфигурации](configuration_reference-tracing).

(user_guide-tracing_jaeger-connect)=
## Подключение к узлу

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Сделать это можно двумя способами:
- В терминале с помощью команды `tt connect`:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

- В веб-интерфейсе TCM.

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:
	
1. Перейдите на вкладку **Stateboard**.
2. Нажмите на набор реплик `router`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

(user_guide-tracing_jaeger-tracing_result)=
## Оценка результатов трассировки

В TCM во вкладке **Terminal** запустите несколько тестовых функций на роутере:

```lua
for i = 1, 10 do
   box.func.get_token:call({"test"})
end
box.func.debug_func:call({"debug_1"})
box.func.debug_func:call({"debug_2"})
```

После этого зайдите в веб-интерфейс Jaeger на [http://127.0.0.1:16686](http://127.0.0.1:16686).
В поле `Service` выберите `tarantool-router-msk:3301` и нажмите кнопку `Find Traces`.
В результате вы увидите примерно 4 результата трассировки для функции `get_token_router()` и ровно 1 результат для функции `debug_func()` с сегментом `debug_1`.

![Результаты трассировки](images/tracing_results.jpg)

Если открыть результат трассировки для функции `get_token_router()`, можно увидеть, что функция `get_token_router()` выполняется примерно за 14 мс:

* 10 мс занимает выполнение функции на экземпляре `storage`;
* 4 мс занимает коммуникация экземпляров по сети до и после вызова функции на экземплярях `storage`.

Логика, выполняемая на экземпляре `storage`, занимает 80% времени, следовательно, оптимизацию кода следует начать с него.

![Результат трассировки функции get_token()](images/tracing_get_token.jpg)

(user_guide-tracing_jaeger-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```

