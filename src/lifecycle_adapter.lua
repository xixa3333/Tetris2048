local LifecycleAdapter={}; LifecycleAdapter.__index=LifecycleAdapter
function LifecycleAdapter.new(runtime,app) return setmetatable({runtime=runtime,app=app,listener=nil},LifecycleAdapter) end
function LifecycleAdapter:start()
    if self.listener then return end
    self.listener=function(event)
        if event.type=="applicationSuspend" then self.app:onSuspend()
        elseif event.type=="applicationResume" then self.app:onResume() end
        return false
    end
    self.runtime:addEventListener("system",self.listener)
end
function LifecycleAdapter:stop()
    if self.listener then self.runtime:removeEventListener("system",self.listener); self.listener=nil end
end
return LifecycleAdapter
