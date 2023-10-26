local function up()
    box.schema.space.create('test2', {if_not_exists = true})
    box.space.test2:format({
        { name = 'id', type = 'integer' },
        { name = 'bar', type = 'integer' },
        { name = 'baz', type = 'string' },
    })
    box.space.test2:create_index('pk', { parts = {'id'}, if_not_exists = true})

    return true
end

return {
    up = up,
}
