local config = require('config')
local fun = require('fun')
local cooler = require('cooler')

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

local function apply()
    if is_storage() then
        box.schema.space.create('sessions', { engine = 'memtx', if_not_exists = true })
        box.space.sessions:format({
            { name = 'id', type = 'unsigned' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'status', type = 'string' },
            { name = 'updated_at', type = 'number' },
        })

        box.space.sessions:create_index('primary', {
            parts = { 'id' },
            if_not_exists = true,
        })

        box.space.sessions:create_index('bucket_id', {
            parts = { 'bucket_id' },
            unique = false,
            if_not_exists = true,
        })

        box.space.sessions:create_index('by_updated_at', {
            parts = { 'updated_at' },
            unique = false,
            if_not_exists = true,
        })

        box.schema.func.create('sessions_updated_at_start_key', {
            body = "function() return require('clock').time() - 60 * 30 end",
            if_not_exists = true,
        })

        cooler.set_func('sessions', "t.updated_at < box.func.sessions_updated_at_start_key:call()")

        cooler.setup('sessions', {
            -- Параметры vinyl
            vinyl_params = {
                bloom_fpr = 0.05,
                run_count_per_level = 8,
                run_size_ratio = 3.5,
            }
        })
    end
end

return {
    apply = {
        scenario = apply,
    }
}
