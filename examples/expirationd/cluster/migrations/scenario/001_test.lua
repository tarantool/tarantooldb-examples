local helpers = require('tt-migrations.helpers')

local function apply()
    local s = box.schema.space.create('test', {if_not_exists = true})
    s:format({
        { name = 'id', type = 'number' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'dt', type = 'datetime' },
        { name = 'data', type = 'any' },
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
