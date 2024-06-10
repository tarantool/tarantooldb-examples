local helpers = require('tt-migrations.helpers')

local function up()
    local space_test = box.schema.space.create('test', {if_not_exists = true})
    space_test:format({
        { name = 'id', type = 'integer' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'data', type = 'any' },
    })
    space_test:create_index('pk', { parts = {'id'}, if_not_exists = true})
    space_test:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    helpers.register_sharding_key('test', {'id'})

    box.schema.func.create('hello', {
        language = 'LUA',
        if_not_exists = true,
        body = [[
            function() return 'Hello!' end
        ]]
    })

    return true
end

return {
    up = {
        scenario = up,
    },
}
