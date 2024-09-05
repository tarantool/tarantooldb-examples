local helpers = require('tt-migrations.helpers')

local function apply()
    local s = box.schema.space.create('test', {
        if_not_exists = true,
        format = {
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'too', type = 'number' },
            { name = 'foo', type = 'string' },
        },
    })
    s:create_index('pk', { parts = {'id'}, if_not_exists = true})
    s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key(s.name, {'id'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
