-- 遊戲控制器：協調規則、畫面、計時器、音效與輸入。
-- 依賴全部由建構子注入，因此可用 fake 物件做整合測試。
-- 回合流程改由階層式狀態機描述：busy 是複合狀態，負責統一鎖定與解鎖輸入，
-- 子狀態只描述自己該做的事，動畫回合不再靠散落的旗標互相牽制。
local StateMachine = require("state_machine")

local GameController = {}
GameController.__index = GameController

local MOVE_COMMANDS = {up = true, down = true, left = true, right = true}
local DEFAULT_TIMINGS = {move = 180, clear = 420, place = 180}

-- 回合狀態表。宣告式描述讓「哪個階段可以接受輸入」變成可讀的資料，
-- 而不是分散在各處的 isBusy / isGameOver 判斷。
local TURN_STATES = {
    turn = {initial = "idle"},
    idle = {parent = "turn", on = {move = "moving", finish = "gameOver"}},
    -- 複合狀態持有整段動畫期間的輸入鎖，任何子狀態離開時一定會解鎖。
    busy = {
        parent = "turn",
        enter = function(controller) controller.state.isBusy = true end,
        exit = function(controller) controller.state.isBusy = false end,
        on = {finish = "gameOver"}
    },
    moving = {
        parent = "busy",
        enter = function(controller, direction) controller:_startMove(direction) end,
        on = {moved = "clearingAfterMove"}
    },
    -- 移動後先結算，避免已完成的線佔住空間而造成錯誤的 Game Over。
    clearingAfterMove = {
        parent = "busy",
        enter = function(controller) controller:_startClear() end,
        on = {cleared = "placing"}
    },
    placing = {
        parent = "busy",
        enter = function(controller) controller:_startPlacement() end,
        on = {placed = "clearingAfterPlace", blocked = "gameOver"}
    },
    -- 新方塊可能正好補滿一列或一行，因此放置後再結算一次。
    clearingAfterPlace = {
        parent = "busy",
        enter = function(controller) controller:_startClear() end,
        on = {cleared = function(controller)
            return controller.state.isGameOver and "gameOver" or "idle"
        end}
    },
    gameOver = {
        parent = "turn",
        enter = function(controller) controller:_showGameOver() end,
        on = {restart = "idle"}
    }
}

function GameController.new(dependencies)
    assert(dependencies.state, "state is required")
    assert(dependencies.logic, "logic is required")
    assert(dependencies.view, "view is required")
    assert(dependencies.scheduler, "scheduler is required")

    local controller = setmetatable({
        state = dependencies.state,
        logic = dependencies.logic,
        view = dependencies.view,
        scheduler = dependencies.scheduler,
        sound = dependencies.sound or {},
        input = dependencies.input or {},
        random = dependencies.random or math.random,
        randomFactory = dependencies.randomFactory,
        onGameOver = dependencies.onGameOver,
        onHome = dependencies.onHome,
        pendingTimers = {}, scoreRecorded = false, active = false,
        workGeneration = 0,
        timings = dependencies.timings or DEFAULT_TIMINGS
    }, GameController)
    controller.machine = StateMachine.new({owner = controller, states = TURN_STATES, initial = "turn"})
    return controller
end

function GameController:phase()
    return self.machine:state()
end

function GameController:cancelPendingWork()
    self.workGeneration = self.workGeneration + 1
    for _, handle in ipairs(self.pendingTimers) do
        self.scheduler:cancel(handle)
    end
    self.pendingTimers = {}
end

