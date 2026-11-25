local helpers = require('tt-migrations.helpers')

local function apply()
    -- Счета клиентов. Спейс создан с is_sync = true: транзакции, затрагивающие
    -- accounts, подтверждаются кворумом реплик набора. Это предусловие гарантии
    -- идемпотентности при смене мастера (см. раздел «Поведение при смене
    -- мастера» в README примера).
    local accounts = box.schema.space.create('accounts', {
        if_not_exists = true,
        is_sync = true,
        format = {
            {name = 'account_id', type = 'unsigned'},
            {name = 'bucket_id', type = 'unsigned'},
            {name = 'balance', type = 'unsigned'},
        },
    })
    accounts:create_index('primary', {
        parts = {'account_id'}, if_not_exists = true,
    })
    accounts:create_index('bucket_id', {
        parts = {'bucket_id'}, unique = false, if_not_exists = true,
    })
    helpers.register_sharding_key('accounts', {'account_id'})

    -- Заказы с внешним идентификатором (external_id). Первичный ключ
    -- order_id не связан с внешним идентификатором: без идемпотентности
    -- повторная вставка создает дубль с новым order_id, а с параметром
    -- idempotency отклоняется. Ключ шардирования — external_id: ретрай
    -- операции с тем же внешним идентификатором попадает в тот же сегмент
    -- (бакет), где его находит маркер идемпотентности — состояние
    -- идемпотентности ведется в пределах пары (key, bucket_id).
    local orders = box.schema.space.create('orders', {
        if_not_exists = true,
        is_sync = true,
        format = {
            {name = 'order_id', type = 'unsigned'},
            {name = 'external_id', type = 'string'},
            {name = 'bucket_id', type = 'unsigned'},
            {name = 'amount', type = 'unsigned'},
            {name = 'created_at', type = 'unsigned'},
        },
    })
    orders:create_index('primary', {
        parts = {'order_id'}, if_not_exists = true,
    })
    orders:create_index('bucket_id', {
        parts = {'bucket_id'}, unique = false, if_not_exists = true,
    })
    helpers.register_sharding_key('orders', {'external_id'})

    -- Хранимая функция для раздела «Идемпотентность в хранимой процедуре»:
    -- списание с баланса внутри транзакции, дедуплицируемой маркером
    -- crud.idempotency.mark. Функция выполняется на хранилище — владельце
    -- сегмента данных (бакета) — при вызове через crud.storage_call.
    box.schema.func.create('app.process_payment', {
        language = 'LUA',
        is_sandboxed = false,
        setuid = false,
        if_not_exists = true,
        body = [[
            function(account_id, amount, idem)
                local account = box.space.accounts:get({account_id})
                if account == nil then
                    error(('Account %d not found'):format(account_id))
                end
                return box.atomic(function()
                    -- Проверка и запись маркера идемпотентности — в той же
                    -- транзакции, что и изменение баланса: применяются
                    -- обе записи либо ни одна.
                    local _, err = crud.idempotency.mark({
                        key = idem.key,
                        seq = idem.seq,
                        ttl = idem.ttl,
                        bucket_id = account.bucket_id,
                        engine = 'memtx',
                    })
                    if err ~= nil then
                        -- Повтор, отставание или смена режима ключа —
                        -- откат транзакции целиком, баланс не меняется.
                        error(err)
                    end
                    local updated = box.space.accounts:update(
                        {account_id}, {{'+', 'balance', amount}})
                    return updated.balance
                end)
            end
        ]],
    })

    return true
end

return {
    apply = {
        scenario = apply,
    },
}
