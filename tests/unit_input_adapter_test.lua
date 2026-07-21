local T=require("test_helper")
local InputAdapter=require("input_adapter")

T.test("Swipe maps four phone gestures to WASD directions",function()
    T.equal(InputAdapter.directionForSwipe(100,100,100,20),"up")
    T.equal(InputAdapter.directionForSwipe(100,100,100,180),"down")
    T.equal(InputAdapter.directionForSwipe(100,100,20,100),"left")
    T.equal(InputAdapter.directionForSwipe(100,100,180,100),"right")
end)

T.test("Swipe ignores taps and chooses the dominant axis",function()
    T.equal(InputAdapter.directionForSwipe(100,100,110,115,40),nil)
    T.equal(InputAdapter.directionForSwipe(100,100,170,130,40),"right")
    T.equal(InputAdapter.directionForSwipe(100,100,130,20,40),"up")
end)

T.test("Input adapter registers and removes keyboard and touch listeners",function()
    local runtime={listeners={}}
    function runtime:addEventListener(name,listener) self.listeners[name]=listener end
    function runtime:removeEventListener(name) self.listeners[name]=nil end
    local commands={}; local input=InputAdapter.new(runtime,40)
    input:start(function(command) commands[#commands+1]=command end)
    runtime.listeners.key({phase="down",keyName="w"})
    runtime.listeners.touch({phase="began",id=1,x=100,y=100})
    runtime.listeners.touch({phase="ended",id=1,x=20,y=100})
    T.equal(commands[1],"up"); T.equal(commands[2],"left")
    input:stop(); T.equal(runtime.listeners.key,nil); T.equal(runtime.listeners.touch,nil)
end)
