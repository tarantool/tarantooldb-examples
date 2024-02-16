local function up()
    box.schema.space.create('test', {if_not_exists = true})
    box.space.test:format({
        { name = 'id', type = 'number' },
        { name = 'too', type = 'number' },
        { name = 'foo', type = 'string' },
    })
    box.space.test:create_index('pk', { parts = {'id'}, if_not_exists = true })

    return true
end

return {
    up = up,
}
