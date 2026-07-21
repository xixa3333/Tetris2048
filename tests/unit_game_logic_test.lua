local T = require("test_helper")
local Board = require("board")
local GameState = require("game_state")
local GameLogic = require("game_logic")

local function chooseFirst(minimum)
    return minimum
end

T.test("GameLogic.start resets state and creates current and next pieces", function()
    local state = GameState.new()
    state.score = 50
    T.equal(GameLogic.start(state, chooseFirst), true)
    T.equal(state.score, 0)
    T.equal(state.currentPiece, 1)
    T.equal(state.nextPiece, 1)
    T.equal(state.grid[1][1], 1)
end)

T.test("GameLogic.reserveNext stores and swaps preview pieces", function()
    local state = GameState.new()
    state.nextPiece = 2
    GameLogic.reserveNext(state, chooseFirst)
    T.equal(state.reservedPiece, 2)
    T.equal(state.nextPiece, 1)
    state.nextPiece = 3
    GameLogic.reserveNext(state, chooseFirst)
    T.equal(state.reservedPiece, 3)
    T.equal(state.nextPiece, 2)
end)

T.test("GameLogic.placeRandomPiece reports game over when no placement exists", function()
    local state = GameState.new()
    for row = 1, #state.grid do
        for column = 1, #state.grid[row] do state.grid[row][column] = 9 end
    end
    state.currentPiece = 1
    T.equal(GameLogic.placeRandomPiece(state, chooseFirst), false)
    T.equal(state.isGameOver, true)
end)

T.test("GameLogic.move slides, scores a completed line, and advances queue", function()
    local state = GameState.new()
    state.currentPiece, state.nextPiece = 1, 2
    for column = 1, 10 do state.grid[1][column] = column end
    local result = GameLogic.move(state, "up", chooseFirst)
    T.equal(result.cleared.lineCount >= 1, true)
    T.equal(state.score >= 10, true)
    T.equal(state.currentPiece, 2)
end)

T.test("GameLogic.move checks completed lines before and after placement", function()
    local state = GameState.new()
    state.currentPiece, state.nextPiece = 1, 2
    local original = Board.clearCompletedLines
    local calls = 0
    Board.clearCompletedLines = function()
        calls = calls + 1
        return {lineCount = 1, cells = {{row = calls, column = 1}}}
    end
    local ok, result = pcall(GameLogic.move, state, "left", chooseFirst)
    Board.clearCompletedLines = original
    if not ok then error(result) end
    T.equal(calls, 2)
    T.equal(result.clearedBeforePlacement.lineCount, 1)
    T.equal(result.clearedAfterPlacement.lineCount, 1)
    T.equal(result.cleared.lineCount, 2)
    T.equal(state.score, 20)
end)

T.test("GameLogic.move places the rotated preview shape before resetting rotation", function()
    local state = GameState.new()
    state.currentPiece, state.nextPiece = 1, 1
    GameLogic.rotateNext(state)
    local expected = GameLogic.shapeFor(1, 1)
    local originalPlace = Board.place
    local captured
    Board.place = function(grid, shape, row, column)
        captured = shape
        return originalPlace(grid, shape, row, column)
    end
    local ok, message = pcall(GameLogic.move, state, "left", chooseFirst)
    Board.place = originalPlace
    if not ok then error(message) end
    T.gridEqual(captured, expected)
    T.equal(state.rotation, 0)
end)
