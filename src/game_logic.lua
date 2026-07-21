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
    local placement = placements[random(1, #placements)]
    Board.place(state.grid, GameLogic.shapeFor(state.currentPiece, state.rotation), placement.row, placement.column)
    return true
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
    local cleared = Board.clearCompletedLines(state.grid)
    state.score = state.score + cleared.lineCount * 10
    GameLogic.advanceQueue(state, random)
    local placed = GameLogic.placeRandomPiece(state, random)
    return {cleared = cleared, placed = placed, gameOver = state.isGameOver}
end

return GameLogic
