local T = require("test_helper")
local Board = require("board")
local GameState = require("game_state")
local GameLogic = require("game_logic")
local GameController = require("game_controller")

local function chooseFirst(minimum) return minimum end

T.test("White-box: different colored components block without merging", function()
    local grid = Board.new(4, 4)
    grid[2][1] = 1
    grid[2][4] = 2
    local moved = Board.slide(grid, "left")
    T.equal(moved[2][1], 1)
    T.equal(moved[2][2], 2)
end)

T.test("White-box: a zero inside a tetromino does not overwrite the board", function()
    local grid = Board.new(3, 3)
    grid[2][1] = 9
    local shape = {{1, 1, 1}, {0, 1, 0}}
    T.equal(Board.canPlace(grid, shape, 1, 1), true)
    Board.place(grid, shape, 1, 1)
    T.equal(grid[2][1], 9)
end)

T.test("White-box: every stale candidate fails without replacing existing colors", function()
    local state = GameState.new()
    state.currentPiece = 2
    local function occupyBoard(minimum)
        for row=1,10 do for column=1,10 do state.grid[row][column]=9 end end
        return minimum
    end
    T.equal(GameLogic.placeRandomPiece(state,occupyBoard),false)
    T.equal(state.isGameOver,true)
    for row=1,10 do for column=1,10 do T.equal(state.grid[row][column],9) end end
end)

T.test("White-box: reserve resets rotation in both store and swap branches", function()
    local state = GameState.new()
    state.nextPiece, state.rotation = 2, 3
    GameLogic.reserveNext(state, chooseFirst)
    T.equal(state.rotation, 0)
    state.nextPiece, state.rotation = 4, 2
    GameLogic.reserveNext(state, chooseFirst)
    T.equal(state.rotation, 0)
    T.equal(state.reservedPiece, 4)
    T.equal(state.nextPiece, 2)
end)

T.test("White-box: rotation cycles through every branch", function()
    local state = GameState.new()
    for expected = 1, 3 do
        GameLogic.rotateNext(state)
        T.equal(state.rotation, expected)
    end
    GameLogic.rotateNext(state)
    T.equal(state.rotation, 0)
end)

T.test("White-box: controller covers invalid, rotate and reserve commands", function()
    local state = GameState.new()
    state.nextPiece = 1
    local view = {renders = 0}
    function view:clearTransient() end
    function view:render() self.renders = self.renders + 1 end
    function view:playClearAnimation() end
    function view:showGameOver() end
    function view:destroy() end
    local scheduler = {}
    function scheduler:after() error("movement should not be scheduled") end
    function scheduler:cancel() end
    local controller = GameController.new({
        state = state, logic = GameLogic, view = view, scheduler = scheduler, random = chooseFirst
    })
    T.equal(controller:handle("unknown"), false)
    T.equal(controller:handle("rotate"), true)
    T.equal(state.rotation, 1)
    T.equal(controller:handle("reserve"), true)
    T.equal(state.reservedPiece, 1)
    T.equal(view.renders, 2)
end)

T.test("White-box: game-over branch stops input and exposes restart callback", function()
    local state = GameState.new()
    local fakeLogic = {}
    function fakeLogic.start(target) target:reset() end
    function fakeLogic.moveBlocks()
        return {moves = {}}
    end
    function fakeLogic.clearCompleted()
        return {lineCount = 0, cells = {}}
    end
    function fakeLogic.placeQueuedPiece(target)
        target.isGameOver = true
        return {placed = false, cells = {}, gameOver = true}
    end
    local view = {renderCount = 0}
    function view:clearTransient() end
    function view:render() self.renderCount = self.renderCount + 1 end
    function view:playClearAnimation() end
    function view:showGameOver(restart) self.restart = restart end
    function view:destroy() end
    local scheduler = {queue = {}}
    function scheduler:after(_, callback) self.queue[#self.queue + 1] = callback; return callback end
    function scheduler:cancel() end
    local input = {stopCount = 0}
    function input:start() end
    function input:stop() self.stopCount = self.stopCount + 1 end
    local sound = {gameOverCount = 0}
    function sound:playGameOver() self.gameOverCount = self.gameOverCount + 1 end
    local controller = GameController.new({
        state = state, logic = fakeLogic, view = view, scheduler = scheduler, input = input, sound = sound
    })
    controller:start()
    controller:handle("down")
    scheduler.queue[1]()
    scheduler.queue[2]()
    T.equal(state.isGameOver, true)
    T.equal(input.stopCount, 2)
    T.equal(sound.gameOverCount, 1)
    T.truthy(view.restart)
end)
