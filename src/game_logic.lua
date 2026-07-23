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

function GameLogic.findPlacements(state, piece, rotation)
    local placements = {}
    local shape = GameLogic.shapeFor(piece, rotation)
    for row = 1, constants.ROWS - #shape + 1 do
        for column = 1, constants.COLS - #shape[1] + 1 do
            if Board.canPlace(state.grid, shape, row, column) then
                placements[#placements + 1] = {row = row, column = column}
            end
        end
    end
    return placements
end

function GameLogic.placeRandomPiece(state, random)
    local placements = GameLogic.findPlacements(state, state.currentPiece, state.rotation)
    if #placements == 0 then
        state.isGameOver = true
        return false
    end
    local shape = GameLogic.shapeFor(state.currentPiece, state.rotation)
    local firstIndex = random(1, #placements)
    -- Placements are a snapshot. Revalidate at commit time and try every candidate
    -- once, so a stale candidate can never overwrite an occupied board cell.
    for offset = 0, #placements - 1 do
        local index = ((firstIndex + offset - 1) % #placements) + 1
        local placement = placements[index]
        if Board.tryPlace(state.grid, shape, placement.row, placement.column) then return true end
    end
    state.isGameOver = true
    return false
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
    state.grid = Board.slide(state.grid, direction)

    -- 第一階段：移動完成後、放入下一塊之前先結算，避免已完成的線
    -- 佔據空間而造成錯誤的 Game Over。
    local clearedBeforePlacement = Board.clearCompletedLines(state.grid)
    -- rotation 描述的是「下一個要放下的方塊」。提升佇列前先保存，
    -- 否則 advanceQueue() 的初始化會讓玩家剛選擇的旋轉角度遺失。
    local placementRotation = state.rotation
    GameLogic.advanceQueue(state, random)
    state.rotation = placementRotation
    local placed = GameLogic.placeRandomPiece(state, random)
    state.rotation = 0

    -- 第二階段：新方塊可能正好補滿一列或一行，因此放置後再次結算。
    local clearedAfterPlacement = {lineCount = 0, cells = {}}
    if placed then
        clearedAfterPlacement = Board.clearCompletedLines(state.grid)
    end

    local lineCount = clearedBeforePlacement.lineCount + clearedAfterPlacement.lineCount
    state.score = state.score + lineCount * 10

    local cells = {}
    for _, cell in ipairs(clearedBeforePlacement.cells) do cells[#cells + 1] = cell end
    for _, cell in ipairs(clearedAfterPlacement.cells) do cells[#cells + 1] = cell end

    return {
        cleared = {lineCount = lineCount, cells = cells},
        clearedBeforePlacement = clearedBeforePlacement,
        clearedAfterPlacement = clearedAfterPlacement,
        placed = placed,
        gameOver = state.isGameOver
    }
end

return GameLogic
