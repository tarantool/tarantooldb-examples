# Шаблон приложения Tarantool DB для tt CLI

## Создание шаблона

Чтобы создать шаблонный проект с Tarantool DB, используйте команду `tt create`:

```bash
tt create tarantool_db --name myapp
   • Creating application in "/home/vboxuser/tarantooldb/myapp"
   • Using template from /home/vboxuser/tarantooldb/templates/tarantool_db
Bucket count (default: 30000): 300
Use expirationd [y|n] (default: n): n
Use only user "admin" for sharding and replication [y|n] (default: n): 
   • Executing post-hook ./hooks/post-gen.sh
   • Application 'myapp' created successfully
```
Здесь:
- `name` -- имя приложения. Обязательный параметр. При выполнении команды будет создана директория с указанным именем.

Модуль `expirationd` по умолчанию отключен (`n`). Чтобы использовать этот модуль, укажите `y` в строке ввода. expirationd будет добавлен в конфигурацию и тесты.

По умолчанию при выполнении команды создаются три пользователя: `admin`, `replicator`, `storage`. Чтобы создать вместо них одного пользователя `admin`, укажите `y` в строке ввода.


## Запуск приложения

Для использования шаблона требуются:
- приложение Docker;
- Docker-образ Tarantool DB 2.x;
- `python3`.

Запустить шаблон можно так:

```bash
make up

...
All services configured
```

В результате будет развернут следующий стенд:
- кластер Tarantool 3.x: 2 роутера, 2 набора реплик по 2 реплики. Используются порты 3301-3307;
- 1 экземпляр TCM, который доступен по адресу http://localhost:8081/. Логин и пароль для входа:

  - **Username**: `admin`
  - **Password**: `secret`

- 1 экземпляр etcd, используется порт 2379.


Изначально будет 1 файл с миграцией: `cluster/migrations/scenario/0000001_example.lua`.
Новые файлы миграций необходимо добавлять в директорию `cluster/migrations/scenario/`.

## Настройка окружения

Чтобы настроить окружение, выполните следующие команды:

```bash
python3 -m venv venv
source venv/bin/activate
pip3 install -r test/requiremets.txt
```

## Запуск тестов
```bash
make test
```

В тесте `test_example.py` показаны примеры использования хэлперов для вызова crud-операций и изменения конфигурации.

```python
tdb_client.conn.crud_truncate('data')
tdb_client.conn.crud_insert_object('data', {"id":1, "data": "data"})
...
cfg = cluster_config.Config
cfg['credentials']['users']['new_user'] = {
   "password": "password",
   "roles": [
      "super"
   ],
}
cluster_config.Config = cfg
```
