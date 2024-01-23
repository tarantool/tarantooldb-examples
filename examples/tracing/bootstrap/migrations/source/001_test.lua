local cartridge_api_topology = require('cartridge.lua-api.get-topology')

local function is_router()
    local roles = cartridge_api_topology.get_enabled_roles_without_deps()
    for _, rname in pairs(roles) do
        if rname == 'crud-router' then
            return true
        end
    end

    return false
end

local function is_storage()
    local roles = cartridge_api_topology.get_enabled_roles_without_deps()
    for _, rname in pairs(roles) do
        if rname == 'crud-storage' then
            return true
        end
    end

    return false
end

local function up()
    if is_router() then
        box.schema.func.create('get_token',  {
            language = 'LUA',
            body = [[
                function (param)
                    local vshard = require('vshard')
                    local tracing = require('app.roles.tracing')

                    local context = {}
                    local span = tracing.start_span(context, 'get_token_router')

                    local bucket_id = vshard.router.bucket_id_mpcrc32(param)
                    local _, err = vshard.router.callrw(bucket_id, 'get_token', {context, param}, {})

                    span:finish({error = err})
                end
            ]],
        })
        box.schema.func.create('debug_func',  {
            language = 'LUA',
            body = [[
                function (trace_name)
                    local tracing = require('app.roles.tracing')
                    local fiber = require('fiber')

                    local span = tracing.start_span({}, trace_name)
                    fiber.sleep(0.1)
                    span:finish()
                end
            ]],
        })
    end

    if is_storage() then
        box.schema.func.create('get_token',  {
            language = 'LUA',
            body = [[
                function (context, param)
                    local tracing = require('app.roles.tracing')
                    local fiber = require('fiber')

                    local span = tracing.start_span(context, 'get_token_storage')
                    fiber.sleep(0.01)
                    span:finish()
                end
            ]],
        })
    end

    return true
end

return {
    up = up,
}
