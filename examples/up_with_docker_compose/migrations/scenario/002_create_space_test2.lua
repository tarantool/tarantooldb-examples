local helpers = require('tt-migrations.helpers')

local function up()
    box.schema.space.create('test2', {if_not_exists = true})
    box.space.test2:format({
        { name = 'id', type = 'integer' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'data', type = 'any' },
    })
    box.space.test2:create_index('pk', { parts = {'id'}, if_not_exists = true})
    box.space.test2:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('test2', {'id'})
end

return {
    up = {
        scenario = up,
    },
}
