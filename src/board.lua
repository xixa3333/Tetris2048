-- 棋盤資料結構與純運算。
-- 本模組不使用 Solar2D API，因此可以在一般 Lua 執行器中直接測試。
local Board = {}

local DIRECTIONS = {
    up = { row = -1, column = 0 },
    down = { row = 1, column = 0 },
    left = { row = 0, column = -1 },
    right = { row = 0, column = 1 }
}

function Board.new(rows, columns, initialValue)
    local value = initialValue == nil and 0 or initialValue
    local grid = {}
    for row = 1, rows do
        grid[row] = {}
        for column = 1, columns do
            grid[row][column] = value
        end
    end
    return grid
end

function Board.clear(grid, value)
    local replacement = value == nil and 0 or value
    for row = 1, #grid do
        for column = 1, #grid[row] do
            grid[row][column] = replacement
        end
    end
end

function Board.copy(grid)
    local copied = Board.new(#grid, #grid[1])
    for row = 1, #grid do
        for column = 1, #grid[row] do
            copied[row][column] = grid[row][column]
        end
    end
    return copied
end

-- 將方塊矩陣依順時針方向旋轉，rotation 可為任意整數。
function Board.rotate(shape, rotation)
    local result = shape
    for _ = 1, (rotation or 0) % 4 do
        local rotated = {}
        for column = 1, #result[1] do
            rotated[column] = {}
            for row = #result, 1, -1 do
                rotated[column][#result - row + 1] = result[row][column]
            end
        end
        result = rotated
    end
    return result
end

function Board.canPlace(grid, shape, top, left)
    for row = 1, #shape do
        for column = 1, #shape[row] do
            if shape[row][column] ~= 0 then
                local targetRow = top + row - 1
                local targetColumn = left + column - 1
                if not grid[targetRow]
                    or grid[targetRow][targetColumn] == nil
                    or grid[targetRow][targetColumn] ~= 0 then
                    return false
                end
            end
        end
    end
    return true
end

-- Transactional placement: validate every occupied target before writing any cell.
-- Returning false leaves the grid byte-for-byte unchanged.
function Board.tryPlace(grid, shape, top, left)
    local targets = {}
    for row = 1, #shape do
        for column = 1, #shape[row] do
            if shape[row][column] ~= 0 then
                local targetRow, targetColumn = top + row - 1, left + column - 1
                if not grid[targetRow]
                    or grid[targetRow][targetColumn] == nil
                    or grid[targetRow][targetColumn] ~= 0 then
                    return false
                end
                targets[#targets + 1] = {
                    row = targetRow, column = targetColumn, value = shape[row][column]
                }
            end
        end
    end
    for _, target in ipairs(targets) do
        grid[target.row][target.column] = target.value
    end
    return true, targets
end

function Board.place(grid, shape, top, left)
    assert(Board.tryPlace(grid, shape, top, left), "cannot place shape at requested position")
end

-- 尋找所有同色且上下左右相連的元件。
local function connectedComponents(grid)
    local visited, components = Board.new(#grid, #grid[1], false), {}
    local neighbors = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}

    for row = 1, #grid do
        for column = 1, #grid[row] do
            if grid[row][column] ~= 0 and not visited[row][column] then
                local value = grid[row][column]
                local queue, component, cursor = {{row = row, column = column}}, {}, 1
                visited[row][column] = true

                while cursor <= #queue do
                    local cell = queue[cursor]
                    cursor = cursor + 1
                    component[#component + 1] = cell
                    for _, offset in ipairs(neighbors) do
                        local nextRow, nextColumn = cell.row + offset[1], cell.column + offset[2]
                        if grid[nextRow]
                            and grid[nextRow][nextColumn] == value
                            and not visited[nextRow][nextColumn] then
                            visited[nextRow][nextColumn] = true
                            queue[#queue + 1] = {row = nextRow, column = nextColumn}
                        end
                    end
                end

                components[#components + 1] = {value = value, cells = component}
            end
        end
    end
    return components
end

-- 將每個相連元件沿指定方向滑到底；元件形狀在移動中保持不變。
function Board.slideWithMoves(grid, direction)
    local delta = assert(DIRECTIONS[direction], "unknown direction: " .. tostring(direction))
    local components = connectedComponents(grid)

    local function frontEdge(component)
        local edge
        for _, cell in ipairs(component.cells) do
            local coordinate = (direction == "up" or direction == "down") and cell.row or cell.column
            if edge == nil
                or ((direction == "down" or direction == "right") and coordinate > edge)
                or ((direction == "up" or direction == "left") and coordinate < edge) then
                edge = coordinate
            end
        end
        return edge
    end

    for id, component in ipairs(components) do
        component.id = id
        for _, cell in ipairs(component.cells) do
            cell.fromRow, cell.fromColumn = cell.row, cell.column
        end
    end
    table.sort(components, function(a, b)
        local aEdge, bEdge = frontEdge(a), frontEdge(b)
        if aEdge == bEdge then return a.id < b.id end
        if direction == "down" or direction == "right" then return aEdge > bEdge end
        return aEdge < bEdge
    end)

    -- All components share one live occupancy map. Moving one cell per pass lets
    -- trailing components follow vacated cells without ever entering a cell that
    -- is still owned by another color/component.
    local occupied = Board.new(#grid, #grid[1], false)
    for _, component in ipairs(components) do
        for _, cell in ipairs(component.cells) do occupied[cell.row][cell.column] = component end
    end

    local movedInPass
    repeat
        movedInPass = false
        for _, component in ipairs(components) do
            local canMove = true
            for _, cell in ipairs(component.cells) do
                local row, column = cell.row + delta.row, cell.column + delta.column
                local owner = occupied[row] and occupied[row][column]
                if not occupied[row] or owner == nil or (owner and owner ~= component) then
                    canMove = false
                    break
                end
            end
            if canMove then
                for _, cell in ipairs(component.cells) do occupied[cell.row][cell.column] = false end
                for _, cell in ipairs(component.cells) do
                    cell.row, cell.column = cell.row + delta.row, cell.column + delta.column
                end
                for _, cell in ipairs(component.cells) do occupied[cell.row][cell.column] = component end
                movedInPass = true
            end
        end
    until not movedInPass

    local result, moves = Board.new(#grid, #grid[1]), {}
    for _, component in ipairs(components) do
        for _, cell in ipairs(component.cells) do
            result[cell.row][cell.column] = component.value
            moves[#moves + 1] = {
                fromRow = cell.fromRow, fromColumn = cell.fromColumn,
                toRow = cell.row, toColumn = cell.column,
                value = component.value
            }
        end
    end

    return result, moves
end

function Board.slide(grid, direction)
    local result = Board.slideWithMoves(grid, direction)
    return result
end

-- 清除完整橫列與直行。交叉格只回報一次，分數仍以線數計算。
function Board.clearCompletedLines(grid)
    local fullRows, fullColumns, cleared = {}, {}, {}
    for row = 1, #grid do
        local full = true
        for column = 1, #grid[row] do
            if grid[row][column] == 0 then full = false; break end
        end
        if full then fullRows[#fullRows + 1] = row end
    end
    for column = 1, #grid[1] do
        local full = true
        for row = 1, #grid do
            if grid[row][column] == 0 then full = false; break end
        end
        if full then fullColumns[#fullColumns + 1] = column end
    end
    local seen = {}
    for _, row in ipairs(fullRows) do
        for column = 1, #grid[row] do
            local key = row .. ":" .. column
            seen[key] = true
            cleared[#cleared + 1] = {row = row, column = column}
            grid[row][column] = 0
        end
    end
    for _, column in ipairs(fullColumns) do
        for row = 1, #grid do
            local key = row .. ":" .. column
            if not seen[key] then cleared[#cleared + 1] = {row = row, column = column} end
            grid[row][column] = 0
        end
    end
    return {rows = fullRows, columns = fullColumns, cells = cleared, lineCount = #fullRows + #fullColumns}
end

return Board
