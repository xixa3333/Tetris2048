-- Firebase 設定載入。
-- 打包後的 app 可以用 require 取得 `firebase_config.local`，但模擬器是用檔案系統
-- 解析模組名稱，require("a.b") 會去找 a/b.lua，含點的檔名永遠找不到，
-- 因此這裡再補一層 loadfile。最後一定要有可用的預設值，設定檔缺漏時
-- 只會讓登入與全球排行榜失效，不能讓整個 APP 開不起來。
local ConfigLoader = {}

local FALLBACK = {
    projectId = "YOUR_FIREBASE_PROJECT_ID",
    apiKey = "YOUR_FIREBASE_WEB_API_KEY",
    appId = "YOUR_FIREBASE_WEB_APP_ID"
}

local function loadModule(name)
    local ok, value = pcall(require, name)
    if ok and type(value) == "table" then return value end
    return nil
end

local function loadFile(filename)
    if type(system) ~= "table" or type(system.pathForFile) ~= "function" then return nil end
    local ok, path = pcall(system.pathForFile, filename, system.ResourceDirectory)
    if not ok or not path then return nil end
    local chunk = loadfile(path)
    if not chunk then return nil end
    local loaded, value = pcall(chunk)
    if loaded and type(value) == "table" then return value end
    return nil
end

function ConfigLoader.load()
    return loadModule("firebase_config.local")
        or loadFile("firebase_config.local.lua")
        or loadModule("firebase_config.example")
        or loadFile("firebase_config.example.lua")
        or FALLBACK
end

return ConfigLoader
