# Охлаждение данных с помощью библиотеки cooler 

В этом руководстве описано, как использовать библиотеку `cooler` для автоматического переноса ("охлаждения") устаревших данных из `memtx`-спейса в `vinyl`-спейс на основе времени жизни (TTL), например, по полям `created_at` или `updated_at`. 

Такой подход позволяет держать горячие данные в оперативной памяти (`memtx`) для высокой производительности и переносить холодные данные на диск (`vinyl`) для долгосрочного хранения.

## Пререквизиты

Для выполнения примера вам понадобится:

* Установленный Docker-образ Tarantool DB;
* Приложение Docker Compose;
* Утилита tt CLI;
* Исходные файлы примера `cooler`.

## Запуск кластера

Для успешного запуска кластера должны быть свободны следующие порты: 

* 2379
* 3301--3308
* 8081

Перейдите в папку с примером `cooler`:

```shell
cd ./doc/examples/cooler/
```

Запустите кластер:

```shell
make start
```

После выполнения команды будет развернут следующий стенд:
- Кластер Tarantool DB:
  - 2 роутера
  - 2 набора реплик по 3 хранилища
- Кластер etcd из 3 узлов
- Tarantool Cluster Manager (TCM)

После запуска должны работать все контейнеры, кроме `init_host`, который используется только для инициализации и завершает свою работу после настройки кластера.

## Доступ к Tarantool Cluster Manager

После запуска кластера становится доступен веб-интерфейс Tarantool Cluster Manager (TCM).
Откройте в браузере адрес http://localhost:8081.
Для входа используйте следующие логин и пароль:
- **Username**: `admin`
- **Password**: `secret`

Через TCM вы можете управлять конфигурацией, просматривать метрики и подключаться к узлам. 

## Создание memtx-спейса и настройка cooler

В данном руководстве используется миграция, определённая в файле: `./cluster/migrations/scenario/001_sessions.lua`.

В ней создаётся шардированный `memtx`-спейс `sessions` для хранения пользовательских сессий. Для архивации устаревших записей используется модуль `cooler`. 

### Настройка cooler

Функция `cooler.setup()` настраивает процесс архивации для указанного `memtx`-спейса. Она регистрирует условие архивации и создаёт архивный `vinyl`-спейс с заданными параметрами:

```lua
cooler.setup('sessions', {
    -- Параметры vinyl
    vinyl_params = {
        bloom_fpr = 0.05,
        run_count_per_level = 8,
        run_size_ratio = 3.5,
    }
})
```

Имена функции и архивного спейса формируются автоматически на основе имени исходного спейса:

* Имя функции-предиката - `<space_name>_is_cooled`, в данном случае `sessions_is_cooled`. Его можно переопределить с помощью параметра `is_cooled_fun_name`.
* Имя архивного `vinyl`-спейса - `<space_name>_cold`, то есть `sessions_cold`. Может быть задано явно через параметр `vinyl_space_name`.

### Условие архивации

Функция-предикат с условием архивации задаётся с помощью функции `cooler.set_func`:

```lua
box.schema.func.create('sessions_updated_at_start_key', {
    body = "function() return require('clock').time() - 60 * 30 end",
    if_not_exists = true,
})

cooler.set_func('sessions', "t.updated_at < box.func.sessions_updated_at_start_key:call()")
```

Мы также определяем здесь функцию `sessions_updated_at_start_key`, возвращающую порог времени для архивации. Условие `t.updated_at < ...` означает: архивировать все сессии, обновлённые более 30 минут назад.

## Проверка создания спейсов

Перейдите в раздел **Tuples** TCM. 

Вы увидите два спейса:

1. `sessions` -- `memtx`-спейс для свежих сессий
2. `sessions_cold` -- созданный `vinyl`-спейс для архивных сессий

## Добавление тестовых данных

Чтобы начать работу с базой данных через интерактивную консоль Tarantool, нужно подключиться к узлу кластера. Это можно сделать двумя способами:

- Через веб-интерфейс TCM;
- Через терминал с помощью утилиты tt CLI:

  ```shell
  tt connect admin:secret-cluster-cookie@localhost:3301
  ```

Подключитесь к роутеру `router-msk`, используя **первый способ** -- через TCM. Для этого:

1. Перейдите в раздел **Stateboard**.
2. Нажмите на набор реплик `router-msk`.
3. Выберите узел `router-msk` и в открывшемся окне перейдите на вкладку **Terminal**.

Теперь вы находитесь в интерактивной консоли Tarantool и можете выполнять запросы к кластеру.

Для удобства ввода данных определите вспомогательную функцию для получения текущего времени:

```lua
function now()
    local clock = require('clock')
    return clock.time()
end
```

Теперь вставьте несколько сессий с разным временем обновления: 

```lua
crud.insert_object_many('sessions', {
    { id = 1, status = 'active', updated_at = now() },           -- свежая
    { id = 2, status = 'closed', updated_at = now() - 60 * 5 },  -- 5 мин назад
    { id = 3, status = 'active', updated_at = now() - 60 * 15 }, -- 15 мин назад
    { id = 4, status = 'closed', updated_at = now() - 60 * 40 }, -- 40 мин назад
    { id = 5, status = 'active', updated_at = now() - 60 * 120 } -- 2 часа назад
})
```

## Включение архивации

Чтобы активировать фоновую задачу архивации, перейдите в **Configuration**. Добавьте конфигурацию роли `cooler` в секцию `storages`: 

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

Нажмите **Save**, затем **Apply**.

Это запустит фоновую задачу модуля `expirationd`, которая будет периодически проверять `sessions` по первичному индексу и перемещать старые записи в `sessions_cold` по заданному условию.

