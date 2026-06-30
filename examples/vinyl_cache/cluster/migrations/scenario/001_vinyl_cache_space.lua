local function apply()
    box.schema.space.create('data', { engine = 'vinyl', if_not_exists = true })
    box.space.data:format({
        { name = 'id', type = 'unsigned' },
        { name = 'payload', type = 'string' },
    })
    box.space.data:create_index('pk', { parts = { 'id' }, if_not_exists = true })

    -- Вспомогательные функции для демонстрации работы кэша.
    -- Используются в консоли: box.func.fill_data:call(), box.func.bench_hot:call(), box.func.bench_scattered:call()

    box.schema.func.create('fill_data', {
        language = 'LUA',
        body = [=[function()
            local s = box.space.data
            for i = 1, 200000, 10000 do
                box.begin()
                for j = i, math.min(i + 9999, 200000) do
                    s:replace{ j, string.rep('x', 200) }
                end
                box.commit()
            end
        end]=],
        if_not_exists = true,
    })

    box.schema.func.create('bench_hot', {
        language = 'LUA',
        body = [=[function()
            local clock = require('clock')
            local s = box.space.data
            local idx = s.index.pk
            local before = idx:stat()
            local t = clock.bench(function()
                for pass = 1, 10 do
                    for i = 1, 5000 do s:get(i) end
                end
            end)[1]
            local after = idx:stat()
            local hit = after.cache.get.rows - before.cache.get.rows
            local total = after.get.rows - before.get.rows
            return string.format('time=%.3fs  hit=%d  miss=%d  ratio=%.2f',
                t, hit, total - hit, hit / total)
        end]=],
        if_not_exists = true,
    })

    box.schema.func.create('bench_scattered', {
        language = 'LUA',
        body = [=[function()
            local clock = require('clock')
            local s = box.space.data
            local idx = s.index.pk
            math.randomseed(42)
            local before = idx:stat()
            local t = clock.bench(function()
                for i = 1, 50000 do s:get(math.random(1, 200000)) end
            end)[1]
            local after = idx:stat()
            local hit = after.cache.get.rows - before.cache.get.rows
            local total = after.get.rows - before.get.rows
            return string.format('time=%.3fs  hit=%d  miss=%d  ratio=%.2f',
                t, hit, total - hit, hit / total)
        end]=],
        if_not_exists = true,
    })
end

return {
    apply = {
        scenario = apply,
    }
}
