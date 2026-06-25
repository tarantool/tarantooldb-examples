local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

local function apply()

    if is_storage() then
        local space_bands = box.schema.space.create('bands', {
            if_not_exists = true,
            format = {
                { name = 'id', type = 'integer' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'band_name', type = 'string' },
                { name = 'year', type = 'integer' },
            },
        })
        space_bands:create_index('primary_key', { parts = {'id'}, if_not_exists = true})
        space_bands:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        helpers.register_sharding_key(space_bands.name, {'id'})
    end

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
