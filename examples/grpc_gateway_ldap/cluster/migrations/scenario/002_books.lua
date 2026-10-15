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
    local books = {
        {id = 1, title = 'Dune', author = 'Frank Herbert'},
        {id = 2, title = 'Fahrenheit 451', author = 'Ray Bradbury'},
        {id = 3, title = 'Foundation', author = 'Isaac Asimov'},
        {id = 4, title = 'Solaris', author = 'Stanislaw Lem'},
        {id = 5, title = 'The Hobbit', author = 'J. R. R. Tolkien'},
        {id = 6, title = 'The Martian', author = 'Andy Weir'},
    }

    for _, book in ipairs(books) do
        local _, err = crud.replace_object('books', book, {timeout = 5})
        if err ~= nil then
            error(err)
        end
    end

    return true
end

return {
    apply = {scenario = apply},
}
