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
        {title = 'Dune', author = 'Frank Herbert'},
        {title = 'Fahrenheit 451', author = 'Ray Bradbury'},
        {title = 'Foundation', author = 'Isaac Asimov'},
        {title = 'Solaris', author = 'Stanislaw Lem'},
        {title = 'The Hobbit', author = 'J. R. R. Tolkien'},
        {title = 'The Martian', author = 'Andy Weir'},
    }

    -- Reserve IDs below 1000 for the original books and manual CRUD requests.
    for id = 1000, 1999 do
        local book = books[(id - 1000) % #books + 1]
        local _, err = crud.replace_object('books', {
            id = id,
            title = book.title,
            author = book.author,
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
