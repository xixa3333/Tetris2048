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

T.test("GameLogic creates a blue L piece from a 3x3 matrix", function()
    local shape = GameLogic.shapeFor(6, 0)
    T.equal(#shape, 3)
    T.equal(#shape[1], 3)
    T.equal(shape[1][1], 6)
    T.equal(shape[2][1], 6)
    T.equal(shape[3][1], 6)
    T.equal(shape[3][2], 6)
    T.equal(GameLogic.newPiece(function(_, maximum) return maximum end), 6)
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

T.test("GameLogic revalidates a stale landing position before placement", function()
    local state = GameState.new()
    state.currentPiece = 2
    local function occupyFirstCandidate(minimum)
        state.grid[1][1] = 9
        return minimum
    end
    T.equal(GameLogic.placeRandomPiece(state, occupyFirstCandidate), true)
    T.equal(state.grid[1][1], 9)
    T.equal(state.grid[1][2], 2)
    T.equal(state.grid[2][2], 2)
end)

T.test("GameLogic allows same-colored objects to touch without filtering legal placements", function()
    local state = GameState.new()
    state.currentPiece, state.rotation = 2, 0
    state.grid[2][3] = 2
    local placements = GameLogic.findPlacements(state, 2, 0)
    local hasTouching = false
    for _, placement in ipairs(placements) do
        if Board.hasAdjacentSameColor(state.grid, placement.shape, placement.row, placement.column) then
            hasTouching = true
        end
    end
    T.equal(hasTouching, true)
    T.equal(#placements > 0, true)
end)

T.test("GameLogic falls back to legal placement instead of game over when every fit touches same color", function()
    local state = GameState.new()
    for row = 1, 10 do
        for column = 1, 10 do state.grid[row][column] = 9 end
    end
    state.grid[1][1], state.grid[1][2] = 0, 0
    state.grid[2][1], state.grid[2][2] = 0, 0
    state.grid[1][3] = 2
    state.currentPiece, state.rotation = 2, 0
    T.equal(GameLogic.placeRandomPiece(state, chooseFirst), true)
    T.equal(state.isGameOver, false)
end)

T.test("GameLogic assigns a stable object id to every placed piece", function()
    local state = GameState.new()
    state.currentPiece, state.rotation = 2, 0
    T.equal(GameLogic.placeRandomPiece(state, chooseFirst), true)
    local firstId = state.objectGrid[1][1]
    T.equal(firstId > 0, true)
    T.equal(state.nextObjectId, firstId + 1)
end)

T.test("GameLogic mode one merges touching same colors while mode two keeps object ids separate", function()
    local classic = GameState.new()
    classic.mode = 1
    classic.grid[2][2], classic.objectGrid[2][2] = 1, 101
    classic.grid[2][3], classic.objectGrid[2][3] = 1, 102
    GameLogic.moveBlocks(classic, "right")
    T.equal(classic.grid[2][9], 1)
    T.equal(classic.grid[2][10], 1)

    local relaxed = GameState.new()
    relaxed.mode = 2
    relaxed.grid[2][2], relaxed.objectGrid[2][2] = 1, 101
    relaxed.grid[2][3], relaxed.objectGrid[2][3] = 1, 102
    GameLogic.moveBlocks(relaxed, "right")
    T.equal(relaxed.grid[2][9], 1)
    T.equal(relaxed.objectGrid[2][9], 101)
    T.equal(relaxed.grid[2][10], 1)
    T.equal(relaxed.objectGrid[2][10], 102)
end)

T.test("GameLogic does not replace the player's selected rotation", function()
    local state = GameState.new()
    for row = 1, 10 do
        for column = 1, 10 do state.grid[row][column] = 9 end
    end
    -- A vertical T fits here, while the selected horizontal T does not.
    state.grid[1][9], state.grid[2][9], state.grid[2][10], state.grid[3][9] = 0, 0, 0, 0
    state.currentPiece, state.rotation = 1, 0
    local placed = GameLogic.placeRandomPiece(state, chooseFirst)
    T.equal(placed, false)
    T.equal(state.isGameOver, true)
end)

T.test("GameLogic finds a selected S shape in the final legal coordinate", function()
    local state = GameState.new()
    for row = 1, 10 do
        for column = 1, 10 do state.grid[row][column] = 9 end
    end
    -- The only legal position is the right-side gap shown by the reported case.
    state.grid[3][8], state.grid[3][9] = 0, 0
    state.grid[4][9], state.grid[4][10] = 0, 0
    state.currentPiece, state.rotation = 4, 0
    local placed, cells, rotation = GameLogic.placeRandomPiece(state, chooseFirst)
    T.equal(placed, true)
    T.equal(#cells, 4)
    T.equal(rotation, 0)
    T.equal(state.isGameOver, false)
end)

T.test("GameLogic keeps the failed placement piece visible on game over", function()
    local state = GameState.new()
    for row = 1, 10 do
        for column = 1, 10 do state.grid[row][column] = 9 end
    end
    state.currentPiece, state.nextPiece, state.rotation = 1, 2, 1
    local placement = GameLogic.placeQueuedPiece(state, function() return 3 end)
    T.equal(placement.placed, false)
    T.equal(state.isGameOver, true)
    T.equal(state.gameOverPiece, 2)
    T.equal(state.gameOverRotation, 1)
    T.equal(state.nextPiece, 3)
    T.equal(state.rotation, 0)
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

T.test("GameLogic exposes movement, clearing and placement as isolated phases", function()
    local state = GameState.new()
    state.currentPiece, state.nextPiece = 1, 2
    for column = 1, 10 do state.grid[5][column] = 3 end
    local movement = GameLogic.moveBlocks(state, "up")
    T.equal(#movement.moves, 10)
    T.equal(state.score, 0)
    T.equal(state.currentPiece, 1)
    T.equal(state.grid[1][1], 3)

    local cleared = GameLogic.clearCompleted(state)
    T.equal(cleared.lineCount, 1)
    T.equal(state.score, 10)
    T.equal(state.currentPiece, 1)

    local placement = GameLogic.placeQueuedPiece(state, chooseFirst)
    T.equal(placement.placed, true)
    T.equal(#placement.cells, 4)
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
    local originalPlace = Board.tryPlace
    local captured
    Board.tryPlace = function(grid, shape, row, column)
        captured = shape
        return originalPlace(grid, shape, row, column)
    end
    local ok, message = pcall(GameLogic.move, state, "left", chooseFirst)
    Board.tryPlace = originalPlace
    if not ok then error(message) end
    T.gridEqual(captured, expected)
    T.equal(state.rotation, 0)
end)
