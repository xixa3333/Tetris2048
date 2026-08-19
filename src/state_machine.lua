-- 階層式狀態機（HSM）。狀態以宣告式表格描述：parent 建立層級，
-- enter / exit 描述進出行為，on 描述事件轉移。事件由最深的子狀態
-- 往父狀態冒泡，共用行為（例如 back、resume）只需在父狀態宣告一次。
-- 本模組不使用 Solar2D API，controller 與測試都可以直接使用。
local StateMachine={}; StateMachine.__index=StateMachine

local function definitionFor(states,name)
    return assert(states[name],"unknown state: "..tostring(name))
end

-- 由根往葉排列的狀態路徑，是進入／離開順序與 isIn 判定的唯一依據。
local function chain(states,name)
    local path,cursor={},name
    while cursor do
        table.insert(path,1,cursor)
        cursor=definitionFor(states,cursor).parent
    end
    return path
end

-- 複合狀態只是分組，實際停留的一定是葉狀態；initial 讓父狀態能指定預設子狀態。
local function leafOf(states,name)
    local definition=definitionFor(states,name)
    while definition.initial do
        name=definition.initial
        definition=definitionFor(states,name)
    end
    return name
end

function StateMachine.new(definition)
    assert(type(definition)=="table" and type(definition.states)=="table","states are required")
    local self=setmetatable({states=definition.states,owner=definition.owner,
        onChange=definition.onChange,current=nil,generation=0},StateMachine)
    if definition.initial then self:enter(definition.initial) end
    return self
end

function StateMachine:_invoke(name,kind,payload)
    local handler=definitionFor(self.states,name)[kind]
    if handler then handler(self.owner,payload,name) end
end

function StateMachine:state() return self.current end

function StateMachine:path()
    return self.current and chain(self.states,self.current) or {}
end

function StateMachine:isIn(name)
    for _,state in ipairs(self:path()) do if state==name then return true end end
    return false
end

-- 轉移只離開與進入「不共用的」祖先，因此同一群組內切換不會重跑父狀態的行為。
function StateMachine:enter(name,payload)
    local target=leafOf(self.states,name)
    local nextPath=chain(self.states,target)
    local currentPath=self:path()
    local shared=0
    while currentPath[shared+1] and currentPath[shared+1]==nextPath[shared+1] do shared=shared+1 end
    -- 自我轉移代表「重新顯示同一個畫面」，只重入葉狀態，父狀態維持不變。
    if self.current==target then shared=#nextPath-1 end
    for index=#currentPath,shared+1,-1 do self:_invoke(currentPath[index],"exit",payload) end
    self.current=target
    self.generation=self.generation+1
    local generation=self.generation
    if self.onChange then self.onChange(self.owner,target,payload) end
    for index=shared+1,#nextPath do
        -- enter 內部可能再次轉移（例如沒有可消除的線就直接進下一階段），
        -- 此時剩下的 enter 已經不屬於目前路徑，必須停止。
        if self.generation~=generation then return self.current end
        self:_invoke(nextPath[index],"enter",payload)
    end
    return self.current
end

-- 找不到事件時回傳 false，呼叫端就能分辨「被忽略的輸入」與「已處理的轉移」。
function StateMachine:dispatch(event,payload)
    local path=self:path()
    for index=#path,1,-1 do
        local transitions=definitionFor(self.states,path[index]).on
        local target=transitions and transitions[event]
        if target~=nil then
            if type(target)=="function" then
                -- 函式型轉移同時扮演守衛：回傳狀態名稱才轉移，回傳 nil 代表留在原地。
                local resolved=target(self.owner,payload,self.current)
                if type(resolved)=="string" then self:enter(resolved,payload) end
            else
                self:enter(target,payload)
            end
            return true
        end
    end
    return false
end

function StateMachine:handles(event)
    local path=self:path()
    for index=#path,1,-1 do
        local transitions=definitionFor(self.states,path[index]).on
        if transitions and transitions[event]~=nil then return true end
    end
    return false
end

return StateMachine
