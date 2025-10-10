local function apply()
    box.snapshot()
    box.schema.upgrade()
    box.snapshot()
end

return {
    apply = {
        scenario = apply,
    }
}