## Проверка архивации

Убедимся, что архивация работает.  

Перейдите обратно в раздел **Tuples**. Вы увидите:

* В `sessions`: остались только свежие сессии (`updated_at` < 30 минут назад)
* В `sessions_cold`: появились старые сессии (`id = 4`, `id = 5`).

## Проверка статистики cooler

Подключитесь к одному из лидеров хранилищ через **Terminal** в TCM.  

Загрузите модуль `cooler`:

```lua
cooler = require('cooler')
```

Далее, с помощью функции `cooler.info()` можно посмотреть следующую информацию о параметрах архивирования для спейса на текущем инстансе:

* `memtx_space` - имя `memtx`-спейса.
* `memtx_tuples_count` - количество кортежей в `memtx`-спейсе.
* `vinyl_space` - имя `vinyl`-спейса.
* `vinyl_params` - параметры `vinyl`-спейса
* `vinyl_tuples_count` - количество кортежей в `vinyl`-спейсе.
* `vinyl_bytes_count` - размер `vinyl`-спейса в байтах.
* `is_cooled_fun` - имя функции-предиката для проверки условия архивации.
* `cooling_indexes` - имена индексов, по которым выполняется архивация.
* `resetup_count` - количество вызовов `resetup` для спейса.

Также, вызвав функцию `cooler.stats()` можно получить статистику архивации для текущего полного прохода по спейсу:

* `scan_elapsed` - время с начала полного прохода (в секундах).
* `tuples_cooled` - количество архивированных кортежей.
* `bytes_cooled` - количество архивированных байт.
* `tuples_scanned` - количество просмотренных кортежей.
* `bytes_scanned` - количество просмотренных байт.
* `avg_rate` - средняя скорость архивации (кортежей/сек)
* `avg_bytes_rate` - средняя скорость архивации (байт/сек)
* `tuples_remaining` - оценка оставшихся кортежей до завершения прохода.
* `eta` - оценка времени до завершения прохода (в секундах).
* `mismatch_count` - количество несовпадений при проверке `memtx`-кортежей в ходе их переноса в `vinyl`-спейс. В результате в `vinyl`-спейсе оказываются старые версии этих кортежей.
* `errors_count` - количество ошибок во время архивации.

## Проверка метрик

Перейдите в раздел **Cluster metrics**. Найдите метрику `cooler_on` и убедитесь, что она равна `1` на обоих лидерах хранилищ. Это означает, что архивация активна.

Также здесь вы можете посмотреть другие метрики архивации с префиксом `cooler`.

## Отключение архивации

Чтобы остановить охлаждение: 

1. Перейдите в раздел **Configuration**.
2. Удалите добавленный конфиг роли `cooler`:

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

Нажмите **Save** и **Apply**, чтобы применить конфиг.

Теперь архивация остановлена. Перейдите в раздел **Cluster metrics** и проверьте, что метрика `cooler_on` равна `0` на инстансах хранилищ.

## Смена формата спейса

Теперь мы изменим формат `sessions`, добавив поле `ip_address`, и пересоздадим архивный спейс.

Перейдите в раздел **Migrations** и добавьте новую миграцию с именем `002_sessions_resetup.lua`:

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

        -- Пересоздаём архивный спейс с новым форматом
        cooler.resetup('sessions')
    end
end

return {
    apply = {
        scenario = apply,
    }
}
```

Здесь мы используем функцию `cooler.resetup()`, которая пересоздаёт архивный `vinyl`-спейс следующим образом:

* Старый `vinyl`-спейс переименовывается в `<vinyl_space_name>_<N>`, где N - счётчик переименований (начинается с 1). Поскольку это первый вызов, новое имя будет `sessions_cold_1`.
* Создаётся новый `vinyl`-спейс `sessions_cold` с актуальным форматом и теми же параметрами.

Нажмите **Save** и **Apply** для применения миграции.

Перейдя в раздел **Tuples**, мы увидим:

* Старый архивный спейс `sessions_cold_1` с новым именем
* Новый пустой спейс `sessions_cold` с полем `ip_address`

## Архивация по вторичному индексу

Перейдите обратно в терминал роутера и вставьте новые данные:

```lua
crud.insert_object_many('sessions', {
    { id = 6, status = 'closed', updated_at = now(), ip_address = '192.168.1.10' },
    { id = 7, status = 'closed', updated_at = now() - 60 * 10, ip_address = '192.168.1.11' },
    { id = 8, status = 'active', updated_at = now() - 60 * 40, ip_address = '192.168.1.12' },
    { id = 9, status = 'active', updated_at = now() - 60 * 60, ip_address = '192.168.1.13' },
    { id = 10, status = 'active', updated_at = now() - 60 * 45, ip_address = '203.0.113.5' },
})
```

Теперь включим более эффективную архивацию -- по вторичному индексу `by_updated_at`.

Перейдите в раздел **Configuration** и обновите конфигурацию роли `cooler`:

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

Здесь мы задаём индекс `by_updated_at`, порог времени с помощью функции `sessions_updated_at_start_key` и тип итератора `LT` для архивации по TTL. В итоге задача архивации будет эффективно просматривать только старые записи.

Нажмите **Save** и **Apply** для применения конфигурации и запуска архивации.

## Проверка финальных результатов

Перейдите в раздел **Tuples**. Убедитесь, что в `sessions_cold` добавились записи, которые старше 30 минут (`id = 8`, `9`, `10`). При этом в `sessions` остались только свежие (`id = 6`, `7`).

## Остановка кластера

Чтобы остановить кластер, выполните в локальном терминале следующую команду:

```shell
make stop
```
