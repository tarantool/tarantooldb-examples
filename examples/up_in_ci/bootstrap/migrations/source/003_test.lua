local function apply()
    box.schema.user.create("example_user", { password = "example_password", if_not_exists = true })
    box.schema.user.grant('example_user', 'read, write, execute', 'universe', nil, { if_not_exists = true })

    return true
end

return {
    apply = {
        scenario = apply,
    }
}
