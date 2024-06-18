local helpers = require('tt-migrations.helpers')

local function up()
     -- Создание спейса customers
    box.schema.space.create('customers', {if_not_exists = true})
    box.space.customers:format({
        { name = 'id', type = 'integer' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'name', type = 'string' },
        { name = 'surname', type = 'string' },
        { name = 'age', type = 'number' },
    })
    box.space.customers:create_index('pk', { parts = {'id'}, if_not_exists = true})
    box.space.customers:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    box.space.customers:create_index('age_index', { parts = {'age'}, unique = false, if_not_exists = true})
    box.space.customers:create_index('full_name', { parts = {'name', 'surname'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('customers', {'id'})

    return true
end

return {
    up = {
        scenario = up,
    },
}
