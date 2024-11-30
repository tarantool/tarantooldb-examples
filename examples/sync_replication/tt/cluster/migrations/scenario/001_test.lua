local helpers = require('tt-migrations.helpers')

local function apply()
    local users = box.schema.space.create('sync_space', {if_not_exists = true, is_sync = true})
    users:format({
        { name = 'uuid', type = 'string' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'too', type = 'number' },
        { name = 'foo', type = 'string' },
    })
    users:create_index('pk', { parts = {'uuid'}, if_not_exists = true })
    users:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('sync_space', {'uuid'})

    local profiles = box.schema.space.create('async_space', { if_not_exists = true })
    profiles:format({
        { name = 'uuid', type = 'string' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'too', type = 'number' },
        { name = 'foo', type = 'string' },
    })
    profiles:create_index('pk', { parts = {'uuid'}, if_not_exists = true })
    profiles:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('async_space', {'uuid'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
