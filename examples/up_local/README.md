# Конфигурация и запуск кластера локально через утилиту ``tt``

Утилита ``tt`` дает возможно запускать и управлять приложениями на ``cartirdge``.

Для локального запуска tarantoolDB необходимо в корне проекта:

1. Установить утилиту ``tt``
   - Ее можно установить из [официального репозитория](https://github.com/tarantool/tt/tree/master#installation)
   - Или использовать версию поставляемую вместе с SDK.
        
        Выполните ``source sdk/env.sh``, чтобы использовать утилиты и модули из sdk.
2. Выполнить сборку проекта

   ``tt build``
3. Запустить процессы tarantool

   ``tt start tarantooldb``
4. Выполнить сборку cartridge кластера

   ``tt cartridge replicasets setup --bootstrap-vshard --name tarantooldb --run-dir tmp/run/tarantooldb``

Чтобы выключить кластер используйте ``tt stop``.

Для конфигурации кластера используются следующие файлы:

1. **tt.yaml** - главный конфигурационный файл ``tt``.
2. **instances.yml** - файл, описывающий инстансы кластера (название, порты, настройки tarantool)
3. **replicasets.yml** - файл, описывающий репликасеты на основе инстансов из ``instances.yml``

Подробнее об использовании [tt](https://github.com/tarantool/tt/blob/master/doc/examples.md) и настройках [cartridge](https://github.com/tarantool/cartridge-cli/tree/master/doc) можно прочесть в соответсвующей документации.