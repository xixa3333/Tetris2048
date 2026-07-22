local T=require("test_helper")
local LifecycleAdapter=require("lifecycle_adapter")
T.test("Lifecycle forwards suspend and resume and unregisters cleanly",function()
    local runtime={}; function runtime:addEventListener(_,listener) self.listener=listener end
    function runtime:removeEventListener() self.listener=nil end
    local app={suspends=0,resumes=0}; function app:onSuspend() self.suspends=self.suspends+1 end
    function app:onResume() self.resumes=self.resumes+1 end
    local adapter=LifecycleAdapter.new(runtime,app); adapter:start()
    runtime.listener({type="applicationSuspend"}); runtime.listener({type="applicationResume"})
    T.equal(app.suspends,1); T.equal(app.resumes,1); adapter:stop(); T.equal(runtime.listener,nil)
end)