function GameController:schedule(delay, callback)
    local generation = self.workGeneration
    local handle
    handle = self.scheduler:after(delay, function()
        for index = #self.pendingTimers, 1, -1 do
            if self.pendingTimers[index] == handle then
                table.remove(self.pendingTimers, index)
                break
            end
        end
        if generation ~= self.workGeneration then return end
        callback()
    end)
    self.pendingTimers[#self.pendingTimers + 1] = handle
end

-- start 與 restart 共用相同生命週期，確保每次重開都先完整清場。
function GameController:start()
    self:cancelPendingWork()
    if self.input.stop then self.input:stop() end
    self.machine:enter("idle")
    self.view:clearTransient()
    if self.randomFactory then self.random = self.randomFactory() end
    self.logic.start(self.state, self.random)
    self.scoreRecorded = false
    self.active = true
    self.view:render(self.state)
    if self.input.start then self.input:start(function(command) self:handle(command) end) end
end

function GameController:restart()
    self:start()
end

function GameController:setMode(mode)
    self.state.mode = tonumber(mode) == 2 and 2 or 1
end

function GameController:recordScoreOnce()
    if not self.scoreRecorded and self.onGameOver then
        self.scoreRecorded = true
        self.onGameOver(self.state.score)
    end
end

function GameController:returnHome()
    self:cancelPendingWork()
    if self.input.stop then self.input:stop() end
    self:recordScoreOnce()
    self.machine:enter("idle")
    self.active = false
    if self.onHome then self.onHome() end
end

function GameController:finishGame()
    self.machine:enter("gameOver")
end

-- 只有 idle 會接受玩家輸入；動畫與 Game Over 期間的輸入一律忽略。
function GameController:handle(command)
    if not self.machine:isIn("idle") then return false end
    if command == "home" then self:returnHome(); return true end

    if command == "rotate" then
        self.logic.rotateNext(self.state)
        self.view:render(self.state)
        return true
    end
    if command == "reserve" then
        self.logic.reserveNext(self.state, self.random)
        self.view:render(self.state)
        return true
    end
    if not MOVE_COMMANDS[command] then return false end

    self.machine:dispatch("move", command)
    return true
end

function GameController:clearAnimation()
    if self.view.clearAnimation then self.view:clearAnimation() end
end

function GameController:_startMove(direction)
    local movement = self.logic.moveBlocks(self.state, direction)
    if self.view.playMoveAnimation then
        self.view:playMoveAnimation(movement.moves, self.timings.move, self.state)
    end
    self:schedule(self.timings.move, function()
        self.view:render(self.state)
        self:clearAnimation()
        self.machine:dispatch("moved")
    end)
end

function GameController:_startClear()
    local cleared = self.logic.clearCompleted(self.state)
    if cleared.lineCount == 0 then self.machine:dispatch("cleared"); return end
    if self.sound.playEliminate then self.sound:playEliminate() end
    self.view:playClearAnimation(cleared.cells)
    self:schedule(self.timings.clear, function()
        self.view:render(self.state)
        self:clearAnimation()
        self.machine:dispatch("cleared")
    end)
end

function GameController:_startPlacement()
    local placement = self.logic.placeQueuedPiece(self.state, self.random)
    if placement.placed and self.view.playPlacementAnimation then
        self.view:playPlacementAnimation(placement.cells, self.timings.place)
    end
    self:schedule(self.timings.place, function()
        self.view:render(self.state)
        self:clearAnimation()
        self.machine:dispatch(placement.gameOver and "blocked" or "placed")
    end)
end

function GameController:_showGameOver()
    if self.input.stop then self.input:stop() end
    if self.sound.playGameOver then self.sound:playGameOver() end
    self:recordScoreOnce()
    self.view:showGameOver(function() self:restart() end, function() self:returnHome() end)
end

function GameController:pause()
    if self.input.stop then self.input:stop() end
end

function GameController:resume()
    if not self.active then return true end
    self.view:setVisible(true)
    self.view:clearTransient()
    if self.view.recover then self.view:recover(self.state) else self.view:render(self.state) end
    if self.machine:isIn("gameOver") then
        self.view:showGameOver(function() self:restart() end, function() self:returnHome() end)
    elseif self.input.start then
        self.input:start(function(command) self:handle(command) end)
    end
    return true
end

function GameController:destroy()
    self:cancelPendingWork()
    if self.input.stop then self.input:stop() end
    self.view:destroy()
end

return GameController
