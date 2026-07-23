-- 應用程式控制器：協調規則、畫面、計時器、音效與輸入。
-- 依賴全部由建構子注入，因此可用 fake 物件做整合測試。
local GameController = {}
GameController.__index = GameController

local MOVE_COMMANDS = {up = true, down = true, left = true, right = true}
local DEFAULT_TIMINGS = {move = 180, clear = 420, place = 180}

function GameController.new(dependencies)
    assert(dependencies.state, "state is required")
    assert(dependencies.logic, "logic is required")
    assert(dependencies.view, "view is required")
    assert(dependencies.scheduler, "scheduler is required")

    return setmetatable({
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
end

function GameController:cancelPendingWork()
    self.workGeneration = self.workGeneration + 1
    for _, handle in ipairs(self.pendingTimers) do
        self.scheduler:cancel(handle)
    end
    self.pendingTimers = {}
    self.state.isBusy = false
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
    self.view:clearTransient()
    if self.randomFactory then self.random=self.randomFactory() end
    self.logic.start(self.state, self.random)
    self.scoreRecorded = false
    self.active = true
    self.view:render(self.state)
    if self.sound.playBackground then self.sound:playBackground() end
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
    self.active = false
    if self.sound.stopBackground then self.sound:stopBackground() end
    if self.onHome then self.onHome() end
end

function GameController:finishGame()
    self.state.isBusy = false
    if self.input.stop then self.input:stop() end
    if self.sound.playGameOver then self.sound:playGameOver() end
    self:recordScoreOnce()
    self.view:showGameOver(function() self:restart() end, function() self:returnHome() end)
end

function GameController:handle(command)
    if self.state.isBusy or self.state.isGameOver then return false end
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

    self.state.isBusy = true
    local movement = self.logic.moveBlocks(self.state, command)
    if self.view.playMoveAnimation then
        self.view:playMoveAnimation(movement.moves, self.timings.move, self.state)
    end
    self:schedule(self.timings.move, function() self:afterMoveAnimation() end)
    return true
end

function GameController:clearAnimation()
    if self.view.clearAnimation then self.view:clearAnimation() end
end

function GameController:runClearPhase(onComplete)
    local cleared = self.logic.clearCompleted(self.state)
    if cleared.lineCount == 0 then onComplete(); return end
    if self.sound.playEliminate then self.sound:playEliminate() end
    self.view:playClearAnimation(cleared.cells)
    self:schedule(self.timings.clear, function()
        self.view:render(self.state)
        self:clearAnimation()
        onComplete()
    end)
end

function GameController:afterMoveAnimation()
    self.view:render(self.state)
    self:clearAnimation()
    self:runClearPhase(function() self:placePhase() end)
end

function GameController:placePhase()
    local placement = self.logic.placeQueuedPiece(self.state, self.random)
    if placement.placed and self.view.playPlacementAnimation then
        self.view:playPlacementAnimation(placement.cells, self.timings.place)
    end
    self:schedule(self.timings.place, function()
        self.view:render(self.state)
        self:clearAnimation()
        if placement.gameOver then self:finishGame(); return end
        self:runClearPhase(function()
            if self.state.isGameOver then self:finishGame() else self.state.isBusy = false end
        end)
    end)
end

function GameController:pause()
    if self.input.stop then self.input:stop() end
    if self.sound.stopBackground then self.sound:stopBackground() end
end

function GameController:resume()
    if not self.active then return true end
    self.view:setVisible(true)
    self.view:clearTransient()
    if not self.state.isGameOver and self.sound.playBackground then self.sound:playBackground() end
    if self.view.recover then self.view:recover(self.state) else self.view:render(self.state) end
    if self.state.isGameOver and not self.state.isBusy then
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
