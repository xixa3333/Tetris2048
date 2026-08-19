local T = require("test_helper")
local GameState = require("game_state")
local GameLogic = require("game_logic")
local GameController = require("game_controller")

local function chooseFirst(minimum) return minimum end

local function buildSystem(callbacks)
    callbacks = callbacks or {}
    local view = {clearCount = 0, renderCount = 0, animationCount = 0, overlayVisible = false, events = {}}
    function view:clearTransient() self.clearCount = self.clearCount + 1; self.overlayVisible = false end
    function view:render() self.renderCount = self.renderCount + 1 end
    function view:playClearAnimation(cells) self.animationCount = self.animationCount + #cells end
    function view:clearAnimation() self.events[#self.events + 1] = "animation-cleared" end
    function view:playMoveAnimation(moves) self.moveCount = #(moves or {}); self.events[#self.events + 1] = "move" end
    function view:playPlacementAnimation(cells) self.placementCount = #(cells or {}); self.events[#self.events + 1] = "place" end
    function view:showGameOver(restart, home) self.overlayVisible = true; self.restart = restart; self.home = home end
    function view:setVisible(value) self.visible = value end
    function view:recover() self.recoverCount = (self.recoverCount or 0) + 1 end
    function view:destroy() self.destroyed = true end

    local scheduler = {queue = {}, cancelled = 0}
    function scheduler:after(_, callback)
        local handle = {callback = callback, cancelled = false}
        self.queue[#self.queue + 1] = handle
        return handle
    end
    function scheduler:cancel(handle) handle.cancelled = true; self.cancelled = self.cancelled + 1 end
    function scheduler:flush()
        local guard = 0
        while #self.queue > 0 do
            guard = guard + 1
            if guard > 50 then error("scheduler did not become idle") end
            self:flushOne()
        end
    end
    function scheduler:flushOne()
        local handle = table.remove(self.queue, 1)
        if handle and not handle.cancelled then handle.callback() end
    end

    local input = {startCount = 0, stopCount = 0}
    function input:start(handler) self.startCount = self.startCount + 1; self.handler = handler end
    function input:stop() self.stopCount = self.stopCount + 1; self.handler = nil end

    local sound = {backgroundCount = 0, gameOverCount = 0, eliminateCount = 0}
    function sound:playBackground() self.backgroundCount = self.backgroundCount + 1 end
    function sound:playGameOver() self.gameOverCount = self.gameOverCount + 1 end
    function sound:playEliminate() self.eliminateCount = self.eliminateCount + 1 end
    function sound:stopBackground() self.stopCount = (self.stopCount or 0) + 1 end

    local controller = GameController.new({
        state = GameState.new(), logic = GameLogic, view = view,
        scheduler = scheduler, input = input, sound = sound, random = callbacks.random or chooseFirst,
        onGameOver = callbacks.onGameOver, onHome = callbacks.onHome
    })
    return controller, view, scheduler, input, sound
end

T.test("Controller start wires input and renders a fresh game", function()
    local controller, view, _, input, sound = buildSystem()
    controller:start()
    T.equal(view.clearCount, 1)
    T.equal(view.renderCount, 1)
    T.equal(input.startCount, 1)
    T.equal(sound.backgroundCount, 0)
    T.truthy(input.handler)
end)

T.test("Game home records partial score once and returns to cover", function()
    local recorded, homes = 0, 0
    local controller = buildSystem({onGameOver=function() recorded=recorded+1 end,onHome=function() homes=homes+1 end})
    controller:start(); controller.state.score=30
    T.equal(controller:handle("home"),true)
    T.equal(recorded,1); T.equal(homes,1); T.equal(controller.active,false)
    T.equal(controller.sound.stopCount,nil)
    controller:returnHome(); T.equal(recorded,1)
end)

T.test("Game-over restart starts a fresh game while home returns to cover", function()
    local homes=0; local controller,view=buildSystem({onGameOver=function() end,onHome=function() homes=homes+1 end})
    controller:start(); controller.state.score=50; controller:finishGame()
    T.truthy(view.restart); T.truthy(view.home)
    view.restart(); T.equal(controller.state.score,0); T.equal(homes,0)
    controller:finishGame(); view.home(); T.equal(homes,1)
end)

T.test("Resume forces renderer recovery and restores input", function()
    local controller,view,_,input,sound=buildSystem(); controller:start(); controller:pause(); controller:resume()
    T.equal(view.recoverCount,1); T.equal(input.startCount,2); T.equal(view.visible,true)
    T.equal(sound.stopCount,nil); T.equal(sound.backgroundCount,0)
end)

T.test("Seeded controller recreates its random stream on every restart",function()
    local streams=0
    local controller=buildSystem()
    controller.randomFactory=function()
        streams=streams+1; local value=0
        return function(minimum,maximum) value=value+1; return minimum+(value%(maximum-minimum+1)) end
    end
    controller:start(); local first=controller.state.currentPiece
    controller:restart(); T.equal(controller.state.currentPiece,first); T.equal(streams,2)
end)

T.test("Controller rejects repeated movement until scheduled turn completes", function()
    local controller, _, scheduler = buildSystem()
    controller:start()
    T.equal(controller:handle("left"), true)
    T.equal(controller:handle("right"), false)
    T.equal(controller:handle("rotate"), false)
    T.equal(controller:handle("reserve"), false)
    T.equal(controller:handle("home"), false)
    scheduler:flushOne()
    T.equal(controller.state.isBusy, true)
    T.equal(controller:handle("up"), false)
    scheduler:flush()
    T.equal(controller.state.isBusy, false)
    T.equal(controller:handle("right"), true)
end)

T.test("Controller animates move, clear, placement, clear as one locked sequence", function()
    local state = GameState.new()
    local calls, clearCount = {}, 0
    local logic = {}
    function logic.moveBlocks() calls[#calls + 1] = "move"; return {moves = {{}}} end
    function logic.clearCompleted()
        clearCount = clearCount + 1
        calls[#calls + 1] = "clear" .. clearCount
        return {lineCount = 1, cells = {{row = 1, column = clearCount}}}
    end
    function logic.placeQueuedPiece()
        calls[#calls + 1] = "place"
        return {placed = true, cells = {{row = 2, column = 2, value = 1}}, gameOver = false}
    end
    local view = {events = {}}
    function view:playMoveAnimation() self.events[#self.events + 1] = "move-animation" end
    function view:playClearAnimation() self.events[#self.events + 1] = "clear-animation" end
    function view:playPlacementAnimation() self.events[#self.events + 1] = "place-animation" end
    function view:clearAnimation() end
    function view:render() end
    local scheduler = {queue = {}}
    function scheduler:after(_, callback) local h={callback=callback}; self.queue[#self.queue+1]=h; return h end
    function scheduler:cancel() end
    local controller = GameController.new({state=state,logic=logic,view=view,scheduler=scheduler})
    T.equal(controller:handle("left"), true)
    while #scheduler.queue > 0 do table.remove(scheduler.queue,1).callback() end
    T.equal(table.concat(calls, ","), "move,clear1,place,clear2")
    T.equal(table.concat(view.events, ","), "move-animation,clear-animation,place-animation,clear-animation")
    T.equal(state.isBusy, false)
end)

T.test("Controller move preserves a cell occupied immediately before landing", function()
    local controller, _, scheduler = buildSystem()
    controller:start()
    controller.random=function(minimum,maximum)
        if maximum>5 then controller.state.grid[1][1]=9 end
        return minimum
    end
    T.equal(controller:handle("down"),true)
    scheduler:flush()
    T.equal(controller.state.grid[1][1],9)
    T.equal(controller.state.isGameOver,false)
end)

T.test("Controller restart cancels work and clears transient animation and text layer", function()
    local controller, view, scheduler, input = buildSystem()
    controller:start()
    controller:handle("left")
    view.overlayVisible = true
    controller:restart()
    T.equal(scheduler.cancelled, 1)
    T.equal(view.clearCount, 2)
    T.equal(view.overlayVisible, false)
    T.equal(input.startCount, 2)
    T.equal(controller.state.score, 0)
    T.equal(controller.state.isBusy, false)
end)

T.test("A stale animation callback cannot modify a restarted game", function()
    local controller, _, scheduler = buildSystem()
    controller:start()
    controller:handle("left")
    local staleCallback = scheduler.queue[1].callback
    controller:restart()
    local expected = require("board").copy(controller.state.grid)
    staleCallback()
    T.gridEqual(controller.state.grid, expected)
    T.equal(controller.state.isBusy, false)
end)

T.test("Turn phases follow the declared state machine from idle back to idle", function()
    local controller, _, scheduler = buildSystem()
    controller:start()
    T.equal(controller:phase(), "idle")
    controller:handle("left")
    T.equal(controller:phase(), "moving")
    local phases = {}
    while #scheduler.queue > 0 do
        scheduler:flushOne()
        phases[#phases + 1] = controller:phase()
    end
    T.equal(phases[#phases], "idle")
    T.equal(controller.state.isBusy, false)
end)

T.test("The busy composite state owns the input lock for every animated phase", function()
    local controller, _, scheduler = buildSystem()
    controller:start()
    controller:handle("down")
    while #scheduler.queue > 0 do
        T.equal(controller.state.isBusy, true, "lock released while phase is " .. controller:phase())
        scheduler:flushOne()
    end
    T.equal(controller:phase(), "idle")
    T.equal(controller.state.isBusy, false)
end)

T.test("Game over is a sibling state that only restart or home can leave", function()
    local homes = 0
    local controller, view = buildSystem({onGameOver = function() end, onHome = function() homes = homes + 1 end})
    controller:start(); controller:finishGame()
    T.equal(controller:phase(), "gameOver")
    T.equal(controller.state.isBusy, false)
    T.equal(controller:handle("left"), false)
    T.equal(controller:handle("home"), false)
    view.restart()
    T.equal(controller:phase(), "idle")
    controller:finishGame(); controller:returnHome()
    T.equal(controller:phase(), "idle")
    T.equal(homes, 1)
end)

T.test("A game that ends before it starts still reports its score exactly once", function()
    local recorded = 0
    local controller = buildSystem({onGameOver = function() recorded = recorded + 1 end})
    T.equal(controller:phase(), "idle")
    controller:returnHome()
    T.equal(recorded, 1)
    controller:finishGame()
    T.equal(recorded, 1)
end)

T.test("Resume reports success both while idle and before the first game", function()
    local controller, view, _, input = buildSystem()
    T.equal(controller:resume(), true)
    T.equal(view.recoverCount, nil)
    T.equal(input.startCount, 0)
    controller:start(); controller:pause()
    T.equal(controller:resume(), true)
    T.equal(view.recoverCount, 1)
    controller:finishGame()
    T.equal(controller:resume(), true)
    T.equal(view.overlayVisible, true)
end)

T.test("The injected random source is the only source of new pieces", function()
    local draws = 0
    local controller = buildSystem({random = function(minimum) draws = draws + 1; return minimum end})
    controller:start()
    T.equal(draws > 0, true)
    T.equal(controller.state.currentPiece, 1)
    T.equal(controller.state.nextPiece, 1)
    local before = draws
    controller:handle("reserve")
    T.equal(draws > before, true)
end)

T.test("Every direction command starts a turn while unknown commands are ignored", function()
    for _, direction in ipairs({"up", "down", "left", "right"}) do
        local controller, view, scheduler = buildSystem()
        controller:start()
        local renders = view.renderCount
        T.equal(controller:handle(direction), true, "direction was rejected: " .. direction)
        T.equal(controller:phase(), "moving")
        scheduler:flush()
        T.equal(view.renderCount > renders, true)
    end
    local controller = buildSystem()
    controller:start()
    T.equal(controller:handle("diagonal"), false)
    T.equal(controller:handle(nil), false)
    T.equal(controller:phase(), "idle")
end)

T.test("Mode selection is normalised into the shared game state", function()
    local controller = buildSystem()
    controller:setMode(2)
    T.equal(controller.state.mode, 2)
    controller:setMode(1)
    T.equal(controller.state.mode, 1)
    controller:setMode("2")
    T.equal(controller.state.mode, 2)
    for _, invalid in ipairs({"", "abc", 0, 3}) do
        controller:setMode(invalid)
        T.equal(controller.state.mode, 1, "unexpected mode for " .. tostring(invalid))
    end
    controller:setMode(2); controller:start()
    T.equal(controller.state.mode, 2, "restarting a game must keep the selected mode")
end)
