local constants = require("constants")
local ui = require("ui_renderer")

local M = {}

-- [[ 內部資料結構：堆疊與節點 ]]
-- 用於處理方塊剪取 (cut) 時的遞迴搜尋
local Node = {}
Node.__index = Node
function Node:new(x, y)
    return setmetatable({ x = x, y = y, next = nil }, Node)
end

local Stack = {}
Stack.__index = Stack
function Stack:new()
    return setmetatable({ top = nil, size = 0 }, Stack)
end

function Stack:push(x, y)
    local newNode = Node:new(x, y)
    newNode.next = self.top
    self.top = newNode
    self.size = self.size + 1
end

function Stack:pop()
    if not self.top then return nil end
    local x, y = self.top.x, self.top.y
    self.top = self.top.next
    self.size = self.size - 1
    return x, y
end

function Stack:isEmpty() return self.size == 0 end

local straight = Stack:new()
local horizontal = Stack:new()

-- [[ 1. 方塊生成與重疊判定 ]]

-- 在主網格資料層建立方塊
function M.MainGenerateBlocks(state)
    -- 呼叫 UI 層繪製方塊
    ui.GenerateBlocks(state.MainImage, state.X, state.Y, state)
    local tetro = constants.tetrominoes[state.BlockNum]
    
    for i = 1, #tetro do
        for j = 1, #tetro[1] do
            -- 根據旋轉角度更新主網格資料
            if (state.rotate == 0) then state.MainGrid[i + state.Y][j + state.X] = tetro[i][j] end
            if (state.rotate == 1) then state.MainGrid[j + state.Y][#tetro - i + 1 + state.X] = tetro[i][j] end
            if (state.rotate == 2) then state.MainGrid[#tetro - i + 1 + state.Y][#tetro[i] - j + 1 + state.X] = tetro[i][j] end
            if (state.rotate == 3) then state.MainGrid[j + state.Y][i + state.X] = tetro[i][j] end
        end
    end
end

-- 判斷隨機生成的方塊是否與現有方塊重疊
function M.JudgmentOverlap(state)
    for z = 0, 400 do
        local flag = 0
        local tetro = constants.tetrominoes[state.BlockNum]
        
        -- 隨機決定位置
        if (state.rotate == 0 or state.rotate == 2) then
            state.X = math.random(constants.COLS - #tetro[1] + 1) - 1
            state.Y = math.random(constants.ROWS - #tetro + 1) - 1
        elseif (state.rotate == 1 or state.rotate == 3) then
            state.X = math.random(constants.ROWS - #tetro + 1) - 1
            state.Y = math.random(constants.COLS - #tetro[1] + 1) - 1
        end

        -- 檢查該位置是否已有方塊 (不為 0)
        for i = 1, #tetro do
            for j = 1, #tetro[i] do
                if (tetro[i][j] ~= 0) then
                    local targetX, targetY
                    if state.rotate == 0 then targetX, targetY = j + state.X, i + state.Y
                    elseif state.rotate == 1 then targetX, targetY = #tetro - i + 1 + state.X, j + state.Y
                    elseif state.rotate == 2 then targetX, targetY = #tetro[i] - j + 1 + state.X, #tetro - i + 1 + state.Y
                    elseif state.rotate == 3 then targetX, targetY = i + state.X, j + state.Y
                    end
                    
                    if state.MainGrid[targetY][targetX] ~= 0 then
                        flag = 1
                        break
                    end
                end
            end
            if (flag == 1) then break end
        end

        if (flag == 0) then break end
        if (z == 400) then state.End = 1 end -- 嘗試 400 次失敗，判定遊戲結束
    end
    
    if (state.End == 0) then M.MainGenerateBlocks(state) end
end

-- [[ 2. 方塊剪取與搜尋邏輯 ]]

-- 遞迴尋找相鄰同色方塊並移至 CutSquare
function M.cut(i, j, state)
    if(state.MainGrid[i][j] ~= 0) then
        -- 紀錄剪取範圍
        if(state.BlockPosition[1] == 0) then state.BlockPosition = {state.MainGrid[i][j], j, i} end
        if(state.BlockPosition[2] > j) then state.BlockPosition[2] = j end
        if(state.BlockPosition[3] > i) then state.BlockPosition[3] = i end
        if(state.tail < j) then state.tail = j end
        if(state.bottom < i) then state.bottom = i end

        -- 移動數據並清空原位
        state.CutSquare[i][j] = state.MainGrid[i][j]
        state.MainImage[i][j] = ui.updateImage(state.MainImage[i][j], "image/space.png")
        state.MainGrid[i][j] = 0
    end

    -- 檢查上下左右
    if(i ~= 1 and state.MainGrid[i-1][j] ~= 0 and state.MainGrid[i-1][j] == state.BlockPosition[1]) then straight:push(i-1, j) end
    if(i ~= 10 and state.MainGrid[i+1][j] ~= 0 and state.MainGrid[i+1][j] == state.BlockPosition[1]) then straight:push(i+1, j) end
    if(j ~= 1 and state.MainGrid[i][j-1] ~= 0 and state.MainGrid[i][j-1] == state.BlockPosition[1]) then horizontal:push(i, j-1) end
    if(j ~= 10 and state.MainGrid[i][j+1] ~= 0 and state.MainGrid[i][j+1] == state.BlockPosition[1]) then horizontal:push(i, j+1) end

    if not horizontal:isEmpty() then
        local ni, nj = horizontal:pop()
        M.cut(ni, nj, state)
    elseif not straight:isEmpty() then
        local ni, nj = straight:pop()
        M.cut(ni, nj, state)
    end
end

-- 根據移動方向掃描網格中的第一個方塊
function M.traverseGrid(state)
    local rowStart, rowEnd, rowStep = 1, constants.ROWS, 1
    local colStart, colEnd, colStep = 1, constants.COLS, 1
    local swap = false

    if state.direction == "down" then rowStart, rowEnd, rowStep = constants.ROWS, 1, -1
    elseif state.direction == "right" then
        rowStart, rowEnd, rowStep = constants.ROWS, 1, -1
        swap = true
    elseif state.direction == "left" then swap = true end

    for i = rowStart, rowEnd, rowStep do
        for j = colStart, colEnd, colStep do
            local x, y = i, j
            if swap then x, y = j, i end
            if state.MainGrid[x][y] ~= 0 then
                M.cut(x, y, state)
                return
            end
        end
    end
end

-- [[ 3. 移動與碰撞物理 ]]

-- 將選中的方塊沿方向移動直到撞擊
function M.BackupMove(AddSub, state)
    while true do
        local HaveBlocks = 0
        local InitialVacancy, BackupInitialVacancy, localX, localY, len
        
        -- 重設剪取暫存與範圍
        state.BlockPosition = {0,0,0}
        state.tail, state.bottom = 0, 0
        M.traverseGrid(state)
        
        state.BlockLength = state.bottom - state.BlockPosition[3] + 1
        state.BlockWidth = state.tail - state.BlockPosition[2] + 1

        -- 判定移動邊界
        if (state.direction == "up" or state.direction == "down") then
            InitialVacancy = state.BlockPosition[3]
            BackupInitialVacancy = state.BlockPosition[3]
            len = 11 - state.BlockLength
        else
            InitialVacancy = state.BlockPosition[2]
            BackupInitialVacancy = state.BlockPosition[2]
            len = 11 - state.BlockWidth
        end

        -- 模擬移動直到碰撞
        while (true) do
            if (state.direction == "up" or state.direction == "down") then
                localX = state.BlockPosition[2]
                localY = InitialVacancy
            else
                localX = InitialVacancy
                localY = state.BlockPosition[3]
            end
            
            local flag = 0
            for i = localY, localY + state.BlockLength - 1 do
                for j = localX, localX + state.BlockWidth - 1 do
                    if (state.MainBackupGrid[i][j] ~= 0 and state.CutSquare[state.BlockPosition[3] + i - localY][state.BlockPosition[2] + j - localX] ~= 0) then
                        BackupInitialVacancy = BackupInitialVacancy + 1 * AddSub * -1
                        flag = 1
                        break
                    end
                end
                if (flag == 1) then break end
                if (i == localY + state.BlockLength - 1) then BackupInitialVacancy = BackupInitialVacancy - 1 * AddSub * -1 end
            end
            
            InitialVacancy = BackupInitialVacancy
            if (flag == 1) then break end
            if (BackupInitialVacancy == 0 and AddSub == -1) then InitialVacancy = 1; break
            elseif (BackupInitialVacancy == len + 1 and AddSub == 1) then InitialVacancy = len; break end
        end

        -- 將資料填入備份網格
        if (state.direction == "up" or state.direction == "down") then localY = InitialVacancy
        else localX = InitialVacancy end

        for i = localY, localY + state.BlockLength - 1 do
            for j = localX, localX + state.BlockWidth - 1 do
                if (j < 11 and i < 11 and state.CutSquare[state.BlockPosition[3] + i - localY][state.BlockPosition[2] + j - localX] ~= 0) then
                    state.MainBackupGrid[i][j] = state.CutSquare[state.BlockPosition[3] + i - localY][state.BlockPosition[2] + j - localX]
                    state.CutSquare[state.BlockPosition[3] + i - localY][state.BlockPosition[2] + j - localX] = 0
                end
            end
        end

        -- 檢查是否還有未處理方塊
        for i = 1, constants.ROWS do
            for j = 1, constants.COLS do
                if (state.MainGrid[i][j] ~= 0) then HaveBlocks = 1 end
            end
        end
        if (HaveBlocks == 0) then break end
    end
end

-- 同步備份數據至主畫面
function M.BackupToMain(state)
    for i = 1, constants.ROWS do
        for j = 1, constants.COLS do
            if (state.MainGrid[i][j] ~= state.MainBackupGrid[i][j]) then
                state.MainGrid[i][j] = state.MainBackupGrid[i][j]
                if (state.MainGrid[i][j] ~= 0) then
                    state.MainImage[i][j] = ui.updateImage(state.MainImage[i][j], constants.BlockImage[state.MainGrid[i][j]])
                end
                state.MainBackupGrid[i][j] = 0
            end
        end
    end
end

-- [[ 4. 消除與遊戲進程 ]]

-- 檢查滿行或滿列並執行消除
function M.eliminate(state, audioTable)
    -- 橫行檢查
    for i = 1, constants.ROWS do
        for j = 1, constants.COLS do
            if (state.MainGrid[i][j] == 0) then break end
            if (j == 10) then state.COL_eliminate[i] = 1 end
        end
    end

    -- 直列檢查
    for i = 1, constants.ROWS do
        for j = 1, constants.COLS do
            if (state.MainGrid[j][i] == 0) then break end
            if (j == 10) then state.ROW_eliminate[i] = 1 end
        end
    end

    -- 執行消除動畫與音效
    for i = 1, 10 do
        if (state.COL_eliminate[i] == 1) then
            state.ScoreNum = state.ScoreNum + 10
            state.COL_eliminate[i] = 0
            audio.play(audioTable.eliminate, { channel = audio.findFreeChannel(), loop = 0 })
            for z = 1, constants.COLS do
                ui.PlayExplosion(state.MainImage[z][i].x, state.MainImage[z][i].y, state)
                state.MainImage[i][z] = ui.updateImage(state.MainImage[i][z], "image/space.png")
                state.MainGrid[i][z] = 0
            end
        end
        if (state.ROW_eliminate[i] == 1) then
            state.ScoreNum = state.ScoreNum + 10
            state.ROW_eliminate[i] = 0
            audio.play(audioTable.eliminate, { channel = audio.findFreeChannel(), loop = 0 })
            for z = 1, constants.COLS do
                ui.PlayExplosion(state.MainImage[i][z].x, state.MainImage[i][z].y, state)
                state.MainImage[z][i] = ui.updateImage(state.MainImage[z][i], "image/space.png")
                state.MainGrid[z][i] = 0
            end
        end
    end
end

return M
