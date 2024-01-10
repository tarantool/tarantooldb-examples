local utils = require('migrator.utils')

local function is_storage()
    local roles = require('cartridge.lua-api.get-topology').get_enabled_roles_without_deps()
    for _, rname in pairs(roles) do
        if rname == 'crud-storage' then
            return true
        end
    end

    return false
end

local function is_router()
    local roles = require('cartridge.lua-api.get-topology').get_enabled_roles_without_deps()
    for _, rname in pairs(roles) do
        if rname == 'crud-router' then
            return true
        end
    end

    return false
end

local function up()
    if is_storage() then
        -- спейс messages
        box.schema.space.create('messages', {if_not_exists = true})
        box.space.messages:format({
            { name = 'id', type = 'uuid' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'text', type = 'string' },
            { name = 'create_date', type = 'datetime' },
        })
        box.space.messages:create_index('pk', { parts = {'id'}, if_not_exists = true})
        box.space.messages:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
        box.space.messages:create_index('create_date', { parts = {'create_date'}, unique = false, if_not_exists = true})
    
        utils.register_sharding_key('message', {'id'})

        box.schema.func.create('messages_is_tuple_expired', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function() return true end
            ]]
        })

        box.schema.func.create('messages_iterate_with', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(options)
                    local datetime = require('datetime')
                    -- создаем интервал, используя аргументы из конфига
                    local int = datetime.interval.new({ sec = options.args.seconds or 60 }) 
                    -- возвращаем необходимый итератор
                    -- обходим по индексу `create_date`, начинаем от текущей момента минус заданный интервал
                    -- если iterator_type == LE, то будут удаляться все записи созданные более чем `options.args.seconds` секунд назад
                    return box.space.messages.index.create_date:pairs({ datetime.now() - int }, { iterator = 'LE' })
                end
            ]]
        })

        box.schema.func.create('messages_process_expired_tuple', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function(space, args, tuple)
                    box.space[space]:delete({tuple.id})
                end
            ]]
        })
    end


    if is_router() then
        -- вспомогательные функции для фоновой записи данных в спейсы для примеров
        box.schema.func.create('__start_messages_stream', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    local fiber = require('fiber')
                    local ch = fiber.channel()
                    local datetime = require('datetime')
                    local uuid = require('uuid')
                    local message_num = 1

                    local messages_fiber = fiber.create(function()
                        while true do
                            local is_stop = ch:get(0)
                            if is_stop then
                                break
                            end
                            fiber.sleep(0.1)
                            message_num = message_num + 1
                            crud.replace('messages', {uuid.new(), box.NULL, tostring(message_num), datetime.now()})
                        end
                    end)
                    messages_fiber:name('messages_fiber')
                    rawset(_G, '__start_messages_stream_data', {
                        stop_ch = ch,
                        fiber = messages_fiber,
                    })
                end
            ]],
        })
        box.schema.func.create('__stop_messages_stream', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    local messages_stream_data = rawget(_G, '__start_messages_stream_data')
                    if messages_stream_data == nil then
                        return
                    end
                    messages_stream_data.stop_ch:put(true)
                    return
                end
            ]],
        })
    end
    return true
end

return {
    up = up,
}
