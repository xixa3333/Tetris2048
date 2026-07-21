local T = require("test_helper")
local GameState = require("game_state")
local GameLogic = require("game_logic")
local GameController = require("game_controller")

local function chooseFirst(minimum) return minimum end

local function buildSystem()
    local view = {clearCount = 0, renderCount = 0, animationCount = 0, overlayVisible = false}
    function view:clearTransient() self.clearCount = self.clearCount + 1; self.overlayVisible = false end
    function view:render() self.renderCount = self.renderCount + 1 end
    function view:playClearAnimation(cells) self.animationCount = self.animationCount + #cells end
    function view:showGameOver(restart) self.overlayVisible = true; self.restart = restart end
    function view:destroy() self.destroyed = true end

    local scheduler = {queue = {}, cancelled = 0}
    function scheduler:after(_, callback)
        local handle = {callback = callback, cancelled = false}
        self.queue[#self.queue + 1] = handle
        return handle
    end
    function scheduler:cancel(handle) handle.cancelled = true; self.cancelled = self.cancelled + 1 end
    function scheduler:flush()
        local queue = self.queue
        self.queue = {}
        for _, handle in ipairs(queue) do if not handle.cancelled then handle.callback() end end
    end

    local input = {startCount = 0, stopCount = 0}
    function input:start(handler) self.startCount = self.startCount + 1; self.handler = handler end
    function input:stop() self.stopCount = self.stopCount + 1; self.handler = nil end

    local sound = {backgroundCount = 0, gameOverCount = 0, eliminateCount = 0}
    function sound:playBackground() self.backgroundCount = self.backgroundCount + 1 end
    function sound:playGameOver() self.gameOverCount = self.gameOverCount + 1 end
    function sound:playEliminate() self.eliminateCount = self.eliminateCount + 1 end

    local controller = GameController.new({
        state = GameState.new(), logic = GameLogic, view = view,
        scheduler = scheduler, input = input, sound = sound, random = chooseFirst
    })
    return controller, view, scheduler, input, sound
end

T.test("Controller start wires input and renders a fresh game", function()
    local controller, view, _, input, sound = buildSystem()
    controller:start()
    T.equal(view.clearCount, 1)
    T.equal(view.renderCount, 1)
    T.equal(input.startCount, 1)
    T.equal(sound.backgroundCount, 1)
    T.truthy(input.handler)
end)

T.test("Controller rejects repeated movement until scheduled turn completes", function()
    local controller, _, scheduler = buildSystem()
    controller:start()
    T.equal(controller:handle("left"), true)
    T.equal(controller:handle("right"), false)
    scheduler:flush()
    T.equal(controller.state.isBusy, false)
    T.equal(controller:handle("right"), true)
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
