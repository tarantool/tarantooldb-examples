local helpers = require('tt-migrations.helpers')
local config = require('config')
local fun = require('fun')
local fiber = require('fiber')

local function is_storage()
    return fun.index('roles.crud-storage', config:get('roles')) ~= nil
end

--[[
    Пример миграции, изменяющей первичный индекс спейса
    ===================================================

    ВАЖНО: Миграция реализована через создание нового спейса и копирования данных в него. Это приводит
           к удвоенному потреблению памяти этим спейсом на время миграции.

    В примере используется спейс `bands`, созданный следующим образом:
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
--]]

local function apply()

    if is_storage() then
        -- Создаем новый спейс с теми же параметрами, что и исходный.
        -- Вносим необходимые изменения в формат.
        local space_bands_new = box.schema.space.create('bands_new', {
            if_not_exists = true,
            format = {
                { name = 'id', type = 'integer' },
                -- Мы добавили новое поле `sub_id`, которое станет частью первичного ключа.
                { name = 'sub_id', type = 'integer' },
                { name = 'bucket_id', type = 'unsigned' },
                { name = 'band_name', type = 'string' },
                { name = 'year', type = 'integer' },
            },
        })
        -- Новый первичный индекс включает в себя поля `id` и `sub_id`.
        space_bands_new:create_index('primary_key', { parts = {'id', 'sub_id'}, if_not_exists = true })
        -- Вторичный индекс `bucket_id` оставляем без изменений.
        space_bands_new:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true })

        -- Добавляем на исходный спейс on_replace триггер, который будет дублировать
        -- все изменения таплов в новый спейс.
        box.schema.func.create('002_extend_bands_pk/bands_on_replace_trigger', {
            if_not_exists = true,
            language = 'lua',
            body = [[
                function(old, new, space_name, request_type)
                    local space_bands_new = box.space.bands_new
                    if space_name == 'bands_old' then
                        space_bands_new = box.space.bands
                    end
                    if request_type == 'DELETE' then
                        space_bands_new:delete{old.id, old.id}
                    else
                        local tup = new:totable()
                        -- Приводим формат тапла к формату нового спейса.
                        -- В данном случае, считаем, что `sub_id` по умолчанию должен быть равен `id`.
                        table.insert(tup, 2, new.id)
                        space_bands_new:replace(tup)
                    end
                end
            ]],
            trigger = 'box.space.bands.on_replace'
        })

        -- Создаем функцию, которая позволяет следить за прогрессом миграции на каждом сторадже:
        -- Во время миграции функцию можно вызвать так: box.func.extend_bands_pk_migration_progress:call()
        box.schema.func.create('extend_bands_pk_migration_progress',{
            if_not_exists = true,
            language = 'lua',
            body = [[
                function()
                    if box.space.bands_old ~= nil then
                        local old = box.space.bands_old:len()
                        local new = box.space.bands:len()
                        return string.format(
                            'Migration is complete. Old space tuples: %d. New space tuples: %d.',
                            old, new)
                    end
                    local old = box.space.bands:len()
                    local new = box.space.bands_new:len()
                    return string.format(
                        'Migration is in progress. Tuples copied: %d / %d.',
                        new, old)
                end
            ]],
        })

        -- Копируем все таплы из оригинального спейса в новый.
        -- Копирование осуществляется группами по `batch_limit` таплов.
        local batch_limit = 1000
        local last_tuple = box.NULL
        while true do
            local count = 0
            for _, tup in box.space.bands:pairs(nil, { after = last_tuple }) do
                local new_tuple = tup:totable()
                table.insert(new_tuple, 2, tup.id)
                local ok, err = pcall(box.space.bands_new.insert, box.space.bands_new, new_tuple)
                if not ok and (err.type ~= 'ClientError' or err.code ~= box.error.TUPLE_FOUND) then
                    error(string.format('Migration failed on tuple %s: %s', tup, err))
                end
                last_tuple = tup

                count = count + 1
                if count >= batch_limit then
                    break
                end
            end

            if count < batch_limit then
                break
            end

            fiber.yield()
        end

        --[[
            По завершении копирования данных переименовываем спейсы, `bands_old` нужно будет позже удалить вручную.

            ВАЖНО: Если в коде приложения обращение к спейсам идет не по имени, а через переменную, или по id,
                   то этот код продолжит обращаться к старому спейсу, потребуется модификация приложения.
        --]]
        box.atomic(function()
            box.space.bands:rename('bands_old')
            box.space.bands_new:rename('bands')
        end)
        --[[
            В качестве альтернативы можно не переименовывать спейсы, а после завершения миграции вручную обновить
            код приложения для работы с новым спейсом. В этом случае важно не забыть зарегистрировать ключ
            шардирования при создании нового спейса:
                helpers.register_sharding_key('bands_new', {'id'})
        --]]
    end

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
