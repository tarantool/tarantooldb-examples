local helpers = require('tt-migrations.helpers')

local function apply()
    local test = box.schema.space.create('test', { if_not_exists = true })
    test:format({
        { name = 'uuid', type = 'string' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'count', type = 'number' },
    })
    test:create_index('pk', { parts = {'uuid'}, if_not_exists = true })
    test:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('test', {'uuid'})
    return true
end

return {
    apply = {
        scenario = apply,
    }
}
