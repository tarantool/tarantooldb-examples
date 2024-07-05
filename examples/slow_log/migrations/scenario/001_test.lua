local helpers = require('tt-migrations.helpers')

local function up()
        box.schema.space.create('data', {if_not_exists = true})
        box.space.data:format({
            { name = 'id', type = 'number' },
            { name = 'bucket_id', type = 'unsigned' },
            { name = 'data', type = 'any' },
        })
        box.space.data:create_index('pk', { parts = {'id'}, if_not_exists = true})
        box.space.data:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})
    
        helpers.register_sharding_key('data', {'id'})

    box.schema.func.create('app.wait_for',  {
        language = 'LUA',
        if_not_exists = true,
        body = [[
            function(sleep_time)
                local log = require('log')
                local fiber = require('fiber')
                log.info("start wait_for " .. sleep_time)
                fiber.sleep(sleep_time)
                log.info("stop wait_for " .. sleep_time)
            end
        ]],
    })

    return true
end

return {
    up = {
        scenario = up,
    },
}
