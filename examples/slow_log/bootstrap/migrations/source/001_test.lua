local fiber = require('fiber')
local log = require('log')
local utils = require('migrator.utils')

local function wait_for(sleep_time)
    log.info("start wait_for " .. sleep_time)
    fiber.sleep(sleep_time)
    log.info("stop wait_for " .. sleep_time)
end

local app = {
    wait_for = wait_for
}

local function up()
    box.schema.space.create('data', {if_not_exists = true})
    box.space.data:format({
        { name = 'id', type = 'number' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'data', type = 'any' },
    })
    box.space.data:create_index('pk', { parts = {'id'}, if_not_exists = true})
    box.space.data:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    utils.register_sharding_key('data', {'id'})
    
    rawset(_G, 'app', app)
    return true
end

return {
    up = up,
}
