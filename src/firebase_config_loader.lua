local ConfigLoader = {}

local function loadModule(name)
    local ok, value = pcall(require, name)
    if ok then return value end
    return nil
end

function ConfigLoader.load()
    local localConfig = loadModule("firebase_config.local")
    if localConfig then return localConfig end
    return require("firebase_config.example")
end

return ConfigLoader
