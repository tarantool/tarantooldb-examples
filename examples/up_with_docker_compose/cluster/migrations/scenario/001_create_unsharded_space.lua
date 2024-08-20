local function apply()
    box.schema.space.create('test1', {if_not_exists = true})
    box.space.test1:format({
        { name = 'id', type = 'number' },
        { name = 'too', type = 'number' },
        { name = 'foo', type = 'string' },
    })
    box.space.test1:create_index('pk', { parts = {'id'}, if_not_exists = true})
end

return {
    apply = {
        scenario = apply,
    }
}
