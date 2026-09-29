local config = require('config')
local fun = require('fun')

local function is_router()
    return fun.index('roles.crud-router', config:get('roles')) ~= nil
end

local function apply()
    if not is_router() then
        return true
    end

    local crud = require('crud')
    for id = 1, 8 do
        local _, err = crud.replace_object('test_kv', {
            id = id,
            name = string.format('seed-demo-row-%02d', id),
            payload = {source = 'grpc-example'},
        }, {timeout = 5})
        if err ~= nil then
            error(err)
        end
    end

    return true
end

return {
    apply = {scenario = apply},
}
