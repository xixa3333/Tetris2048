local json = require("json")

local JsonStorage = {}
JsonStorage.__index = JsonStorage

function JsonStorage.new(filename)
    return setmetatable({filename = filename or "leaderboard.json"}, JsonStorage)
end

function JsonStorage:load()
    local path = system.pathForFile(self.filename, system.DocumentsDirectory)
    local file = path and io.open(path, "r")
    if not file then return {} end
    local text = file:read("*a")
    file:close()
    local ok, data = pcall(json.decode, text)
    return ok and type(data) == "table" and data or {}
end

function JsonStorage:save(data)
    local path = system.pathForFile(self.filename, system.DocumentsDirectory)
    local file = assert(io.open(path, "w"))
    file:write(json.encode(data))
    file:close()
end

return JsonStorage
