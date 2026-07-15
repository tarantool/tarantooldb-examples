# Кэш кортежей движка vinyl (нагрев/охлаждение)

В этом примере показано устройство и принцип работы **кэша кортежей** движка vinyl, а также описано, как его настроить
и оценить влияние кэша на производительность чтений. Кроме того, показано, как реализовать сценарий нагрева и охлаждения данных.

Движок vinyl — это дисковый LSM-движок: данные сначала пишутся в in-memory уровень (L0), а затем
сбрасываются на диск в виде run-файлов. Чтение данных, уже сброшенных на диск, требует обращения
к диску и потому медленнее чтения из памяти. Чтобы ускорить повторные чтения, vinyl держит
в памяти **кэш кортежей** (`vinyl_cache`) — LRU-кэш недавно прочитанных кортежей.

Стенд состоит из одного экземпляра Tarantool DB. Конфигурация хранится в etcd;
управление кластером доступно через веб-интерфейс [Tarantool Cluster Manager](getting_started-tcm).

Содержание:

* [](admin_guide-vinyl_cache-prereq)
* [](admin_guide-vinyl_cache-start)
* [](admin_guide-vinyl_cache-files)
* [](admin_guide-vinyl_cache-config)
* [](admin_guide-vinyl_cache-read-path)
* [](admin_guide-vinyl_cache-connect)
* [](admin_guide-vinyl_cache-prepare)
* [](admin_guide-vinyl_cache-index-stat)
* [](admin_guide-vinyl_cache-demo-memory)
* [](admin_guide-vinyl_cache-demo-hit)
* [](admin_guide-vinyl_cache-demo-miss)
* [](admin_guide-vinyl_cache-stop)

## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](https://tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install/install_docker) Tarantool DB (`tarantooldb:3x-latest`) и etcd (`quay.io/coreos/etcd:v3.5.15`);
* приложение Docker Compose;
* утилита [tt CLI](https://tarantool.io/docs/tdb/ru/3_x/install_and_upgrade/install_tt) для подключения к консоли экземпляра;
* исходные файлы примера `vinyl_cache`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/en/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `vinyl_cache` расположен в таком архиве в директории `./doc/examples/vinyl_cache/`.

  * Отдельный архив [vinyl_cache.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/vinyl_cache/vinyl_cache.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-vinyl_cache-start)=
## Запуск стенда

Для успешного запуска должны быть свободны следующие порты:

* 2379
* 3301
* 8081

Перейдите в директорию примера `vinyl_cache`:

```shell
cd ./doc/examples/vinyl_cache/
```

Запустите стенд:

```shell
make start
```

Команда последовательно:

1. Создаёт Docker-сеть `tarantooldb_network`;
2. Запускает etcd (3 узла) и TCM;
3. Публикует конфигурацию в etcd;
4. Запускает узел Tarantool DB (`vinyl-cache`) и контейнер `init_host`, который применяет миграцию.
  Миграция создаёт спейс на движке vinyl с названием `data` и регистрирует вспомогательные функции `fill_data`, `bench_hot` и `bench_scattered`.

После запуска стенда доступны:

* узел Tarantool DB на порту `3301`;
* веб-интерфейс TCM на порту `8081`.

Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

* **Username**: `admin`
* **Password**: `secret`

(admin_guide-vinyl_cache-files)=
## Используемые файлы

В руководстве используются следующие файлы примера `vinyl_cache`:

* `Makefile` -- команды запуска и остановки стенда;
* `cluster/config.yml` -- конфигурация и топология экземпляра (включая секцию `vinyl`);
* `cluster/docker-compose.yml` -- описание узла Tarantool DB и контейнера `init_host`;
* `cluster/migrations/scenario/001_vinyl_cache_space.lua` -- миграция: создаёт спейс `data` и регистрирует функции `fill_data`, `bench_hot`, `bench_scattered`;
* `tools/docker-compose.yml` -- описание etcd-кластера и TCM;
* `tools/tcm.yml` -- конфигурация TCM.

(admin_guide-vinyl_cache-config)=
## Настройка кэша vinyl

Кэш vinyl настраивается в корневой секции `vinyl` декларативной конфигурации кластера:

```yaml
vinyl:
  memory: 134217728   # 128 MiB — буфер in-memory уровня (L0). Значение по умолчанию.
  cache: 16777216     # 16 MiB  — размер кэша кортежей. По умолчанию 128 MiB; 0 = кэш выключен.
```

Здесь:

* `vinyl.cache` -- размер LRU-кэша прочитанных кортежей в байтах. Значение по умолчанию: 128 MiB.
  Значение `0` отключает кэш. LRU-кэш наполняется при чтениях, в записи он не участвует. Обновление или удаление
  кортежа инвалидирует его запись в кэше.
* `vinyl.memory` -- размер in-memory уровня L0 в байтах. Значение по умолчанию: 128 MiB. Сюда попадают
  все операции записи. При заполнении уровень сбрасывается на диск.

Обе опции можно менять динамически из консоли, при этом `vinyl_memory` разрешено только увеличивать,
а `vinyl_cache` -- изменять в любую сторону.

В веб-интерфейсе TCM на вкладке **Dashboard** выберите узел кластера **vinyl-cache* . В открывшемся окне перейдите на вкладку **Terminal**  и попробуйте ввести следующие команды:

```lua
box.cfg.vinyl_cache                          -- смотрим текущий размер кэша
-- 16777216
```

```lua
box.cfg{ vinyl_cache = 32 * 1024 * 1024 }   -- меняем
```

```lua
box.cfg.vinyl_cache                          -- смотрим новое текущее значение
-- 33554432
```

(admin_guide-vinyl_cache-read-path)=
## Путь чтения данных в vinyl

При выполнении запроса `GET` или `SELECT` vinyl последовательно проверяет несколько источников
и возвращает результат из первого источника, где был найден кортеж:

| Приоритет | Источник | Счётчик в `index:stat()` |
| --- |---|---|
| 1 | `vinyl_cache` — LRU-кэш кортежей в памяти | `cache.get.rows` |
| 2 | `vinyl_memory` — L0, in-memory уровень | `memory.iterator.lookup` |
| 3 | Диск — run-файлы | `disk.iterator.lookup` |

Чтение идёт из L0 без обращений к диску, пока данные не сброшены на диск — то есть до тех пор, пока не сделан снимок данных через `box.snapshot()` или не переполнена память в `vinyl_memory`. После сброса данные переезжают на диск, и именно тут `vinyl_cache`
начинает играть роль.

(admin_guide-vinyl_cache-connect)=
## Подключение к консоли

Подключитесь к экземпляру с помощью tt CLI:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

Чтобы выйти из консоли, введите `\quit`.

Проверьте, что значение кэша взято из конфигурации:

```shell
echo "box.cfg.vinyl_cache" | tt connect admin:secret-cluster-cookie@localhost:3301
# 16777216
```

(admin_guide-vinyl_cache-prepare)=
## Подготовка данных

Спейс `data` на движке vinyl создаётся автоматически при запуске стенда через миграцию.
Загрузите данные – 200 000 кортежей примерно по 200 байт, итого ~40 MB):

