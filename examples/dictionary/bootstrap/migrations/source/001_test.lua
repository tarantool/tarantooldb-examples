local utils = require('migrator.utils')

local function is_router()
    return utils.check_roles_enabled({'crud-router'})
end

local function up()

    if is_router() then
        box.schema.func.create('get_money_move', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(money_move_id)
                    local vshard = require('vshard')
                    local bucket_id = vshard.router.bucket_id_strcrc32(money_move_id)
                    return vshard.router.callro(bucket_id, 'box.schema.func.call', { 'get_money_move', money_move_id })
                end
            ]]
        })
    else
        box.schema.space.create('money_moves', {if_not_exists = true})
        box.space.money_moves:format({
            { name = 'money_move_id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'recorder_id', type = 'number' },
            { name = 'dt', type = 'datetime' },
            { name = 'category_id', type = 'string' },
            { name = 'income', type = 'boolean' },
            { name = 'amount', type = 'number' },
        })
        box.space.money_moves:create_index('pk', { parts = {'money_move_id'}, if_not_exists = true})
        box.space.money_moves:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        utils.register_sharding_key('money_moves', {'money_move_id'})

        box.schema.func.create('get_money_move', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(money_move_id)
                    local tuple = box.space.money_moves:get(money_move_id)
                    local money_move = tuple:tomap({names_only = true})
                    local category_name = dictionary.get('categories', money_move.category_id)
                    if category_name then
                        money_move.category_name = category_name
                    end

                    return money_move
                end
            ]]
        })
    end

    return true
end

return {
    up = up,
}
