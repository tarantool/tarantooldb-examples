local helpers = require('tt-migrations.helpers')

local function apply()
    local accounts = box.schema.space.create('accounts', {
        if_not_exists = true,
        format = {
            {name = 'id', type = 'unsigned'},
            {name = 'bucket_id', type = 'unsigned'},
            {name = 'balance', type = 'integer'},
        },
    })
    accounts:create_index('primary', {
        parts = {'id'}, if_not_exists = true,
    })
    accounts:create_index('bucket_id', {
        parts = {'bucket_id'}, unique = false, if_not_exists = true,
    })
    helpers.register_sharding_key('accounts', {'id'})

    box.schema.func.create('app.get_balance', {
        language = 'LUA',
        is_sandboxed = false,
        setuid = false,
        if_not_exists = true,
        body = [[
            function(account_id)
                local account = box.space.accounts:get({account_id})
                if account == nil then
                    return nil
                end
                return account.balance
            end
        ]],
    })

    box.schema.func.create('app.credit_account', {
        language = 'LUA',
        is_sandboxed = false,
        setuid = false,
        if_not_exists = true,
        body = [[
            function(account_id, amount)
                if type(amount) ~= 'number' or amount <= 0 then
                    error('amount must be positive')
                end

                return box.atomic(function()
                    local account = box.space.accounts:get({account_id})
                    if account == nil then
                        error(('Account %d not found'):format(account_id))
                    end

                    local updated = box.space.accounts:update(
                        {account_id}, {{'+', 'balance', amount}}
                    )
                    return updated.balance
                end)
            end
        ]],
    })

    box.schema.user.grant('storage_call_reader', 'read', 'space',
        'accounts', {if_not_exists = true})
    box.schema.user.grant('storage_call_reader', 'execute', 'function',
        'app.get_balance', {if_not_exists = true})
    if box.space._bucket ~= nil then
        box.schema.user.grant('storage_call_reader', 'read', 'space',
            '_bucket', {if_not_exists = true})
    end

    return true
end

return {
    apply = {
        scenario = apply,
    },
}
