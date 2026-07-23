local T = require("test_helper")
local Board = require("board")
local GameState = require("game_state")
local GameLogic = require("game_logic")

local function chooseFirst(minimum) return minimum end

T.test("Boundary: a single cell reaches each of the four board edges", function()
    local cases = {
        up = {row = 1, column = 5},
        down = {row = 10, column = 5},
        left = {row = 5, column = 1},
        right = {row = 5, column = 10}
    }
    for direction, expected in pairs(cases) do
        local grid = Board.new(10, 10)
        grid[5][5] = 1
        local moved = Board.slide(grid, direction)
        T.equal(moved[expected.row][expected.column], 1, direction .. " edge was not reached")
    end
end)

T.test("Boundary: placement accepts the bottom-right corner", function()
    local grid = Board.new(10, 10)
    T.equal(Board.canPlace(grid, {{1}}, 10, 10), true)
    Board.place(grid, {{1}}, 10, 10)
    T.equal(grid[10][10], 1)
end)

T.test("Boundary: collision at the final shape cell leaves every target unchanged", function()
    local grid = Board.new(10, 10)
    grid[10][10] = 8
    local before = Board.copy(grid)
    T.equal(Board.tryPlace(grid, {{7, 7}, {7, 7}}, 9, 9), false)
    T.gridEqual(grid, before)
end)

T.test("Boundary: transactional placement preserves every preoccupied board cell", function()
    local shape = {{3, 3, 3}, {0, 3, 0}}
    for blockedRow=1,10 do
        for blockedColumn=1,10 do
            local grid=Board.new(10,10); grid[blockedRow][blockedColumn]=9
            local before=Board.copy(grid)
            local placed=Board.tryPlace(grid,shape,4,4)
            if not placed then T.gridEqual(grid,before) end
            T.equal(grid[blockedRow][blockedColumn],9)
        end
    end
end)

T.test("Boundary: placement rejects every position outside the board", function()
    local grid = Board.new(10, 10)
    T.equal(Board.canPlace(grid, {{1}}, 0, 1), false)
    T.equal(Board.canPlace(grid, {{1}}, 1, 0), false)
    T.equal(Board.canPlace(grid, {{1}}, 11, 1), false)
    T.equal(Board.canPlace(grid, {{1}}, 1, 11), false)
end)

T.test("Boundary: four rotations return the original shape", function()
    local shape = {{1, 1, 1}, {0, 1, 0}}
    T.gridEqual(Board.rotate(shape, 4), shape)
    T.gridEqual(Board.rotate(shape, 8), shape)
end)

T.test("Boundary: empty board remains empty after movement and line clearing", function()
    local grid = Board.new(10, 10)
    T.gridEqual(Board.slide(grid, "down"), grid)
    local result = Board.clearCompletedLines(grid)
    T.equal(result.lineCount, 0)
    T.equal(#result.cells, 0)
end)

T.test("Boundary: completely full board clears all rows and columns", function()
    local grid = Board.new(10, 10, 1)
    local result = Board.clearCompletedLines(grid)
    T.equal(result.lineCount, 20)
    T.equal(#result.cells, 100)
    T.gridEqual(grid, Board.new(10, 10))
end)

T.test("Boundary: rotated I piece has legal positions on a blank board", function()
    local state = GameState.new()
    local horizontal = GameLogic.findPlacements(state, 5, 0)
    local vertical = GameLogic.findPlacements(state, 5, 1)
    T.equal(#horizontal, 70)
    T.equal(#vertical, 70)
    state.currentPiece, state.rotation = 5, 1
    T.equal(GameLogic.placeRandomPiece(state, chooseFirst), true)
end)
