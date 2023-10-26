local function up()
    box.schema.space.create('test1', {if_not_exists = true})
    box.space.test1:format({
        { name = 'id', type = 'integer' },
        { name = 'too', type = 'integer' },
        { name = 'foo', type = 'string' },
    })
    box.space.test1:create_index('pk', { parts = {'id'}, if_not_exists = true})

    return true
end

return {
    up = up,
}
