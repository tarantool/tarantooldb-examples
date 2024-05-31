local fio = require('fio')
local yaml = require('yaml').new()

yaml.cfg({
    encode_use_tostring = true,
    encode_load_metatables = false,
    decode_save_metatables = false,
})

local function read_file(path_to_file)
    local file, err = fio.open(path_to_file, {'O_RDONLY'})
    if err ~= nil then
        error(('Failed to read file %s: %s'):format(path_to_file, err))
    end

    local data = file:read()
    file:close()

    return data
end

local function write_file(path_to_file, data)
    local file, err = fio.open(path_to_file, {'O_CREAT', 'O_WRONLY', 'O_TRUNC'}, tonumber(666, 8))
    if err ~= nil then
        error(('Failed to write file %s: %s'):format(path_to_file, err))
    end

    local result = file:write(data)
    file:close()

    return result
end

local file_str = read_file('config.yml')
local cfg = yaml.decode(file_str)

cfg.config = nil

file_str = yaml.encode(cfg)
write_file('config.tcm.yml', file_str)

print('config.tcm.yml - created')
