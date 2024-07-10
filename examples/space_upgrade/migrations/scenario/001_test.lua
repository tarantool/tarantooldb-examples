local helpers = require('tt-migrations.helpers')
local rconfig = require('config')

local function has_a_role(role_name)
    local roles = rconfig:get().roles
    for _, rname in pairs(roles) do
        if rname == role_name then
            return true
        end
    end

    return false
end

local function is_router()
    return has_a_role('roles.crud-router')
end

local function is_storage()
    return has_a_role('roles.crud-storage')
end

local function up()
    if is_storage() then
        -- задаем спейсы и индексы для них
        box.schema.space.create('projects', { if_not_exists = true })
        box.space.projects:format({
            { name = 'project_id', type = 'uuid' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'name', type = 'string' },
            { name = 'description', type = 'string', is_nullable = true },
        })
        box.space.projects:create_index('pk', { parts = {'project_id'}, if_not_exists = true})
        box.space.projects:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        -- указываем ключ шардирования для модуля CRUD
        helpers.register_sharding_key('projects', {'project_id'})

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
            { name = 'email', type = 'string' },
        })
        box.space.users:create_index('pk', { parts = {'user_id'}, if_not_exists = true})
        box.space.users:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        helpers.register_sharding_key('users', {'user_id'})
    end
    if is_router() then
        -- __fill_data используется для заполнения кластера тестовыми данными в большом объеме
        box.schema.func.create('__fill_data', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    local uuid = require('uuid')
                    local fiber = require('fiber')
                    local len = 700000
                    local ch = fiber.channel(20)
                    local log = require('log')

                    log.info('start to fill_data')
                    for i = 1, len / 1000 do
                        log.info("send batch %s", i)
                        fiber.create(function(ch)
                            local projects, tasks, users = {}, {}, {}
                            fiber.sleep(0.01)
                            
                            for i = 1, 1000 do
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
                            end
                            crud.replace_object_many('projects', projects)
                            crud.replace_object_many('users', users)
                            crud.replace_object_many('tasks', tasks)
                            ch:put(box.NULL)
                        end, ch)
                        ch:get()
                    end
                    log.info('data filled')
                end
            ]],
        })
    end

    return true
end

return {
    up = {
        scenario = up,
    },
}
