local T=require("test_helper")
local SettingsService=require("settings_service")

local function storage(value)
    return {value=value or {},load=function(self) return self.value end,save=function(self,data) self.value=data end}
end
T.test("Settings normalize, clamp and persist volume percentages and seed",function()
    local raw=storage({backgroundVolume=-5,effectVolume=140,seed="  repeat-me  "})
    local settings=SettingsService.new(raw); local value=settings:get()
    T.equal(value.backgroundVolume,0); T.equal(value.effectVolume,100); T.equal(value.seed,"repeat-me")
    settings:update({backgroundVolume=33.6,effectVolume="20",seed=string.rep("x",80),backgroundTrack="BackGround_02_Test.mp3"})
    T.equal(raw.value.backgroundVolume,34); T.equal(raw.value.effectVolume,20); T.equal(#raw.value.seed,64)
    T.equal(raw.value.backgroundTrack,"BackGround_02_Test.mp3")
end)
T.test("Settings reject malformed local data and notify subscribers",function()
    local raw=storage("corrupt"); local settings=SettingsService.new(raw); local observed
    settings:subscribe(function(value) observed=value end)
    settings:update({backgroundVolume="bad",effectVolume=nil,seed=nil})
    T.equal(observed.backgroundVolume,15); T.equal(observed.effectVolume,40); T.equal(observed.seed,"")
end)

T.test("Preview applies live without saving and revert restores the stored settings",function()
    local storage={data={backgroundVolume=15,effectVolume=40,seed="",backgroundTrack="A.mp3"},writes=0}
    function storage:load() return self.data end
    function storage:save(data) self.writes=self.writes+1; self.data=data end
    local settings=SettingsService.new(storage)
    local seen={}
    settings:subscribe(function(value) seen[#seen+1]=value.backgroundVolume end)

    settings:preview({backgroundVolume=80,effectVolume=90,seed="",backgroundTrack="B.mp3"})
    T.equal(settings:get().backgroundVolume,80); T.equal(settings:get().backgroundTrack,"B.mp3")
    T.equal(seen[1],80); T.equal(storage.writes,0)
    T.equal(settings:isPreviewing(),true)

    settings:revert()
    T.equal(settings:get().backgroundVolume,15); T.equal(settings:get().backgroundTrack,"A.mp3")
    T.equal(seen[2],15); T.equal(storage.writes,0); T.equal(settings:isPreviewing(),false)
end)

T.test("Saving a preview makes it the new restore point",function()
    local storage={data={},writes=0}
    function storage:load() return self.data end
    function storage:save(data) self.writes=self.writes+1; self.data=data end
    local settings=SettingsService.new(storage)
    settings:preview({backgroundVolume=70,effectVolume=20,seed="abc",backgroundTrack="B.mp3"})
    settings:update({backgroundVolume=70,effectVolume=20,seed="abc",backgroundTrack="B.mp3"})
    T.equal(storage.writes,1); T.equal(settings:isPreviewing(),false)
    settings:revert()
    T.equal(settings:get().backgroundVolume,70); T.equal(settings:get().seed,"abc")
    T.equal(storage.writes,1)
end)

T.test("Revert without changes neither notifies listeners nor writes storage",function()
    local storage={data={backgroundVolume=15},writes=0}
    function storage:load() return self.data end
    function storage:save(data) self.writes=self.writes+1; self.data=data end
    local settings=SettingsService.new(storage)
    local notifications=0
    settings:subscribe(function() notifications=notifications+1 end)
    settings:preview(settings:get())
    settings:revert()
    T.equal(notifications,1); T.equal(storage.writes,0)
end)
