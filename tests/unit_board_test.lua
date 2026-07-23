local T = require("test_helper")
local Board = require("board")

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
