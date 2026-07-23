local constants = require("constants")
local Board = require("board")

-- 純遊戲規則。所有隨機來源由呼叫端注入，讓測試結果可重現。
local GameLogic = {}

function GameLogic.newPiece(random)
    return random(1, #constants.tetrominoes)
end

function GameLogic.shapeFor(piece, rotation)
    return Board.rotate(constants.tetrominoes[piece], rotation)
end

-- Preview matrices may intentionally keep a 3 x 3 footprint, but empty outer
-- rows and columns must not consume board space when checking a landing spot.
local function trimEmptyBorder(shape)
    local top, bottom, left, right
    for row = 1, #shape do
        for column = 1, #shape[row] do
            if shape[row][column] ~= 0 then
                top = math.min(top or row, row); bottom = math.max(bottom or row, row)
                left = math.min(left or column, column); right = math.max(right or column, column)
            end
        end
    end
    local trimmed = {}
    for row = top, bottom do
        trimmed[#trimmed + 1] = {}
        for column = left, right do
            trimmed[#trimmed][#trimmed[#trimmed] + 1] = shape[row][column]
        end
    end
    return trimmed
end

function GameLogic.findPlacements(state, piece, rotation)
    local placements = {}
    local shape = trimEmptyBorder(GameLogic.shapeFor(piece, rotation))
    for row = 1, constants.ROWS - #shape + 1 do
        for column = 1, constants.COLS - #shape[1] + 1 do
            if Board.canPlace(state.grid, shape, row, column) then
                placements[#placements + 1] = {row = row, column = column, shape = shape, rotation = rotation % 4}
            end
        end
    end
    return placements
end

function GameLogic.placeRandomPiece(state, random)
    state.gameOverPiece = nil
    state.gameOverRotation = 0
    local placements = GameLogic.findPlacements(state, state.currentPiece, state.rotation)
    -- Rotation is a player decision. Exhaust every coordinate for the selected
    -- orientation, but never rotate automatically just to avoid game over.
    if #placements == 0 then
        state.gameOverPiece = state.currentPiece
        state.gameOverRotation = state.rotation
        state.isGameOver = true
        return false
    end
    local firstIndex = random(1, #placements)
    -- Placements are a snapshot. Revalidate at commit time and try every candidate
    -- once, so a stale candidate can never overwrite an occupied board cell.
    for offset = 0, #placements - 1 do
        local index = ((firstIndex + offset - 1) % #placements) + 1
        local placement = placements[index]
        local objectId = state.nextObjectId or 1
        local placed, cells = Board.tryPlace(state.grid, placement.shape, placement.row, placement.column, state.objectGrid, objectId)
        if placed then
            state.nextObjectId = objectId + 1
            return true, cells, placement.rotation
        end
    end
    state.isGameOver = true
    state.gameOverPiece = state.currentPiece
    state.gameOverRotation = state.rotation
    return false
end

-- Turn rules are split into phases so a controller can animate each state
-- transition without coupling these rules to Solar2D timers or display objects.
function GameLogic.moveBlocks(state, direction)
    local trackingGrid = state.mode == 2 and state.objectGrid or nil
    local grid, moves, objectGrid = Board.slideWithMoves(state.grid, direction, trackingGrid)
    state.grid = grid
    if state.mode == 2 then state.objectGrid = objectGrid or state.objectGrid end
    return {moves = moves, objectGrid = state.objectGrid}
end

function GameLogic.clearCompleted(state)
    local cleared = Board.clearCompletedLines(state.grid, state.objectGrid)
    state.score = state.score + cleared.lineCount * 10
    return cleared
end

function GameLogic.placeQueuedPiece(state, random)
    local placementRotation = state.rotation
    GameLogic.advanceQueue(state, random)
    state.rotation = placementRotation
    local placed, cells = GameLogic.placeRandomPiece(state, random)
    state.rotation = 0
    return {placed = placed, cells = cells or {}, gameOver = state.isGameOver}
end

function GameLogic.advanceQueue(state, random)
    state.currentPiece = state.nextPiece or GameLogic.newPiece(random)
    state.nextPiece = GameLogic.newPiece(random)
    state.rotation = 0
end

function GameLogic.start(state, random)
    state:reset()
    GameLogic.advanceQueue(state, random)
    return GameLogic.placeRandomPiece(state, random)
end

function GameLogic.rotateNext(state)
    state.rotation = (state.rotation + 1) % 4
end

function GameLogic.reserveNext(state, random)
    if state.reservedPiece then
        state.reservedPiece, state.nextPiece = state.nextPiece, state.reservedPiece
    else
        state.reservedPiece = state.nextPiece
        state.nextPiece = GameLogic.newPiece(random)
    end
    state.rotation = 0
end

function GameLogic.move(state, direction, random)
    GameLogic.moveBlocks(state, direction)

    -- 第一階段：移動完成後、放入下一塊之前先結算，避免已完成的線
    -- 佔據空間而造成錯誤的 Game Over。
    local clearedBeforePlacement = GameLogic.clearCompleted(state)
    -- rotation 描述的是「下一個要放下的方塊」。提升佇列前先保存，
    -- 否則 advanceQueue() 的初始化會讓玩家剛選擇的旋轉角度遺失。
    local placement = GameLogic.placeQueuedPiece(state, random)

    -- 第二階段：新方塊可能正好補滿一列或一行，因此放置後再次結算。
    local clearedAfterPlacement = {lineCount = 0, cells = {}}
    if placement.placed then
        clearedAfterPlacement = GameLogic.clearCompleted(state)
    end

    local lineCount = clearedBeforePlacement.lineCount + clearedAfterPlacement.lineCount
    local cells = {}
    for _, cell in ipairs(clearedBeforePlacement.cells) do cells[#cells + 1] = cell end
    for _, cell in ipairs(clearedAfterPlacement.cells) do cells[#cells + 1] = cell end

    return {
        cleared = {lineCount = lineCount, cells = cells},
        clearedBeforePlacement = clearedBeforePlacement,
        clearedAfterPlacement = clearedAfterPlacement,
        placed = placement.placed,
        gameOver = state.isGameOver
    }
end

return GameLogic
