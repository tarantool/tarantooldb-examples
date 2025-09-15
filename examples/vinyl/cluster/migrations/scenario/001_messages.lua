local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

local function apply()
    if is_storage() then
        box.schema.space.create('messages', { engine = 'vinyl', if_not_exists = true })
        box.space.messages:format({
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'text', type = 'string' },
            { name = 'created_at', type = 'datetime' },
        })

        box.space.messages:create_index('bucket_id', { parts = { 'bucket_id', 'id' }, if_not_exists = true })

        helpers.register_sharding_key('messages', { 'id' })
    end
end

return {
    apply = {
        scenario = apply,
    }
}
