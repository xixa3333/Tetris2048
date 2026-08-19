local T=require("test_helper")
local ConfigLoader=require("firebase_config_loader")

T.test("Firebase config loading never stops the APP from starting",function()
    local config=ConfigLoader.load()
    T.equal(type(config),"table")
    for _,key in ipairs({"projectId","apiKey","appId"}) do
        T.equal(type(config[key]),"string","missing config key: "..key)
        T.truthy(#config[key]>0)
    end
end)

T.test("Firebase config reads dotted filenames the simulator cannot require",function()
    T.equal(ConfigLoader.load().projectId,"YOUR_FIREBASE_PROJECT_ID")
    local originalSystem,originalLoadfile=system,loadfile
    local requested={}
    system={ResourceDirectory="resource",pathForFile=function(name)
        requested[#requested+1]=name
        if name=="firebase_config.local.lua" then return "resource/firebase_config.local.lua" end
        return nil
    end}
    loadfile=function(path)
        if path=="resource/firebase_config.local.lua" then
            return function() return {projectId="real-project",apiKey="real-key",appId="real-app"} end
        end
        return nil
    end
    local loaded=ConfigLoader.load()
    system,loadfile=originalSystem,originalLoadfile
    T.equal(loaded.projectId,"real-project"); T.equal(loaded.apiKey,"real-key")
    T.equal(requested[1],"firebase_config.local.lua")
end)

T.test("A broken configuration file falls back instead of crashing the APP",function()
    local originalSystem,originalLoadfile=system,loadfile
    system={ResourceDirectory="resource",pathForFile=function(name) return "resource/"..name end}
    loadfile=function() return function() error("corrupted config") end end
    local loaded=ConfigLoader.load()
    system,loadfile=originalSystem,originalLoadfile
    T.equal(type(loaded),"table"); T.equal(loaded.projectId,"YOUR_FIREBASE_PROJECT_ID")
end)
