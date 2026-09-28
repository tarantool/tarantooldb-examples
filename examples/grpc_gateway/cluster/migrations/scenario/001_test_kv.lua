local helpers = require('tt-migrations.helpers')

local function apply()
    local test_kv = box.schema.space.create('test_kv', {if_not_exists = true})
    test_kv:format({
        { name = 'id', type = 'unsigned' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'payload', type = 'map', is_nullable = true },
    })
    test_kv:create_index('primary', { parts = {'id'}, if_not_exists = true })
    test_kv:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true })
    -- The composite index lets pagination continue from (name, id),
    -- even when multiple records have the same name.
    test_kv:create_index('name', { parts = {'name', 'id'}, unique = false, if_not_exists = true })

    helpers.register_sharding_key('test_kv', {'id'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
