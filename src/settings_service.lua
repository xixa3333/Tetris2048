-- Persistent, UI-independent settings with one normalized data contract.
local SettingsService={}; SettingsService.__index=SettingsService
local DEFAULTS={backgroundVolume=15,effectVolume=40,seed=""}

local function clampPercent(value,fallback)
    local number=tonumber(value)
    if not number then return fallback end
    return math.max(0,math.min(100,math.floor(number+0.5)))
end
local function normalizeSeed(value)
    local seed=tostring(value or ""):match("^%s*(.-)%s*$")
    return seed:sub(1,64)
end

function SettingsService.normalize(value)
    value=type(value)=="table" and value or {}
    return {backgroundVolume=clampPercent(value.backgroundVolume,DEFAULTS.backgroundVolume),
        effectVolume=clampPercent(value.effectVolume,DEFAULTS.effectVolume),seed=normalizeSeed(value.seed)}
end
function SettingsService.new(storage)
    local self=setmetatable({storage=assert(storage),listeners={}},SettingsService)
    self.value=SettingsService.normalize(storage:load()); return self
end
function SettingsService:get()
    return {backgroundVolume=self.value.backgroundVolume,effectVolume=self.value.effectVolume,seed=self.value.seed}
end
function SettingsService:update(value)
    self.value=SettingsService.normalize(value); self.storage:save(self.value)
    for _,listener in ipairs(self.listeners) do listener(self:get()) end
    return self:get()
end
function SettingsService:subscribe(listener)
    self.listeners[#self.listeners+1]=listener
end
return SettingsService
