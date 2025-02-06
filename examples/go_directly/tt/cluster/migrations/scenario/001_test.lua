local function apply()
    local s = box.schema.space.create('test', {
        if_not_exists = true,
        format = {
            { name = 'id', type = 'number' },
            { name = 'too', type = 'number' },
            { name = 'foo', type = 'string' },
        },
    })
    s:create_index('pk', { parts = {'id'}, if_not_exists = true })

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
