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

T.test("Board.slideWithMoves keeps touching same-colored object ids separate", function()
    local grid = Board.new(4, 4)
    local objects = Board.new(4, 4)
    grid[2][2], objects[2][2] = 1, 101
    grid[2][3], objects[2][3] = 1, 102
    local moved, _, movedObjects = Board.slideWithMoves(grid, "right", objects)
    T.equal(moved[2][3], 1)
    T.equal(moved[2][4], 1)
    T.equal(movedObjects[2][3], 101)
    T.equal(movedObjects[2][4], 102)
end)

T.test("Board.slideWithMoves splits one object when line clearing cuts it apart", function()
    local grid = Board.new(5, 5)
    local objects = Board.new(5, 5)
    grid[2][3], objects[2][3] = 3, 201
    grid[3][3], objects[3][3] = 3, 201
    grid[4][3], objects[4][3] = 3, 201
    for column = 1, 5 do
        if column ~= 3 then grid[3][column], objects[3][column] = 9, 900 + column end
    end
    Board.clearCompletedLines(grid, objects)
    local moved, _, movedObjects = Board.slideWithMoves(grid, "left", objects)
    T.equal(moved[2][1], 3)
    T.equal(moved[4][1], 3)
    T.equal(movedObjects[2][1], 201)
    T.equal(movedObjects[4][1], 201)
end)

T.test("Board.tryPlace never partially writes over an occupied cell", function()
    local grid = Board.new(3, 3)
    grid[1][2] = 9
    local before = Board.copy(grid)
    T.equal(Board.tryPlace(grid, {{1, 1}}, 1, 1), false)
    T.gridEqual(grid, before)
end)

T.test("Board.slideWithMoves preserves a connected component while moving left", function()
    local grid = Board.new(4, 4)
    grid[2][3], grid[2][4], grid[3][3] = 1, 1, 1
    local moved = Board.slideWithMoves(grid, "left")
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

T.test("Board.slideWithMoves never overwrites interleaved components", function()
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
    local moved = Board.slideWithMoves(grid, "right")
    local after = colorCounts(moved)
    for color = 1, #constants.BlockImage do
        T.equal(after[color], before[color], "color was overwritten: " .. color)
    end
end)

T.test("Board.slideWithMoves lets dependent components move together in the selected direction", function()
    local grid = Board.new(5, 5)
    local objects = Board.new(5, 5)
    grid[3][2], objects[3][2] = 1, 101
    grid[2][1], objects[2][1] = 2, 202
    grid[3][1], objects[3][1] = 2, 202
    grid[4][1], objects[4][1] = 2, 202
    grid[4][2], objects[4][2] = 2, 202
    local moved, _, movedObjects = Board.slideWithMoves(grid, "up", objects)
    T.equal(moved[1][1], 2)
    T.equal(moved[2][1], 2)
    T.equal(moved[3][1], 2)
    T.equal(moved[3][2], 2)
    T.equal(moved[1][2], 1)
    T.equal(movedObjects[3][2], 202)
    T.equal(movedObjects[1][2], 101)
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

T.test("Sliding reports moves front-first so animations follow the travel order", function()
    local grid = Board.new(5, 5)
    grid[3][1], grid[3][3], grid[3][5] = 1, 2, 3
    local _, moves = Board.slideWithMoves(grid, "right")
    T.equal(#moves, 3)
    T.equal(moves[1].fromColumn, 5)
    T.equal(moves[2].fromColumn, 3)
    T.equal(moves[3].fromColumn, 1)
    T.equal(moves[3].toColumn, 3)
end)

T.test("Multi-cell components keep their own front edge while sliding upwards", function()
    local grid = Board.new(5, 5)
    for row = 1, 4 do grid[row][1] = 1 end
    grid[2][4] = 2
    local moved, moves = Board.slideWithMoves(grid, "up")
    T.equal(moved[1][4], 2); T.equal(moved[2][4], 0)
    for row = 1, 4 do T.equal(moved[row][1], 1) end
    T.equal(#moves, 5)
    -- 前緣是元件最靠近移動方向的那一格，而不是最遠的那一格。
    T.equal(moves[1].fromRow, 1); T.equal(moves[1].fromColumn, 1)
    T.equal(moves[#moves].fromColumn, 4)
end)

T.test("Transactional placement refuses to write outside the board", function()
    local grid = Board.new(3, 3)
    T.equal(Board.tryPlace(grid, {{1}}, 5, 1), false)
    T.equal(Board.tryPlace(grid, {{1}}, 1, 5), false)
    T.equal(Board.tryPlace(grid, {{1, 1}}, 1, 3), false)
    T.gridEqual(grid, Board.new(3, 3))
    T.equal(Board.canPlace(grid, {{1}}, 0, 1), false)
end)

T.test("Sliding returns a fresh object grid only when object tracking is requested", function()
    local grid = Board.new(3, 3)
    grid[1][1], grid[3][3] = 1, 1
    local _, _, withoutTracking = Board.slideWithMoves(grid, "left")
    T.equal(withoutTracking, nil)
    local objects = Board.new(3, 3)
    objects[1][1], objects[3][3] = 7, 8
    local _, _, tracked = Board.slideWithMoves(grid, "left", objects)
    T.truthy(tracked)
    T.equal(tracked == objects, false)
    -- 原始 objectGrid 必須維持不變，狀態層才能自行決定要不要替換。
    T.equal(objects[1][1], 7); T.equal(objects[3][3], 8)
    T.equal(tracked[1][1], 7); T.equal(tracked[3][1], 8)
end)

T.test("An L shaped component is ordered by its front edge, not by its last cell", function()
    local grid = Board.new(5, 5)
    grid[1][3], grid[2][3], grid[2][2] = 1, 1, 1
    grid[4][3] = 2
    local moved, moves = Board.slideWithMoves(grid, "right")
    T.equal(moved[1][5], 1); T.equal(moved[2][5], 1); T.equal(moved[2][4], 1)
    T.equal(moved[4][5], 2)
    -- 兩個元件的前緣都在第 3 行，先發現的元件先播動畫。
    T.equal(moves[1].fromRow, 1); T.equal(moves[1].fromColumn, 3)
    T.equal(moves[#moves].fromRow, 4)
end)

T.test("Sliding left orders components by their leftmost cell", function()
    local grid = Board.new(5, 5)
    grid[1][3], grid[2][3], grid[2][2] = 1, 1, 1
    grid[4][2] = 2
    local moved, moves = Board.slideWithMoves(grid, "left")
    T.equal(moved[1][2], 1); T.equal(moved[2][1], 1); T.equal(moved[2][2], 1)
    T.equal(moved[4][1], 2)
    T.equal(moves[1].fromRow, 1); T.equal(moves[1].fromColumn, 3)
    T.equal(moves[#moves].fromRow, 4)
end)
