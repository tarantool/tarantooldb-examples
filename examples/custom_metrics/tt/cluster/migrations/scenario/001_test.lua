local helpers = require('tt-migrations.helpers')

local function apply()
    lua_code = [[
    function()
        -- Проверить, была ли переменная уже инициализирована
        if _G.test_insert_count == nil then
            -- Инициализировать переменную нужно только один раз
            _G.test_insert_count = require('metrics').counter('test_insert_count', 'The number of data operations')
        end

        -- Функция для генерации метрики
        local function update_metric(counter)
            -- Здесь происходит обновление значения метрики. Каждая пара время-значение сопровождается
            -- меткой. В качестве метки выступает структура с произвольными пользовательскими
            -- данными, необходимыми для построения нужных графиков. К такой структуре применяется следующее условие:
            -- количество вариантов значений внутри нее должно быть ограничено, чтобы не
            -- перегрузить БД, собирающую метрики (как правило, это одна из Time Series баз данных).

            local label_pairs = {
                request_type = 'default',
            }
            counter:inc(1, label_pairs) -- Увеличить значение счётчика на единицу и одновременно подписать
                                        -- новую пару время-значение
        end

        -- Вызвать функцию генерации метрики
        update_metric(_G.test_insert_count)
    end
    ]]

    box.schema.func.create('counter_task', {
        body = lua_code,
        language = 'LUA',
        if_not_exists = true
    })
    return true
end

return {
    apply = {
        scenario = apply,
    }
}
