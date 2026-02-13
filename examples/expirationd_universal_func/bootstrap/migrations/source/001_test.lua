local utils = require('migrator.utils')

local function is_storage()
    return utils.check_roles_enabled({'crud-storage'})
end

local function is_router()
    return utils.check_roles_enabled({'crud-router'})
end

local function up()
    if is_storage() then
        -- создание спейса space_too
        local s = box.schema.space.create('space_too', {if_not_exists = true})
        s:format({
            { name = 'id', type = 'uuid' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'text', type = 'string' },
            { name = 'create_date', type = 'datetime' },
        })
        s:create_index('pk', { parts = {'id'}, if_not_exists = true})
        s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    
        utils.register_sharding_key(s.name, {'id'})

        -- создание спейса space_foo
        s = box.schema.space.create('space_foo', {if_not_exists = true})
        s:format({
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'dt', type = 'datetime' },
            { name = 'data', type = 'any' },
        })
        s:create_index('pk', { parts = {'id'}, if_not_exists = true})
        s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        utils.register_sharding_key(s.name, {'id'})

        -- создание спейса space_bar
        s = box.schema.space.create('space_bar', {if_not_exists = true})
        s:format({
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'create_at', type = 'datetime' },
            { name = 'data', type = 'uuid' },
        })
        s:create_index('pk', { parts = {'id'}, if_not_exists = true})
        s:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        utils.register_sharding_key(s.name, {'id'})

        box.schema.func.create('is_tuple_expired', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function (args, tuple)
                    local datetime = require('datetime')

                    if type(args) ~= 'table' then
                        return false
                    end
                    if not args.date_field_name or not args.seconds then
                        return false
                    end

                    local tuple_dt = tuple[args.date_field_name]
                    if not tuple_dt then
                        return false
                    end

                    local seconds = datetime.interval.new({ sec = args.seconds })
                    local expired_dt = datetime.now() - seconds

                    return tuple_dt < expired_dt
                end
            ]]
        })
    end


    if is_router() then
        -- вспомогательные функции для фоновой записи данных в спейсы для примеров
        box.schema.func.create('generate_data_start', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    local fiber = require('fiber')
                    local ch = fiber.channel()
                    local datetime = require('datetime')
                    local uuid = require('uuid')
                    local digest = require('digest')
                    local current_id = 1

                    local generate_data_fiber = fiber.create(function()
                        while true do
                            local is_stop = ch:get(0)
                            if is_stop then
                                break
                            end
                            fiber.sleep(0.1)

                            local text = digest.md5_hex(tostring(current_id))
                            local uid = uuid.new()

                            crud.replace('space_too', {uid, box.NULL, text, datetime.now()})
                            crud.replace('space_foo', {current_id, box.NULL, datetime.now(), {
                                too_uid = uid,
                                foo_id = current_id,
                            }})
                            crud.replace('space_bar', {current_id, box.NULL, datetime.now(), uid})

                            current_id = current_id + 1
                        end
                    end)
                    generate_data_fiber:name('generate_data_fiber')
                    rawset(_G, 'generate_data', {
                        stop_ch = ch,
                        fiber = generate_data_fiber,
                    })
                    return 'Generate data started'
                end
            ]],
        })
        box.schema.func.create('generate_data_stop', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    local generate_data = rawget(_G, 'generate_data')
                    if generate_data == nil then
                        return
                    end
                    generate_data.stop_ch:put(true)
                    return 'Generate data stopped'
                end
            ]],
        })
    end
    return true
end

return {
    up = up,
}
