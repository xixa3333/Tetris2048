-- 將鍵盤與手機滑動統一轉成遊戲命令。此模組不持有遊戲狀態，
-- 畫面切換時只需 start/stop 即可避免輸入洩漏到其他頁面。
local InputAdapter = {}
InputAdapter.__index = InputAdapter

local KEY_COMMANDS = {
    w="up", s="down", a="left", d="right", r="rotate", space="reserve",
    up="up", down="down", left="left", right="right"
}

function InputAdapter.directionForSwipe(startX, startY, endX, endY, threshold)
    local dx, dy = endX-startX, endY-startY
    threshold = threshold or 40
    if math.max(math.abs(dx), math.abs(dy)) < threshold then return nil end
    if math.abs(dx) > math.abs(dy) then return dx > 0 and "right" or "left" end
    return dy > 0 and "down" or "up"
end

function InputAdapter.new(runtime, threshold)
    return setmetatable({runtime=runtime or Runtime,threshold=threshold or 40},InputAdapter)
end

function InputAdapter:start(handler)
    self:stop(); self.handler=handler
    self.keyListener=function(event)
        local phase=event.phase=="began" and "down" or event.phase
        local command=phase=="down" and KEY_COMMANDS[event.keyName]
        if command then handler(command); return true end
        return false
    end
    self.touchListener=function(event)
        if event.phase=="began" then
            self.touchId,self.startX,self.startY=event.id,event.x,event.y
            return false
        end
        if (event.phase=="ended" or event.phase=="cancelled") and
            (self.touchId==nil or self.touchId==event.id) and self.startX then
            local command=InputAdapter.directionForSwipe(self.startX,self.startY,event.x,event.y,self.threshold)
            self.touchId,self.startX,self.startY=nil,nil,nil
            if command then handler(command); return true end
        end
        return false
    end
    self.runtime:addEventListener("key",self.keyListener)
    self.runtime:addEventListener("touch",self.touchListener)
end

function InputAdapter:stop()
    if self.keyListener then self.runtime:removeEventListener("key",self.keyListener) end
    if self.touchListener then self.runtime:removeEventListener("touch",self.touchListener) end
    self.keyListener,self.touchListener,self.handler=nil,nil,nil
    self.touchId,self.startX,self.startY=nil,nil,nil
end

return InputAdapter
