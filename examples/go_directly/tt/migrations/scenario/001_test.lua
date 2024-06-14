local helpers = require('tt-migrations.helpers')

local function up()
    box.schema.space.create('test', {if_not_exists = true})
    box.space.test:format({
        { name = 'id', type = 'number' },
        { name = 'too', type = 'number' },
        { name = 'foo', type = 'string' },
    })
    box.space.test:create_index('pk', { parts = {'id'}, if_not_exists = true })

    helpers.register_sharding_key('test', {'id'})

    return true
end

return {
    up = {
        scenario = up,
    },
}
