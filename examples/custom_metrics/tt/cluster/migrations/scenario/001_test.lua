local helpers = require('tt-migrations.helpers')
local uuid = require('uuid')
local fiber = require('fiber')
local metrics = require('metrics')

math.randomseed(os.time())

-- Функция для генерации случайного числа от 1 до 10
local function generate_random_count()
    return math.random(1, 10)
end

-- Функция для генерации и вставки
function generate_inset(space)
    local user_uuid = uuid.str() -- Генерация случайного UUID
    local bucket_id = generate_random_count()
    local count = generate_random_count()

    space:insert{user_uuid, bucket_id, count, foo}
    local test_insert_count = metrics.counter('test_insert_count', 'The number of data operations')
    test_insert_count:inc(count, { request_type = request_type })
end

-- Функция для запуска задачи каждые 5 секунд
function start_periodic_task(space)
    fiber.create(function()
        while true do
            generate_inset(space)
            fiber.sleep(5) -- Пауза на 5 секунд
        end
    end)
end

local function apply()
    local test = box.schema.space.create('test', { if_not_exists = true })
    test:format({
        { name = 'uuid', type = 'string' },
        { name = 'bucket_id', type = 'unsigned' },
        { name = 'count', type = 'number' },
    })
    test:create_index('pk', { parts = {'uuid'}, if_not_exists = true })
    test:create_index('bucket_id', { parts = {'bucket_id'}, unique = false, if_not_exists = true})

    helpers.register_sharding_key('async_space', {'uuid'})

    start_periodic_task(test)
    return true
end

return {
    apply = {
        scenario = apply,
    }
}
