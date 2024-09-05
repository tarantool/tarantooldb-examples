local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')

local function is_router()
    return fun.index('roles.crud-router', config:get('roles')) ~= nil
end

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

local function apply()
    -- создание спейсов и индексов для них
    box.schema.space.create('projects', { if_not_exists = true })
    box.space.projects:format({
        { name = 'project_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'description', type = 'string', is_nullable = true },
    })
    box.space.projects:create_index('pk', { parts = {'project_id'}, if_not_exists = true})
    box.space.projects:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('projects', {'project_id'}) -- указываем ключ шардирования для модуля CRUD

    box.schema.space.create('tasks', { if_not_exists = true })
    box.space.tasks:format({
        { name = 'task_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'description', type = 'string', is_nullable = true },
        { name = 'status', type = 'string' },
        { name = 'project_id', type = 'uuid' },
        { name = 'assigned_user_id', type = 'uuid', is_nullable = true },
    })
    box.space.tasks:create_index('pk', { parts = {'task_id'}, if_not_exists = true})
    box.space.tasks:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    box.space.tasks:create_index('project_id', { parts = {'project_id'}, unique = false, if_not_exists = true})
    box.space.tasks:create_index('assigned_user_id', { parts = {'assigned_user_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('tasks', {'project_id'})

    box.schema.space.create('users', { if_not_exists = true })
    box.space.users:format({
        { name = 'user_id', type = 'uuid' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'email', type = 'string', is_nullable = true },
    })
    box.space.users:create_index('pk', { parts = {'user_id'}, if_not_exists = true})
    box.space.users:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('users', {'user_id'})

    if is_storage() then
        -- задаем функции, вызываемые через vshard
        -- tasks.replace_user заменяет одного пользователя на другого по всем задачам на сторадже
        -- tasks у которых assigned_user_id == user_id
        box.schema.func.create('tasks.replace_user', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(current_user_id, new_user_id)
                    local fiber = require('fiber')
                    local every_100 = 0
                    for _, t in box.space.tasks.index.assigned_user_id:pairs({current_user_id}, 'EQ') do
                        box.space.tasks:update(t.task_id, {{'=', 'assigned_user_id', new_user_id}})
                        every_100 = every_100 + 1
                        if every_100 == 100 then
                            every_100 = 0
                            fiber.yield()
                        end
                    end
                    return true
                end
            ]],
        })

        -- projects.delete_project удаляет транзакционно проект и все связанные с ним задачи
        box.schema.func.create('projects.delete_project', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(project_id)
                    local proj = box.space.projects:get(project_id)
                    if proj == nil then
                        return false
                    end

                    -- данные из projects и tasks удалятся транзакционно
                    box.atomic(function()
                        box.space.projects:delete(project_id)

                        for _, t in box.space.tasks.index.project_id:pairs({project_id}, 'EQ') do
                            box.space.tasks:delete(t.task_id)
                        end
                    end)
                    return true
                end
            ]],
        })
    end

    if is_router() then
        -- app.delete_user удаляет пользователя и во всех задачах связанных с ним в поле assigned_user_id сохраняет box.NULL
        box.schema.func.create('app.delete_user', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(user_id)
                    local vshard_router = require('vshard.router')
                    local _, err = crud.delete('users', user_id)
                    if err ~= nil then
                        return {err = err, res = box.NULL}
                    end

                    -- vshard_router.map_callrw вызовет `tasks.replace_user` на всех стораджах
                    local _, err, uuid = vshard_router.map_callrw('tasks.replace_user', {user_id, box.NULL})
                    if err ~= nil then
                        return {err = err, res = box.NULL, uuid = uuid}
                    end

                    return {res = true, err = box.NULL}
                end
            ]],
        })
        -- app.get_project_data возрващает данные по проекту project_id, а также данные по задачам в проекте и
        -- пользователям, связанными с этими задачами
        box.schema.func.create('app.get_project_data',  {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(project_id)
                    -- получаем наш проект, нам нужны только поля 'name' и 'description', остальные мы со стораджа не забираем
                    local res, err = crud.get('projects', project_id, {fields = {'name', 'description'}})
                    if err ~= nil then
                        return {res = box.NULL, err = err}
                    end

                    -- проверка, на случай если crud.get не вернул данных
                    -- next(res.rows) вернет nil, если таблица res.rows пустая
                    if next(res.rows) == nil then
                        return {res = {}, err = box.NULL}
                    end
                    local project = crud.unflatten_rows(res.rows, res.metadata)[1]

                    local opts = { use_tomap = true,  fields = {'name', 'description', 'status', 'assigned_user_id'} }

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
                        }
                        table.insert(project.tasks, task)

                        -- после получения задачи, находим для нее пользователя
                        if t.assigned_user_id ~= box.NULL then
                            -- провеяем, не запрашивали ли мы этого пользователя ранее
                            if seen_users[t.assigned_user_id] == nil then
                                local user_res, err = crud.get('users', t.assigned_user_id, {fields = {'name', 'email'}})
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

        -- app.delete_project удаляет проект и все связанные с ним задачи
        box.schema.func.create('app.delete_project', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(project_id)
                    -- вычисляем на какой мастер послать запрос
                    local vshard_router = require('vshard.router')
                    local bucket_id = vshard_router.bucket_id_strcrc32(project_id)
                    local _, err = vshard_router.callrw(bucket_id, 'projects.delete_project', {project_id})
                    if err ~= nil then
                        return {res = box.NULL, err = err}
                    end
                    return {res = true, err = box.NULL}
                end
            ]],
        })

         -- __create_example_data_mant используется для заполнения кластера тестовыми данными в большом объеме
        box.schema.func.create('__generate_data', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(size)
                    local uuid = require('uuid')
                    local fiber = require('fiber')

                    local final_size = size or 450000
                    local projects, tasks, users = {}, {}, {}
                    local batch_size = 1000
                    for n = 1, size do
                        table.insert(projects, {
                            project_id = uuid.new(),
                            name = 'Task Management ' .. i,
                            description = 'Development of a task management system ' .. i,
                        })
                        table.insert(users, {
                            user_id = uuid.new(),
                            name = 'john_doe ' .. i,
                            email = 'john.doe' .. i .. "@example.com"
                        })
                        table.insert(tasks, {
                            task_id = uuid.new(),
                            name = 'Create New Logo',
                            description = 'Design a new logo for the website.',
                            status = 'Not Started',
                            project_id = uuid.new(),
                            assigned_user_id = uuid.new(),
                        })

                        if (n % batch_size == 0) or (n == size) then
                            crud.replace_object_many('projects', projects)
                            crud.replace_object_many('users', users)
                            crud.replace_object_many('tasks', tasks)

                            projects, tasks, users = {}, {}, {}
                            fiber.yield()
                        end
                    end
                end
            ]],
        })
    end

    return true

end

return {
    apply = {
        scenario = apply,
    }
}
