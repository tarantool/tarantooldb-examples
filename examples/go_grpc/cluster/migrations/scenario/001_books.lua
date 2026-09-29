local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')

local function apply()
    if fun.index('roles.crud-storage', config:get('roles')) == nil then
        return true
    end

    local books = box.schema.space.create('books', {if_not_exists = true})
    books:format({
        {name = 'id', type = 'unsigned'},
        {name = 'bucket_id', type = 'unsigned'},
        {name = 'title', type = 'string'},
        {name = 'author', type = 'string'},
    })
    books:create_index('primary', {parts = {'id'}, if_not_exists = true})
    books:create_index('bucket_id', {parts = {'bucket_id'}, unique = false, if_not_exists = true})
    helpers.register_sharding_key('books', {'id'})
    return true
end

return {
    apply = {scenario = apply},
}
