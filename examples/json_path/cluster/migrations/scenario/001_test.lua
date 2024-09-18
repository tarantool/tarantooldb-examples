local helpers = require('tt-migrations.helpers')

local function apply()
    local space_test = box.schema.space.create('test', {if_not_exists = true})
    space_test:format({
        { name = 'id', type = 'integer' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'users', type = 'map' },
        { name = 'authors', type = 'array' },
        { name = 'payload', type = 'string', is_nullable = true },
    })
    space_test:create_index('pk', { parts = {'id'}, if_not_exists = true})
    space_test:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    helpers.register_sharding_key('test', {'id'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
