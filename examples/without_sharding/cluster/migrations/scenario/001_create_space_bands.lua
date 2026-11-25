local function apply()
    local space_bands = box.schema.space.create('bands', {
        if_not_exists = true,
        format = {
            { name = 'id', type = 'integer' },
            { name = 'band_name', type = 'string' },
            { name = 'year', type = 'integer' },
        },
    })
    space_bands:create_index('primary_key', { parts = {'id'}, if_not_exists = true })

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