```shell
echo "box.func.fill_data:call()" | tt connect admin:secret-cluster-cookie@localhost:3301
```

`fill_data` вставляет 200 000 кортежей пачками по 10 000 в отдельных транзакциях.

После вставки данные находятся в in-memory уровне L0. Убедитесь в этом:

```shell
echo "box.stat.vinyl().memory.level0" | tt connect admin:secret-cluster-cookie@localhost:3301
# 50938368
```

(admin_guide-vinyl_cache-index-stat)=
## Статистика индекса: index:stat()

Метод `index:stat()` возвращает накопленную статистику по конкретному индексу.
Для спейса `data` вызов выглядит так:

```lua
box.space.data.index.pk:stat()
```

Подробное описание всех полей приведено в документации платформы Tarantool в [справочнике метода index:stat()](https://www.tarantool.io/ru/doc/latest/reference/reference_lua/box_index/stat/).

Для анализа работы кэша vinyl используются следующие поля:

| Поле | Описание |
|---|---|
| `get.rows` | Общее количество кортежей, возвращённых через этот индекс |
| `cache.get.rows` | Количество кортежей, обслуженных из кэша (попадания) |
| `cache.evict.rows` | Количество кортежей, вытесненных из кэша (кэш переполнен) |
| `cache.rows` | Количество кортежей в кэше прямо сейчас |
| `memory.iterator.lookup` | Количество чтений, обращавшихся к L0 |
| `disk.iterator.lookup` | Количество чтений, дошедших до дисковых run-файлов |

Пример: посчитать hit/miss за период:

```lua
idx = box.space.data.index.pk
before = idx:stat()
-- ... выполнить чтения ...
after = idx:stat()

hit   = after.cache.get.rows - before.cache.get.rows
total = after.get.rows       - before.get.rows
miss  = total - hit
-- ratio = hit / total
```

(admin_guide-vinyl_cache-demo-memory)=
## Демо: чтение из vinyl_memory (данные в L0)

Пока данные не сброшены на диск, все чтения обслуживаются из in-memory уровня L0.
Отключите кэш, чтобы изолировать этот эффект. Подключитесь к консоли:

```shell
tt connect admin:secret-cluster-cookie@localhost:3301
```

И выполните:

```lua
s = box.space.data
```

```lua
clock = require('clock')
```

```lua
idx = s.index.pk
```

```lua
box.cfg{ vinyl_cache = 0 }
```

Измерьте чтение 5 000 ключей и посмотрите значения счётчиков:

```lua
before = idx:stat()
```

```lua
clock.bench(function() for i = 1, 5000 do s:get(i) end end)[1]   -- ~0.021 с
```

```lua
after = idx:stat()
```

```lua
after.memory.iterator.lookup - before.memory.iterator.lookup   -- =5000: данные в L0
```

```lua
after.disk.iterator.lookup   - before.disk.iterator.lookup     -- =0:    run-файлов ещё нет
```

Сбросьте L0 на диск:

```shell
echo "box.snapshot()" | tt connect admin:secret-cluster-cookie@localhost:3301
echo "box.stat.vinyl().memory.level0" | tt connect admin:secret-cluster-cookie@localhost:3301
# 0
```

Теперь повторите измерение:

```lua
before = idx:stat()
```

```lua
clock.bench(function() for i = 1, 5000 do s:get(i) end end)[1]   -- ~0.260 с
```

```lua
after = idx:stat()
```

```lua
after.memory.iterator.lookup - before.memory.iterator.lookup   -- =5000: итератор L0 открывается, но пуст
```

```lua
after.disk.iterator.lookup   - before.disk.iterator.lookup     -- =5000: данные читаются с диска
```

Второй вызов заметно медленнее — те же данные теперь читаются с диска.
Сравните значение времени с первым замером: на тестовом стенде ~0.021 с против ~0.260 с (разница в ~12 раз).
Именно для ускорения таких повторных чтений и существует `vinyl_cache`.

(admin_guide-vinyl_cache-demo-hit)=
## Демо A. Кэш помогает: горячий набор данных

В демо выполняется многократное чтение одного и того же небольшого набора ключей (1–5000).
Этот набор целиком помещается в кэш 16 MiB, поэтому повторные чтения обслуживаются из памяти.

Для последовательного чтения данных создана хранимая процедура `bench_hot`. Она выполняет 10 проходов по ключам 1–5000, замеряет время через `clock.bench` и считает hit/miss по разнице счётчиков `index:stat()`. Текст процедуры можно посмотреть на вкладке **Funcs** узла **vinyl-cache** в TCM.

Сначала измерьте время с **выключенным** кэшем — каждое чтение при этом идёт на диск:

```shell
echo "box.cfg{ vinyl_cache = 0 }" | tt connect admin:secret-cluster-cookie@localhost:3301
echo "box.func.bench_hot:call()" | tt connect admin:secret-cluster-cookie@localhost:3301
# time=2.504s  hit=0  miss=50000  ratio=0.00
```

Теперь включите кэш и сделайте повторный замер. Первый проход прогревает кэш, остальные девять обслуживаются из него:

```shell
echo "box.cfg{ vinyl_cache = 16 * 1024 * 1024 }" | tt connect admin:secret-cluster-cookie@localhost:3301
echo "box.func.bench_hot:call()" | tt connect admin:secret-cluster-cookie@localhost:3301
# time=0.306s  hit=45000  miss=5000  ratio=0.90
```

Повторите процедуру с уже прогретым кэшем — все 5000 ключей находятся в нём:

```shell
echo "box.func.bench_hot:call()" | tt connect admin:secret-cluster-cookie@localhost:3301
# time=0.099s  hit=50000  miss=0  ratio=1.00
```

Видно, что в сравнении с выключенным кэшем время сократилось примерно в 25 раз.

(admin_guide-vinyl_cache-demo-miss)=
## Демо B. Кэш бесполезен: чтения по всему набору данных

В этом демо выполняется чтение случайных ключей по **всему** набору данных (200 000 ключей, ~40 MB).
При кэше 4 MiB данные постоянно вытесняются, и кэш почти не помогает.

Для случайного чтения создана хранимая процедура `bench_scattered`. Она выполняет 50 000 случайных чтений по всему диапазону ключей.

```shell
echo "box.cfg{ vinyl_cache = 4 * 1024 * 1024 }" | tt connect admin:secret-cluster-cookie@localhost:3301
echo "box.func.bench_scattered:call()" | tt connect admin:secret-cluster-cookie@localhost:3301
# time=2.309s  hit=3401  miss=46599  ratio=0.07
```

Рост числа вытеснений подтверждает, что кэш работает безрезультатно:

```shell
echo "box.space.data.index.pk:stat().cache.evict.rows" | tt connect admin:secret-cluster-cookie@localhost:3301
# 37397
```

Для сравнения результатов отключите кэш совсем:

```shell
echo "box.cfg{ vinyl_cache = 0 }" | tt connect admin:secret-cluster-cookie@localhost:3301
echo "box.func.bench_scattered:call()" | tt connect admin:secret-cluster-cookie@localhost:3301
# time=2.333s  hit=0  miss=50000  ratio=0.00
```

Разница во времени с включённым и выключенным кэшем минимальна. Это означает, что кэш, размер которого меньше рабочего набора данных,
не даёт выигрыша — его поведение неотличимо от полного отсутствия кэша.

> [!NOTE]
> Кэш кортежей эффективен только тогда, когда есть **горячий набор** данных, который помещается в кэш целиком. При равномерных обращениях ко всему набору данных, превышающему
> размер кэша, кэш не приносит пользы.

(admin_guide-vinyl_cache-stop)=
## Остановка стенда

Чтобы остановить стенд, выполните в локальном терминале следующую команду:

```shell
make stop
```
