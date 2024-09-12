local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

local function apply()
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

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
