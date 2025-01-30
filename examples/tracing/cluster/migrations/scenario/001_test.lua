local rconfig = require('config')

local function has_a_tag(tag_name)
    local labels = rconfig:get().labels

    return labels.tag == tag_name
end

local function apply()
    if has_a_tag('api') then
        box.schema.func.create('get_token',  {
            language = 'LUA',
            body = [[
                function (param)
                    local pool = require('experimental.connpool')
                    local tracing = require('app.roles.tracing')

                    local context = {}
                    local span = tracing.start_span(context, 'get_token_api')

                    local _, err = pool.call('get_token', {context, param}, {
                        labels = {
                            tag='worker',
                        },
                    })

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

    if has_a_tag('worker') then
        box.schema.func.create('get_token',  {
            language = 'LUA',
            body = [[
                function (context, param)
                    local tracing = require('app.roles.tracing')
                    local fiber = require('fiber')

                    local span = tracing.start_span(context, 'get_token_worker')
                    fiber.sleep(0.01)
                    span:finish()
                end
            ]],
        })
    end

    return true
end


return {
    apply = {
        scenario = apply,
    },
}
