local helpers = require('tt-migrations.helpers')

local function apply()

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

    box.schema.func.create('get_name_by_uri', {
        language = 'LUA',
        if_not_exists = true,
        body = [[
            function(uri)
                local net_box = require('net.box')

                local conn = net_box.connect({
                    uri = uri,
                    params = {
                        transport = 'ssl',
                        ssl_cert_file='/tmp/certs/client-cert.pem',
                        ssl_key_file='/tmp/certs/client-key.pem'
                    }
                })

                return conn:eval('return box.info().name')
            end
        ]]
    })

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
