local helpers = require('tt-migrations.helpers')

local function apply()
    local space = box.schema.space.create('customers', {
        if_not_exists = true,
        format = {
            { name = 'id', type = 'integer' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'name', type = 'string' },
            { name = 'surname', type = 'string' },
            { name = 'age', type = 'number' },
        },
    })
    space:create_index('pk', { parts = {'id'}, if_not_exists = true})
    space:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('customers', {'id'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
