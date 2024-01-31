# Примеры файлов для конфигурирования кластера через TT CLI

> Для разработчиков TarantoolDB см. соответствующий [раздел](../../CONTRIBUTING.md#локальный-запуск).

Локальное развёртывание происходит с помощью клиентской утилиты [TT CLI](../../../README.md#интерфейс-командной-строки-%28cli%29) (`tt`).

Для локального запуска TarantoolDB необходимо:
1. Создать папку продукта TarantoolDB
   ```shell
   mkdir tarantooldb
   ```
   > **Важно**
   > 
   > Папка должна называться `tarantooldb`
2. Распаковать в созданную директорию `tarantooldb` содержимое архива для развёртывания (из раздела клиентской зоны [for deploy](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/for_deploy))
3. Создать конфигурационные файлы для локального старта (см. [подраздел ниже](#файлы-для-локального-старта))
4. Запустить процессы узлов TarantoolDB из папки продукта командой:
   ```shell
   ./tt start
   ```
5. Выполнить сборку кластера из узлов TarantoolDB:

   ```shell
   ./tt cartridge replicasets setup --bootstrap-vshard --name tarantooldb --run-dir var/run
   ```

Кластер доступен по адресу одного из узлов (кроме stateboard). Например: http://localhost:8081

Чтобы выключить кластер используйте команду:
```shell
./tt stop
```

## Файлы для локального старта
Для конфигурирования кластера используются следующие файлы ([пример](tarantooldb/)):

1. **tt.yaml** - конфигурационный файл для TT CLI ([документация](https://www.tarantool.io/en/doc/latest/reference/tooling/tt_cli/configuration/)).
   Можно сгенерировать командой `tt init`.
2. **instances.yml** - файл, описывающий узлы кластера (название, порты, прочие настройки)
3. **replicasets.yml** - файл, описывающий группы узлов (репликасеты) и их роли)
