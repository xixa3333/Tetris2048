local constants = require("constants")
local M = {}

-- 初始化遊戲狀態
M.ScoreNum = 0
M.SaveNum = 0
M.BlockNum = 0
M.X = 0
M.Y = 0
M.End = 0
M.rotate = 0
M.direction = ""
M.BlockPosition = {0, 0, 0}
M.BlockLength = 0
M.BlockWidth = 0
M.tail = 0
M.bottom = 0

-- 網格與圖片存儲
M.MainGrid = {}
M.MainBackupGrid = {}
M.CutSquare = {}
M.MainImage = {}
M.NextImage = {}
M.ReserveImage = {}
M.animTable = {}

for row = 1, constants.ROWS do
    M.MainGrid[row] = {}
    M.MainBackupGrid[row] = {}
    M.CutSquare[row] = {}

    for column = 1, constants.COLS do
        M.MainGrid[row][column] = 0
        M.MainBackupGrid[row][column] = 0
        M.CutSquare[row][column] = 0
    end
end

-- 消除計數器
M.ROW_eliminate = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
M.COL_eliminate = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

M.isBusy = false      -- 鎖定輸入，防止連續按鍵衝突
M.timerHandles = {}   -- 儲存計時器，方便在重開時取消

return M
