local helpers = require('tt-migrations.helpers')

local function apply()
    local accounts = box.schema.space.create('accounts', {
        if_not_exists = true,
        format = {
            {name = 'client_id', type = 'unsigned'},
            {name = 'account_type', type = 'string'},
            {name = 'bucket_id', type = 'unsigned'},
            {name = 'balance', type = 'unsigned'},
        },
    })
    accounts:create_index('primary', {
        parts = {'client_id', 'account_type'}, if_not_exists = true,
    })
    accounts:create_index('bucket_id', {
        parts = {'bucket_id'}, unique = false, if_not_exists = true,
    })
    helpers.register_sharding_key('accounts', {'client_id'})

    local transfers = box.schema.space.create('transfers', {
        if_not_exists = true,
        format = {
            {name = 'txn_id', type = 'unsigned'},
            {name = 'client_id', type = 'unsigned'},
            {name = 'bucket_id', type = 'unsigned'},
            {name = 'from_account', type = 'string'},
            {name = 'to_account', type = 'string'},
            {name = 'amount', type = 'unsigned'},
            {name = 'created_at', type = 'unsigned'},
        },
    })
    transfers:create_index('primary', {
        parts = {'txn_id'}, if_not_exists = true,
    })
    transfers:create_index('bucket_id', {
        parts = {'bucket_id'}, unique = false, if_not_exists = true,
    })
    helpers.register_sharding_key('transfers', {'client_id'})

    return true
end

return {
    apply = {
        scenario = apply,
    },
}
