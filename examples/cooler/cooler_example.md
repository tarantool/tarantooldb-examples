(user_guide-cooler_example)=
# Пример архивации устаревших данных

Доступно с версии 3.0.0.

В этом руководстве приведен пример переноса пользовательских сессий старше 30 минут из спейса memtx в vinyl.

(user_guide-cooler_example-prereq)=
## Пререквизиты

Для выполнения примера вам понадобятся:

- установленный [Docker-образ](install_docker-image) Tarantool DB; 
- приложение Docker Compose;
- утилита [tt CLI](install-install_tt);
- исходные файлы примера `cooler`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `cooler` расположен в таком архиве в директории `./doc/examples/cooler/`.
    
  * Отдельный архив [cooler.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/cooler/cooler.tar.gz), скачанный c сайта Tarantool.
  ```

(user_guide-cooler_example-start_example)=
## Запуск стенда

Для успешного запуска стенда должны быть свободны следующие порты: 

* 2379
* 3301--3308
* 8081

Перейдите в папку с примером `cooler`:

```shell
cd ./doc/examples/cooler/
```

Запустите стенд:

```shell
make start
```

После выполнения команды будет развернут следующий стенд:
- кластер Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
- кластер etcd из 3 узлов;
- веб-интерфейс [Tarantool Cluster Manager](getting_started-tcm) (TCM).

После запуска должны работать все контейнеры, кроме `init_host`.
Контейнер `init_host` используется только для инициализации и завершает свою работу после настройки кластера.

Также после запуска кластера становится доступен веб-интерфейс TCM.
Через TCM вы можете управлять конфигурацией кластера, просматривать метрики кластера и подключаться к его узлам.
Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

(user_guide-cooler_example-create_space_memtx)=
## Создание спейса в memtx

В руководстве при запуске кластера применяется [миграция](user_guide-migrations) из файла
`./cluster/migrations/scenario/001_sessions.lua` примера `cooler`.
В этой миграции создан на движке memtx [шардированный спейс](admin_guide-sharding) `sessions` для хранения пользовательских сессий:

```{literalinclude} cluster/migrations/scenario/001_sessions.lua
:start-after: if is_storage() then
:end-before: box.schema.func.create(
:language: lua
:dedent:
```

(user_guide-cooler_example-setup)=
## Настройка архивации

Также в миграции, [описанной выше](user_guide-cooler_example-create_space_memtx), указаны [настройки процесса архивации](user_guide-cooler_example-setup_space)
для заданного спейса memtx и определено [условие](user_guide-cooler_example-set_func), по которому будет запускаться архивация.

(user_guide-cooler_example-setup_space)=
### Создание спейса vinyl

Метод [cooler.setup()](reference_lua-cooler-setup) настраивает процесс архивации для заданного спейса memtx.
Метод регистрирует условие архивации и создаёт архивный спейс в vinyl с указанными параметрами:

```{literalinclude} cluster/migrations/scenario/001_sessions.lua
:start-at: cooler.setup(
:end-before: end
:language: lua
:dedent:
```

По умолчанию имена функции и архивного спейса формируются автоматически на основе имени исходного спейса memtx следующим образом:

- имя функции-предиката -- `<space_name>_is_cooled`, в данном случае `sessions_is_cooled`.
  Может быть задано явно через параметр `is_cooled_fun_name`.
- имя архивного спейса vinyl -- `<space_name>_cold`, то есть `sessions_cold`.
  Может быть задано явно через параметр `vinyl_space_name`.

(user_guide-cooler_example-set_func)=
### Условие архивации

Функцию с условием архивации можно задать с помощью метода [cooler.set_func()](reference_lua-cooler-set_func).
В примере ниже также создана функция `sessions_updated_at_start_key`, которая возвращает порог времени для архивации.
Условие `t.updated_at < ...` означает, что нужно архивировать все сессии, обновлённые более 30 минут назад.

```{literalinclude} cluster/migrations/scenario/001_sessions.lua
:start-at: box.schema.func.create(
:end-before: cooler.setup(
:language: lua
:dedent:
```

(user_guide-cooler_example-check_spaces)=
### Проверка созданных спейсов

Проверить, что memtx-спейс `sessions` и соответствующий ему архивный спейс в vinyl созданы успешно, можно так:

1. В TCM перейдите на вкладку **Tuples**.
2. Если спейсы созданы успешно, в списке вы увидите два спейса:

   - `sessions` -- спейс в memtx для свежих сессий;
   - `sessions_cold` -- созданный спейс в vinyl для архивных сессий.

(user_guide-cooler_example-add_data)=
## Вставка тестовых данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера.
Это можно сделать двумя способами:

- через веб-интерфейс TCM;
- через терминал с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:

1. Перейдите в раздел **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal** (`TT Connect`).
   Теперь вы находитесь в интерактивной консоли Tarantool и можете выполнять запросы к кластеру.

Для удобства ввода данных определите вспомогательную функцию `now()`, которая получает текущее время:

```lua
function now()
    local clock = require('clock')
    return clock.time()
end
```

Теперь добавьте в спейс memtx несколько сессий с разным временем обновления: 

```lua
crud.insert_object_many('sessions', {
    { id = 1, status = 'active', updated_at = now() },           -- свежая
    { id = 2, status = 'closed', updated_at = now() - 60 * 5 },  -- 5 мин назад
    { id = 3, status = 'active', updated_at = now() - 60 * 15 }, -- 15 мин назад
    { id = 4, status = 'closed', updated_at = now() - 60 * 40 }, -- 40 мин назад
    { id = 5, status = 'active', updated_at = now() - 60 * 120 } -- 2 часа назад
})
```

(user_guide-cooler_example-enable)=
## Запуск архивации данных

Чтобы запустить фоновую задачу архивации:

1. В TCM перейдите во вкладку **Configuration** с YAML-конфигурацией кластера.
2. На вкладке **Configuration** добавьте в секцию экземпляров хранилищ (`storages`) технологическую роль `roles.cooler`
   и настройки этой роли в `roles_cfg`: 

    ```yaml
    storages:
      replication:
        failover: election
      sharding:
        roles: [storage]
      roles:
        - roles.crud-storage
        - roles.cooler
      roles_cfg:
        roles.cooler:
          sessions:
            expirationd:
              primary:
    ```

   Здесь:
   - `sessions` -- название спейса memtx, для которого настраивается архивация.
     Параметры архивации такого спейса задаются через настройки модуля `expirationd` в одноименной вложенной секции
     конфигурации;
     - `primary` -- название первичного ключа, по которому идет сканирование спейса.
   
   Полный список опций конфигурации для роли `roles.cooler` можно найти в [Справочнике по конфигурации](configuration_reference-cooler).

3. Нажмите **Save** и затем **Apply**, чтобы сохранить и применить новую конфигурацию кластера.

Эти настройки запускают фоновую задачу модуля `expirationd`: задача периодически сканирует спейс `sessions` по
первичному индексу и перемещает старые записи в архивный спейс `sessions_cold` по заданному условию.

Чтобы проверить запущенную архивацию данных, откройте вкладку **Tuples**.
Если все настроено корректно, вы увидите в спейсах следующее:

- в `sessions` остались только свежие сессии (`updated_at` < 30 минут назад);
- в `sessions_cold` появились старые сессии (`id = 4`, `id = 5`).

(user_guide-cooler_example-info_stats)=
## Статистика архивации

Просмотреть текущую статистику архивации можно с помощью методов [cooler.info()](reference_lua-cooler-info) и
[cooler.stats()](reference_lua-cooler-stats).
Для этого:

1. В TCM подключитесь к одному из лидеров хранилищ и перейдите на вкладку **Terminal** (`TT Connect`).  
2. Во вкладке **Terminal** загрузите модуль `cooler`:

   ```lua
   cooler = require('cooler')
   ```

3. Вызовите метод `cooler.info()`:

   ```lua
   cooler.info()
   ```
   
   Метод выводит следующую информацию о параметрах архивирования для спейса на текущем экземпляре:

   - `memtx_space` -- имя спейса memtx;
   - `memtx_tuples_count`  -- количество кортежей в спейсе memtx;
   - `vinyl_space` -- имя спейса vinyl;
   - `vinyl_params` -- параметры спейса vinyl (см. параметры в [](reference_lua-cooler-setup)).
     Полный список доступных параметров vinyl и их подробное описание приведены в
       [документации Tarantool](https://www.tarantool.io/ru/doc/latest/reference/configuration/configuration_reference/#vinyl);
   - `vinyl_tuples_count` -- количество кортежей в спейсе vinyl;
   - `vinyl_bytes_count` -- размер спейса vinyl в байтах;
   - `is_cooled_fun` -- имя функции-предиката для проверки условия архивации;
   - `cooling_indexes` -- имена индексов, по которым выполняется архивация;
   - `resetup_count` -- количество вызовов метода [cooler.resetup()](reference_lua-cooler-resetup) для спейса.

4. Вызовите метод `cooler.stats()`:

   ```lua
   cooler.stats()
   ```
   
   Метод выводит статистику архивации для текущего полного прохода по спейсу:

   - `scan_elapsed` -- время с начала полного прохода в секундах;
   - `tuples_cooled` -- количество архивированных кортежей за текущий проход по спейсу;
   - `bytes_cooled` -- объем архивированных данных в байтах за текущий проход по спейсу;
   - `tuples_scanned` -- количество просканированных кортежей за текущий проход по спейсу;
   - `bytes_scanned` -- объем просканированных данных в байтах за текущий проход по спейсу;
   - `avg_rate` -- средняя скорость архивации (кортежи в секунду);
   - `avg_bytes_rate` -- средняя скорость архивации (байты в секунду);
   - `tuples_remaining` -- оценка оставшихся кортежей до завершения прохода;
   - `eta` -- оценка времени до завершения прохода в секундах;
   - `mismatch_count` -- количество несовпадений при проверке кортежей memtx в ходе их переноса в спейс vinyl.
     После переноса кортежа в спейс vinyl и до его удаления из спейса memtx эти кортежи сравниваются между собой.
     Если во время переноса кортеж memtx был изменен, в vinyl остаётся предыдущая версия кортежа.
     В этом случае значение `cooler_mismatches` увеличивается на 1;
   - `errors_count` -- количество ошибок, возникших во время архивации.

(user_guide-cooler_example-metrics)=
## Просмотр метрик

Для отслеживания процесса переноса данных в Tarantool DB доступен набор метрик модуля `cooler`.
Метрики рассчитываются отдельно для каждой задачи архивации, с разбивкой по ключам `space` и `index`-- спейсу и индексу,
по которым выполняется архивация.
Полный список доступных метрик модуля можно найти в разделе [Метрики Tarantool DB](admin_guide-monitoring_tdb-cooler).

Для просмотра метрик в TCM откройте вкладку **Cluster** > **Cluster metrics**.
Все доступные метрики архивации помечены в списке префиксом `cooler`.

Чтобы проверить, включена ли архивация, в строке поиска найдите метрику `cooler_on`.
Убедитесь, что она равна `1` на каждом из лидеров хранилищ - это означает, что архивация запущена.

Смотрите также: [Мониторинг в Tarantool DB](admin_guide-monitoring).

(user_guide-cooler_example-disable)=
## Остановка архивации

Чтобы отключить фоновый перенос данных: 

1. В TCM откройте вкладку **Configuration**.
2. Удалите из конфигурации кластера настройки технологической роли `roles.cooler`, указанные в секции `roles_cfg`:

    ```yaml
    storages:
      replication:
        failover: election
      sharding:
        roles: [storage]
      roles:
        - roles.crud-storage
        - roles.cooler
      roles_cfg:  # пусто
    ```

3. Нажмите **Save** и **Apply**, чтобы применить новую конфигурацию кластера.

Теперь архивация остановлена.
Чтобы проверить это, перейдите во вкладку **Cluster** > **Cluster metrics** и проверьте, что метрика `cooler_on` равна `0` на экземплярах хранилищ.

(user_guide-cooler_example-change_format)=
## Смена формата спейса

Теперь измените формат memtx-спейса `sessions`, добавив в него поле `ip_address`, и создайте заново архивный спейс.
Для этого:

1. В TCM откройте вкладку **Migrations**.
2. Добавьте новую миграцию `002_sessions_resetup.lua`:

    ```lua
    local config = require('config')
    local fun = require('fun')
    local cooler = require('cooler')
    
    local function is_storage()
        return fun.index('roles.crud-storage', config:get('roles')) ~= nil
    end
    
    local function apply()
        if is_storage() then
            box.space.sessions:format({
                { name = 'id', type = 'unsigned' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'status', type = 'string' },
                { name = 'updated_at', type = 'number' },
                { name = 'ip_address', type = 'string', is_nullable = true },
            })
    
            -- Повторное создание архивного спейса с новым форматом
            cooler.resetup('sessions')
        end
    end
    
    return {
        apply = {
            scenario = apply,
        }
    }
    ```

   В миграции используется метод [cooler.resetup()](reference_lua-cooler-resetup), который при смене формата исходного спейса
   повторно создает спейс в vinyl следующим образом:

   - старый спейс vinyl будет переименован в `<vinyl_space_name>_<N>`, где `N` -- счётчик переименований (начинается с 1).
     Поскольку это первый вызов, новое имя будет `sessions_cold_1`;
   - новый vinyl-спейс `sessions_cold` будет создан с актуальным форматом и теми же параметрами.

3. Нажмите **Save** и **Apply** для применения миграции.
4. Перейдите на вкладку **Tuples**. На этой вкладке вы увидите:

   - старый архивный спейс `sessions_cold_1` с новым именем;
   - новый пустой спейс `sessions_cold` с полем `ip_address`.

(user_guide-cooler_example-secondary_index)=
## Архивация по вторичному индексу

Подключитесь повторно к роутеру, откройте вкладку **Terminal** (`TT Connect`) и добавьте еще несколько новых сессий:

```lua
crud.insert_object_many('sessions', {
    { id = 6, status = 'closed', updated_at = now(), ip_address = '192.168.1.10' },
    { id = 7, status = 'closed', updated_at = now() - 60 * 10, ip_address = '192.168.1.11' },
    { id = 8, status = 'active', updated_at = now() - 60 * 40, ip_address = '192.168.1.12' },
    { id = 9, status = 'active', updated_at = now() - 60 * 60, ip_address = '192.168.1.13' },
    { id = 10, status = 'active', updated_at = now() - 60 * 45, ip_address = '203.0.113.5' },
})
```

Чтобы включить более эффективную архивацию по вторичному индексу `by_updated_at`:

1. В TCM перейдите во вкладку **Configuration**.
2. В YAML-конфигурации кластера обновите конфигурацию роли `roles.cooler`:

    ```yaml
    storages:
      replication:
        failover: election
      sharding:
        roles: [storage]
      roles:
        - roles.crud-storage
        - roles.cooler
      roles_cfg:
        roles.cooler:
          sessions:
            expirationd:
              by_updated_at:
                start_key: sessions_updated_at_start_key
                iterator_type: 'LT'
    ```

   Здесь:
   - `sessions` -- название спейса memtx, для которого настраивается архивация;
     - `by_updated_at` -- название вторичного индекса, по которому идет сканирование спейса;
       - `start_key` -- ключ, с которого начинается проход по индексу.
         Функция `sessions_updated_at_start_key` определяет порог времени для архивации;
       - `iterator_type` -- тип итератора для архивации по TTL.

  В итоге задача архивации будет эффективно сканировать только старые записи.

3. Нажмите **Save** и **Apply**, чтобы применить конфигурацию и запустить перенос данных.

Чтобы проверить результат работы архивации, перейдите на вкладку **Tuples**.
Убедитесь, что в vinyl-спейс `sessions_cold` добавлены сессии старше 30 минут (`id = 8`, `9`, `10`).
При этом в исходном спейсе `sessions` должны остаться только свежие сессии (`id = 6`, `7`).

(user_guide-cooler_example-stop_example)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
