local function apply()
    box.schema.upgrade()
    return true
end

return {
    apply = {
        scenario = apply,
    }
}
