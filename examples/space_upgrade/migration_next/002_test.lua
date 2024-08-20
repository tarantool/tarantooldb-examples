local utils = require('migrator.utils')
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
        box.schema.func.create('__migrator_projects_002', {
            language = 'lua',
            is_deterministic = true,
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
                { name = 'assigned_manager_id', type = 'uuid', is_nullable = true },
                { name = 'description', type = 'string', is_nullable = true },
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
                { name = 'status', type = 'number' },
                { name = 'project_id', type = 'uuid' },
                { name = 'assigned_user_id', type = 'uuid', is_nullable = true },
                { name = 'due_date', type = 'datetime' },
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
