(admin_guide-schema-upgrade-migrations)=
# Обновление схемы через миграции

В этом руководстве показано, как обновить cхему Tarantool DB при выполнении [миграции](user_guide-migrations).


(admin_guide-schema-upgrade-migrations-prereq)=
## Пререквизиты

Для выполнения примера требуются:

* установленные [Docker-образы](install_docker-image) Tarantool DB, Prometheus и Grafana;
* приложение Docker Compose;
* исходные файлы примера `migrations_schema_upgrade`.

  ```{admonition} Примечание
  :class: note

  Есть два способа получить исходные файлы примера:

  * Архив с полной документацией Tarantool DB, полученный по почте или скачанный в [личном кабинете tarantool.io](https://www.tarantool.io/ru/accounts/customer_zone/packages/tarantooldb/release/documentation).
    Пример архива: `tarantooldb-documentation-3.0.0.tar.gz`.
    Пример `migrations_schema_upgrade` расположен в таком архиве в директории `./doc/examples/migrations_schema_upgrade/`.
    
  * Отдельный архив [migrations_schema_upgrade.tar.gz](https://tarantool.io/ru/tarantooldb/doc/latest/examples/migrations_schema_upgrade/migrations_schema_upgrade.tar.gz), скачанный c сайта Tarantool.
  ```

(admin_guide-schema-upgrade-migrations-start_example)=
## Запуск стенда

Перейдите в директорию примера `migrations_schema_upgrade`:

```shell
cd ./doc/examples/migrations_schema_upgrade/
```

Запустите кластер Tarantool DB:

```shell
make start
```

Запущенный стенд состоит из:

- кластера Tarantool DB:
  - 2 роутера;
  - 2 набора реплик по 3 хранилища;
  - 1 [Tarantool Cluster Manager](getting_started-tcm) (TCM);
- кластера etcd из 3 узлов.

После запуска должны работать все контейнеры, кроме [init_host](admin_guide-deploy_docker_compose-init_host).
Также после запуска становится доступен веб-интерфейс TCM.

Для входа в TCM откройте в браузере адрес [http://localhost:8081](http://localhost:8081).
Логин и пароль для входа:

- **Username**: `admin`
- **Password**: `secret`

В TCM откройте вкладку **Stateboard**.

В кластере появится предупреждение о необходимости обновить схему БД:
![](./cluster/warning.png)

(admin_guide-schema-upgrade-migrations-upgrade)=
## Обновление схемы

Один из надежных способов обновления схемы БД -- применить соответствующую миграцию.
Миграция при этом выглядит так:

```lua
local function apply()
    box.snapshot()
    box.schema.upgrade()
    box.snapshot()
end

return {
    apply = {
        scenario = apply,
    }
}
```

Выполнить миграцию можно с помощью утилиты [tt CLI](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/). Для этого:


1. В локальном терминале поместите файл из папки `migration_next` с кодом миграций `003_test.lua` в папку `./cluster/migrations/scenario/`:

   ```shell
   cp -a cluster/migration_next/* cluster/migrations/scenario/ 
   ```

2. Загрузите миграции в [централизованное хранилище](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/cluster/#publish):

   ```shell
   tt migrations publish http://admin:secret-cluster-cookie@localhost:2379/tdb/ migrations
   ```

   Узнать больше о командах `tt migrations` можно в [документации Tarantool](https://www.tarantool.io/ru/doc/latest/tooling/tt_cli/migrations/).

3. Примените миграции:

   ```shell
   docker compose exec tarantool-router-msk tt migrations apply http://etcd1:2379/tdb --tarantool-username=admin --tarantool-password=secret-cluster-cookie
   cd ..
   ```

Предупреждение об устаревшей схеме БД пропадет после успешного обновления схемы.

Обновление схемы также будет отражено в логах:

```txt
tarantool-router-msk-1  | 2025-10-09 08:44:55.876 [1] main/104/interactive/box.upgrade upgrade.lua:1591 I> Recovering snapshot with schema version 3.1.0
tarantool-router-msk-1  | 2025-10-09 08:44:55.901 [1] main/104/interactive/box.load_cfg load_cfg.lua:1229 W> Your schema version is 3.1.0 while Tarantool 3.4.0-0-gea61d3a20 requires a more recent schema version. Please, consider using box.schema.upgrade().
tarantool-router-msk-1  | 2025-10-09 08:44:55.928 [1] main/104/interactive/tarantool.config log.lua:74 W> The schema version 3.1.0 is outdated, the latest version is 3.3.0. Please, consider using box.schema.upgrade().
tarantool-router-msk-1  | 2025-10-09 08:44:55.928 [1] main/129/box.watcher/tarantool.config log.lua:74 W> The schema version 3.1.0 is outdated, the latest version is 3.3.0. Please, consider using box.schema.upgrade().
tarantool-router-msk-1  | 2025-10-09 08:46:10.299 [1] main/180/tt_migrations.executor/box.upgrade upgrade.lua:1632 I> set schema version to 3.3.0
```

Проверить, что схема успешно обновлена, можно с помощью вызова `box.info.schema_version`. После обновления схемы значение `schema_version` увеличится.

(admin_guide-schema-upgrade-migrations-stop_example)=
## Остановка стенда

Остановить стенд можно так:

```shell
make stop
```
