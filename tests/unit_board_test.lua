local T = require("test_helper")
local Board = require("board")
local constants = require("constants")

T.test("Board.rotate rotates a T piece clockwise", function()
    local rotated = Board.rotate({{1, 1, 1}, {0, 1, 0}}, 1)
    T.gridEqual(rotated, {{0, 1}, {1, 1}, {0, 1}})
end)

T.test("Board.canPlace rejects collisions and out-of-bounds cells", function()
    local grid = Board.new(3, 3)
    grid[2][2] = 9
    T.equal(Board.canPlace(grid, {{1}}, 1, 1), true)
    T.equal(Board.canPlace(grid, {{1}}, 2, 2), false)
    T.equal(Board.canPlace(grid, {{1}}, 4, 1), false)
end)

T.test("Board.tryPlace never partially writes over an occupied cell", function()
    local grid = Board.new(3, 3)
    grid[1][2] = 9
    local before = Board.copy(grid)
    T.equal(Board.tryPlace(grid, {{1, 1}}, 1, 1), false)
    T.gridEqual(grid, before)
end)

T.test("Board.slide preserves a connected component while moving left", function()
    local grid = Board.new(4, 4)
    grid[2][3], grid[2][4], grid[3][3] = 1, 1, 1
    local moved = Board.slide(grid, "left")
    T.gridEqual(moved, {
        {0, 0, 0, 0},
        {1, 1, 0, 0},
        {1, 0, 0, 0},
        {0, 0, 0, 0}
    })
end)

T.test("Board.slideWithMoves reports every source and destination without losing cells", function()
    local grid = Board.new(4, 4)
    grid[2][3], grid[2][4] = 4, 4
    local moved, moves = Board.slideWithMoves(grid, "left")
    T.equal(#moves, 2)
    T.equal(moves[1].fromRow, 2)
    T.equal(moves[1].toRow, 2)
    T.equal(moves[1].toColumn, 1)
    T.equal(moves[2].toColumn, 2)
    T.equal(moved[2][1], 4)
    T.equal(moved[2][2], 4)
end)

T.test("Board.slide never overwrites interleaved components", function()
    local grid = {
        {2,4,0,4,2,5},
        {2,0,3,0,5,3},
        {0,0,0,0,0,0},
        {1,2,0,4,4,0},
        {1,0,4,1,4,5},
        {0,1,5,4,5,0}
    }
    local function colorCounts(board)
        local counts = {}
        for row = 1, #board do
            for column = 1, #board[row] do
                local value = board[row][column]
                if value ~= 0 then counts[value] = (counts[value] or 0) + 1 end
            end
        end
        return counts
    end
    local before = colorCounts(grid)
    local moved = Board.slide(grid, "right")
    local after = colorCounts(moved)
    for color = 1, #constants.BlockImage do
        T.equal(after[color], before[color], "color was overwritten: " .. color)
    end
end)

T.test("Board.clearCompletedLines clears row and column intersections once", function()
    local grid = {
        {1, 1, 1},
        {0, 1, 0},
        {0, 1, 0}
    }
    local result = Board.clearCompletedLines(grid)
    T.equal(result.lineCount, 2)
    T.equal(#result.cells, 5)
    T.gridEqual(grid, Board.new(3, 3))
end)
