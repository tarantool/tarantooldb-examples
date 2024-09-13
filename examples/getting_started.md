# [AEON](https://github.com/tarantool/aeon/blob/master/README.ru.md)

## Быстрый старт

- Запустите кластер из примера `up_with_docker_compose`
  ```shell
  make start
  ```

- Откройте админку и перейдите в терминал роутера
- Сорздайте новый спейс:

  ```lua
  aeon.router.create_space{
          name = 'myspace',
          format = {
            {name = 'id', type = 'string'},
            {name = 'name', type = 'string'},
          },
          key_def = {
            {field = 'id', type = 'string'}
          }
  }
  ```

- Добавьте несколько записей в таблицу:

  ```lua
  aeon.router.replace({
        space = 'myspace',
        tuples = {
            { 'a', 'b' },
            { 'c', 'd' },
        },
        flags = {
            return_tuples = true,
        }
  })
  ```

- Сделайте выборку значений:

  ```lua
  aeon.router.select{
        space = 'myspace',
        key = {'a'},
        iterator = 'gt',
        limit = 100,
  }
  ```

- Остановите кластер

  ```shell
  make stop
  ```
