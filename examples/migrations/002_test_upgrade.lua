local utils = require('migrator.utils')

local function is_router()
    return utils.check_roles_enabled({'crud-router'})
end

local function is_storage()
    return utils.check_roles_enabled({'crud-storage'})
end

local function up()
    if is_storage() then
        box.schema.func.create('__migrator_projects_002', {
            language = 'lua',
            is_deterministic = true,
            body = [[
                function(t)
                    local datetime = require('datetime')
                    local deadline = datetime.new({year=2999, month=12, day=31})
                    if #t == 4 then
                        return t:update({{'!', 5, deadline}})
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
                { name = 'description', type = 'string', is_nullable = true },
                { name = 'deadline', type = 'datetime', is_nullable = true },
            },
            mode = 'dryrun+upgrade',
            is_async = true,
        })
        rawset(_G, '__projects_migration', projects_migration)

        box.schema.func.create('__migrator_tasks_002', {
            language = 'lua',
            is_deterministic = true,
            body = [[
                function(t)
                    local datetime = require('datetime')
                    local due_date = datetime.new({year=2999, month=12, day=31})
                    if #t == 7 then
                        return t:update({{'!', 8, due_date}})
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
                { name = 'status', type = 'string' },
                { name = 'project_id', type = 'uuid' },
                { name = 'assigned_user_id', type = 'uuid', is_nullable = true },
                { name = 'due_date', type = 'datetime', is_nullable = true },
            },
            mode = 'dryrun+upgrade',
            is_async = true,
        })
        rawset(_G, '__tasks_migration', tasks_migration)

        box.schema.func.create('__migrator_users_002',  {
            language = 'lua',
            is_deterministic = true,
            body = [[
                function(t)
                    if #t == 4 then
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
                { name = 'role', type = 'string' },
                { name = 'email', type = 'string', is_nullable = true },
            },
            mode = 'dryrun+upgrade',
            is_async = true,
        })
        rawset(_G, '__users_migration', users_migration)
    end

    if is_router() then
        box.atomic(function()
            -- нам необходимо добавить работу с новыми полями в app.get_project_data
            -- чтобы обновить код в персистентной функции необходимо удалить ее и создать новый вариант
            box.schema.func.drop('app.get_project_data') -- удаляем старый вариант
            box.schema.func.create('app.get_project_data',  {
                language = 'LUA',
                if_not_exists = true,
                body = [[
                    function(project_id)
                        -- получаем наш проект, нам нужны только поля 'name', 'description' и 'deadline' остальные мы со стораджа не забираем
                        -- добавляется новое поел 'deadline'
                        local res, err = crud.get('projects', project_id, {fields = {'name', 'description', 'deadline'}})
                        if err ~= nil then
                            return {res = box.NULL, err = err}
                        end

                        -- проверка, на случай если crud.get не вернул данных
                        -- next(res.rows) вернет nil, если таблица res.rows пустая
                        if next(res.rows) == nil then
                            return {res = {}, err = box.NULL}
                        end
                        local project = crud.unflatten_rows(res.rows, res.metadata)[1]
    
                        -- добавляем в списков полей, получаемых со стораджа поле 'due_date'
                        local opts = { use_tomap = true,  fields = {'name', 'description', 'status', 'assigned_user_id', 'due_date' } }

                        -- кэшируем уже запрошенных пользователей, т.к. один пользователь может быть назначен на несколько задач
                        local seen_users = {}
                        project.tasks = {}

                        -- crud.pairs итерируется последовательно по шардам и возвращает запрашиваемые данные
                        -- данные запрашиваются со стораджей батчами, их можно указать в opts в параметре batch_size
                        -- по умолчанию он равен 100
                        for _, t in crud.pairs('tasks', {{"==", "project_id", project_id}}, opts) do
                            local task = {
                                name = t.name,
                                description = t.description,
                                status = t.status,
                                due_date = t.due_date,
                            }
                            table.insert(project.tasks, task)

                            -- после получения задачи, находим для нее пользователя
                            if t.assigned_user_id ~= box.NULL then
                                -- провеяем, не запрашивали ли мы этого пользователя ранее
                                if seen_users[t.assigned_user_id] == nil then
                                    -- добавляем в списков полей, получаемых со стораджа поле 'due_date'
                                    local user_res, err = crud.get('users', t.assigned_user_id, {fields = {'name', 'email', 'role'}})
                                    if err ~= nil then
                                        return {res = box.NULL, error = err}
                                    end
    
                                    local user = crud.unflatten_rows(user_res.rows, user_res.metadata)[1]
                                    if user == nil then
                                        goto continue
                                    end
                                    seen_users[t.assigned_user_id] = user
                                end
                                if seen_users[t.assigned_user_id] ~= nil then
                                    task.user = seen_users[t.assigned_user_id]
                                end
                            end
                            ::continue::
                        end
                        return {res = project, err = box.NULL}
                    end
                ]]
            })
        end)
    end
end

return {
    up = up,
}
