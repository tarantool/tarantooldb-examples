local helpers = require('tt-migrations.helpers')

local function up()

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

    return true
end

return {
    up = {
        scenario = up,
    },
}
