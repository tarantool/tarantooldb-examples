local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')

local function is_router()
    return fun.index('roles.crud-router', config:get('roles')) ~= nil
end

local function apply()
    if is_router() then
        box.schema.func.create('get_money_move', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(money_move_id)
                    function convert_to_map(metadata, tuple)
                        local res = {}
                        for field_num, field_meta in ipairs(metadata) do
                            res[field_meta.name] = tuple[field_num]
                        end

                        return res
                    end

                    local resp, err = crud.get('money_moves', money_move_id)
                    if err ~= nil then
                        return nil, err
                    end

                    if #resp.rows == 0 then
                        return
                    end

                    local money_move = convert_to_map(resp.metadata, resp.rows[1])
                    local category_name = dictionary.get('categories', money_move.category_id)
                    if category_name then
                        money_move.category_name = category_name
                    end

                    return money_move
                end
            ]]
        })
    else
        local money_moves_space = box.schema.space.create('money_moves', {
            if_not_exists = true,
            format = {
                { name = 'money_move_id', type = 'number' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'recorder_id', type = 'number' },
                { name = 'dt', type = 'datetime' },
                { name = 'category_id', type = 'string' },
                { name = 'income', type = 'boolean' },
                { name = 'amount', type = 'number' },
            },
        })

        money_moves_space:create_index('pk', { parts = {'money_move_id'}, if_not_exists = true})
        money_moves_space:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        helpers.register_sharding_key(money_moves_space.name, {'money_move_id'})
    end

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
