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
    local _, err = crud.replace_object('books', {
        id = 1,
        title = 'The Hobbit',
        author = 'J. R. R. Tolkien',
    }, {timeout = 5})
    if err ~= nil then
        error(err)
    end

    return true
end

return {
    apply = {scenario = apply},
}
