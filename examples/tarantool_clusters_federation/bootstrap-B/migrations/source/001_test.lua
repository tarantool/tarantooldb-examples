local utils = require('migrator.utils')

local function is_storage()
    return utils.check_roles_enabled({'crud-storage'})
end

local function apply()
    if is_storage() then
        box.schema.space.create('test', {if_not_exists = true})
        box.space.test:format({
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
        })
        box.space.test:create_index('pk', { parts = {'id'}, if_not_exists = true})
        box.space.test:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        utils.register_sharding_key('test', {'id'})
    end
    return true
end

return {
    apply = {
        scenario = apply,
    }
}
