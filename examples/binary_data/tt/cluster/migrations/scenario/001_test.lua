local helpers = require('tt-migrations.helpers')

local function apply()
    local s = box.schema.space.create('my_files', {
        if_not_exists = true,
        format = {
            { name = 'name', type = 'string' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'data', type = 'string' },
        },
    })

    s:create_index('pk', { parts = {'name'} })
    s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false })

    helpers.register_sharding_key(s.name, {'name'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
