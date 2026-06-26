local config = require('config')
local fun = require('fun')

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

local function apply()

    if is_storage() then
        -- Удаляем старый спейс.
        box.space.bands_old:drop()

        -- Удаляем триггер.
        if box.schema.func.exists('002_extend_bands_pk/bands_on_replace_trigger') then
            box.schema.func.drop('002_extend_bands_pk/bands_on_replace_trigger')
        end

        -- Удаляем функцию мониторинга.
        if box.schema.func.exists('extend_bands_pk_migration_progress') then
            box.schema.func.drop('extend_bands_pk_migration_progress')
        end
    end

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
