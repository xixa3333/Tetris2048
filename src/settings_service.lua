-- Persistent, UI-independent settings with one normalized data contract.
-- 設定頁支援即時預覽：preview 只套用到執行中的服務，update 才寫入儲存，
-- 沒有儲存就離開設定頁時由 revert 還原成最後一次儲存的值。
local SettingsService={}; SettingsService.__index=SettingsService
local DEFAULTS={backgroundVolume=15,effectVolume=40,seed="",backgroundTrack=""}

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
        effectVolume=clampPercent(value.effectVolume,DEFAULTS.effectVolume),seed=normalizeSeed(value.seed),
        backgroundTrack=tostring(value.backgroundTrack or DEFAULTS.backgroundTrack)}
end
function SettingsService.new(storage)
    local self=setmetatable({storage=assert(storage),listeners={}},SettingsService)
    self.value=SettingsService.normalize(storage:load())
    self.saved=SettingsService.normalize(self.value)
    return self
end
function SettingsService:get()
    return {backgroundVolume=self.value.backgroundVolume,effectVolume=self.value.effectVolume,
        seed=self.value.seed,backgroundTrack=self.value.backgroundTrack}
end
function SettingsService:_apply(value)
    self.value=SettingsService.normalize(value)
    for _,listener in ipairs(self.listeners) do listener(self:get()) end
    return self:get()
end
-- 即時預覽：立刻讓音樂與音量跟著改變，但不寫入儲存。
function SettingsService:preview(value) return self:_apply(value) end
function SettingsService:update(value)
    local applied=self:_apply(value)
    self.saved=SettingsService.normalize(self.value)
    self.storage:save(self.value)
    return applied
end
function SettingsService:isPreviewing()
    for key,value in pairs(self.saved) do
        if self.value[key]~=value then return true end
    end
    return false
end
function SettingsService:revert()
    if self:isPreviewing() then self:_apply(self.saved) end
    return self:get()
end
function SettingsService:subscribe(listener)
    self.listeners[#self.listeners+1]=listener
end
return SettingsService
