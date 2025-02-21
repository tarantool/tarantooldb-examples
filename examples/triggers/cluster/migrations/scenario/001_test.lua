local function apply()
    local s = box.schema.space.create('my_space', {
        if_not_exists = true,
        format = {
            { name = 'id', type = 'number' },
            { name = 'dt', type = 'datetime' },
            { name = 'data', type = 'string' },
        },
    })

    s:create_index('pk', { parts = {'id'} })

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
