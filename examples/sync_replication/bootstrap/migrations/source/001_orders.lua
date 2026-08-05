local utils = require('migrator.utils')

local function is_router()
    return utils.check_roles_enabled({'crud-router'})
end

local function up()
    if not is_router() then
        local orders = box.schema.space.create('orders', {is_sync = true, if_not_exists = true})
        orders:format({
            {name = 'order_id', type = 'number'},
            {name = 'bucket_id', type = 'unsigned'},
            {name = 'customer_name', type = 'string'},
            {name = 'amount', type = 'number'},
            {name = 'status', type = 'string'},
        })
        orders:create_index('pk', {parts = {'order_id'}, if_not_exists = true})
        orders:create_index('bucket_id', {parts = {'bucket_id'}, unique = false, if_not_exists = true})

        utils.register_sharding_key('orders', {'order_id'})
    end

    return true
end

return {
    up = up,
}
