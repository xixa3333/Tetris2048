local T=require("test_helper")
local SettingsService=require("settings_service")

local function storage(value)
    return {value=value or {},load=function(self) return self.value end,save=function(self,data) self.value=data end}
end
T.test("Settings normalize, clamp and persist volume percentages and seed",function()
    local raw=storage({backgroundVolume=-5,effectVolume=140,seed="  repeat-me  "})
    local settings=SettingsService.new(raw); local value=settings:get()
    T.equal(value.backgroundVolume,0); T.equal(value.effectVolume,100); T.equal(value.seed,"repeat-me")
    settings:update({backgroundVolume=33.6,effectVolume="20",seed=string.rep("x",80)})
    T.equal(raw.value.backgroundVolume,34); T.equal(raw.value.effectVolume,20); T.equal(#raw.value.seed,64)
end)
T.test("Settings reject malformed local data and notify subscribers",function()
    local raw=storage("corrupt"); local settings=SettingsService.new(raw); local observed
    settings:subscribe(function(value) observed=value end)
    settings:update({backgroundVolume="bad",effectVolume=nil,seed=nil})
    T.equal(observed.backgroundVolume,15); T.equal(observed.effectVolume,40); T.equal(observed.seed,"")
end)
