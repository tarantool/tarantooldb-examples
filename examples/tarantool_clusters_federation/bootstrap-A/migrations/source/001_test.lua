local utils = require('migrator.utils')

local function is_router()
    return utils.check_roles_enabled({'crud-router'})
end

local function is_storage()
    return utils.check_roles_enabled({'crud-storage'})
end

local function apply()
    if is_router() then
        box.schema.func.create('__start_data_stream', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    if rawget(_G, '__stream_data') ~= nil then
                        return
                    end

                    local fiber = require('fiber')
                    local ch = fiber.channel()
                    local datetime = require('datetime')
                    local count = 1

                    local stream_fiber = fiber.create(function()
                        while true do
                            local is_stop = ch:get(0)
                            if is_stop then
                                break
                            end
                            fiber.sleep(0.1)
                            count = count + 1
                            crud.replace('test', {count})
                        end
                    end)
                    stream_fiber:name('stream_fiber')
                    rawset(_G, '__stream_data', {
                        stop_ch = ch,
                        fiber = stream_fiber,
                    })
                end
            ]],
        })
        box.schema.func.create('__stop_data_stream', {
            language = 'LUA',
            if_not_exists = true,
            body = [[
                function()
                    local stream_data = rawget(_G, '__stream_data')
                    if stream_data == nil then
                        return
                    end
                    stream_data.stop_ch:put(true)
                    rawset(_G, '__stream_data', nil)
                    return
                end
            ]],
        })
    end
    if is_storage() then
        box.schema.space.create('test', {if_not_exists = true})
        box.space.test:format({
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
        })
        box.space.test:create_index('pk', { parts = {'id'}, if_not_exists = true})
        box.space.test:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

        utils.register_sharding_key('test', {'id'})
    end
    return true
end

return {
    apply = {
        scenario = apply,
    }
}
