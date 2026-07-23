local constants = require("constants")
local Board = require("board")

-- GameState 是每一局遊戲唯一的資料來源。
-- 顯示物件、計時器與音效不放在這裡，避免規則層依賴 Solar2D。
local GameState = {}
GameState.__index = GameState

function GameState.new()
    local self = setmetatable({}, GameState)
    self.grid = Board.new(constants.ROWS, constants.COLS)
    self.objectGrid = Board.new(constants.ROWS, constants.COLS)
    self.mode = 1
    self:reset()
    return self
end

function GameState:reset()
    Board.clear(self.grid)
    Board.clear(self.objectGrid)
    self.nextObjectId = 1
    self.score = 0
    self.currentPiece = nil
    self.nextPiece = nil
    self.gameOverPiece = nil
    self.gameOverRotation = 0
    self.reservedPiece = nil
    self.rotation = 0
    self.isBusy = false
    self.isGameOver = false
end

return GameState
