local rconfig = require('config')

 local function is_storage()
        local roles = rconfig:get().roles
        for _, rname in pairs(roles) do
            if rname == 'roles.crud-storage' then
                return true

            end
        end

        return false
    end

local function apply()
    if is_storage() then
        -- Функция для преобразования кортежей в спейсе projects
        box.schema.func.create('__migrator_projects_002', { -- Давайте функции название с номером миграции
            language = 'lua', -- Функция на Lua
            is_deterministic = true, -- Функция детерминированная
            body = [[
                function(t)
                    if #t == 4 then
                        return t:update({{'!', 4, box.NULL}})
                    end
                    return t
                end
            ]]
        })

        local projects_migration = box.space.projects:upgrade({
            func = '__migrator_projects_002',
            format = {
                { name = 'project_id', type = 'uuid' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'name', type = 'string' },
                -- Добавили поле assigned_manager_id
                { name = 'assigned_manager_id', type = 'uuid', is_nullable = true },
                { name = 'description', type = 'string', is_nullable = true },
            },
            mode = 'dryrun+upgrade',
            is_async = true,
        })
        rawset(_G, '__projects_migration', projects_migration)

        -- Функция для преобразования кортежей в спейсе tasks
        box.schema.func.create('__migrator_tasks_002', {
            language = 'lua',
            is_deterministic = true,
            body = [[
                function(t)
                    -- Задана дата по умолчанию для due_date
                    local datetime = require('datetime')
                    local due_date = datetime.new({year=2999, month=12, day=31})
                    -- Проверили количество полей. Если полей 7, это означает, что поле due_date добавлено не было
                    if #t == 7 then
                        -- Чтобы изменить тип поля, старое поле нужно удалить и добавить вместо него новое
                        -- Для этого подходит функция `tuple:transform`
                        -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_tuple/transform/
                        -- t:transform(5, 1, 0) удаляет одно поле, начиная с пятого (status), и добавляет вместо него число 0
                        -- update({{"!", 8, due_date}}) добавляет поле в конец, на восьмую позицию, и присваивает полю значение due_date
                        return t:transform(5, 1, 0):update({{"!", 8, due_date}})
                    end
                    return t
                end
            ]],
        })

        local tasks_migration = box.space.tasks:upgrade({
            func = '__migrator_tasks_002',
            format = {
                { name = 'task_id', type = 'uuid' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'name', type = 'string' },
                { name = 'description', type = 'string', is_nullable = true },
                -- Изменили тип поля status
                { name = 'status', type = 'number' },
                { name = 'project_id', type = 'uuid' },
                { name = 'assigned_user_id', type = 'uuid', is_nullable = true },
                -- Добавили новое поле due_date
                { name = 'due_date', type = 'datetime' },
            },
            mode = 'dryrun+upgrade',
            is_async = true,
        })
        rawset(_G, '__tasks_migration', tasks_migration)

        -- Функция для преобразования кортежей в спейсе users
        box.schema.func.create('__migrator_users_002',  {
            language = 'lua',
            is_deterministic = true,
            body = [[
                function(t)
                    -- Проверили, что поле role еще не добавлено
                    if #t == 4 then
                        -- Добавили новое поле на четвертую позицию, между name и contact
                        return t:update({{'!', 4, 'not set'}})
                    end
                    return t
                end
            ]],
        })

        local users_migration = box.space.users:upgrade({
            func = '__migrator_users_002',
            format = {
                { name = 'user_id', type = 'uuid' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'name', type = 'string' },
                -- Добавили новое поле role
                { name = 'role', type = 'string' },
                -- Изменили название поля на contact
                { name = 'contact', type = 'string' },
            },
            mode = 'dryrun+upgrade',
            is_async = true,
        })
        rawset(_G, '__users_migration', users_migration)
    end
end

return {
    apply = {
        scenario = apply,
    }
}
