local helpers = require('tt-migrations.helpers')

local function apply()
    box.schema.space.create('orders', {if_not_exists = true})
    box.space.orders:format({
        { name = 'id', type = 'number' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'customer', type = 'string' },
        { name = 'amount', type = 'number' },
    })
    box.space.orders:create_index('pk', { parts = {'id'}, if_not_exists = true})
    box.space.orders:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('orders', {'id'})

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
