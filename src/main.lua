-- 載入模組
local constants = require("constants")
local state = require("game_state")
local ui = require("ui_renderer")
local logic = require("game_logic")
local widget = require("widget")

-- 音效檔案處理
local audioFiles = {
    eliminate = audio.loadStream("music/eliminate.mp3"),
    background = audio.loadStream("music/BackGround.mp3"),
    gameOver = audio.loadStream("music/GameOver.mp3")
}

-- 初始化隨機種子
math.randomseed(os.time())

-- 播放背景音樂
audio.play(audioFiles.background, {channel = 1, loop = -1})
audio.setVolume(0.15, {channel = 1})
audio.setVolume(0.4, {channel = 2})
audio.setVolume(0.4, {channel = 3})

-- 前端 UI 物件變數 (區域變數)
local buttonStart, buttonRule, againButton
local textScore, textReserve, textNext, endText
local ruleText
local arrowKeys = {} -- 存放 W, A, S, D, R, Space 按鈕
local onKeyEvent, cancelAllTimers, resetGame

local function schedule(delay, callback)
    local handle = timer.performWithDelay(delay, callback, 1)
    state.timerHandles[#state.timerHandles + 1] = handle
    return handle
end

-- [[ 輔助函式：按鈕回呼 ]]

local function up1(event) state.key = "w"; onKeyEvent(event); end
local function down1(event) state.key = "s"; onKeyEvent(event); end
local function left1(event) state.key = "a"; onKeyEvent(event); end
local function right1(event) state.key = "d"; onKeyEvent(event); end
local function rotate1(event) state.key = "r"; onKeyEvent(event); end
local function reserve1(event) state.key = "space"; onKeyEvent(event); end

-- [[ 介面元件建立 ]]

local function CreateArrowKeys()
    arrowKeys.W = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "W", fontSize = 20, onPress = up1, x = 250, y = 730
    }
    arrowKeys.A = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "A", fontSize = 20, onPress = left1, x = 200, y = 780
    }
    arrowKeys.S = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "S", fontSize = 20, onPress = down1, x = 250, y = 780
    }
    arrowKeys.D = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "D", fontSize = 20, onPress = right1, x = 300, y = 780
    }
    arrowKeys.R = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "旋轉", fontSize = 20, onPress = rotate1, x = 100, y = 780
    }
    arrowKeys.Space = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "保留", fontSize = 20, onPress = reserve1, x = 400, y = 780
    }
end

-- 檢查遊戲結束
local function checkEnd()
    if (state.End == 1) then
        cancelAllTimers()
        audio.stop(1)
        audio.play(audioFiles.gameOver, { channel = 3, loop = 0 })
        Runtime:removeEventListener("key", onKeyEvent)

        endText = display.newText("GAME OVER", 200, 70, native.systemFont, 50)
        endText:setTextColor(1, 0, 0)

        againButton = widget.newButton {
            defaultFile = "image/explode1.png", overFile = "image/explode3.png",
            label = "重新", fontSize = 20, onPress = function()
                -- 重新開始邏輯
                endText:removeSelf(); endText = nil
                againButton:removeSelf(); againButton = nil
                ui.DeleteBlocks(state.ReserveImage, 4, state)
                ui.DeleteBlocks(state.NextImage, 4, state)
                ui.DeleteBlocks(state.MainImage, 10, state)
                resetGame()
                CreateArrowKeys()
            end,
            x = 250, y = 230
        }

        -- 移除箭頭按鈕
        for k, v in pairs(arrowKeys) do if v then v:removeSelf(); end end
        arrowKeys = {}
    end
end

-- 完善後的清理函式
cancelAllTimers = function()
    state.isBusy = true

    -- 1. 停止所有計時器
    for i = 1, #state.timerHandles do
        if state.timerHandles[i] then
            pcall(timer.cancel, state.timerHandles[i])
        end
    end
    state.timerHandles = {}

    -- 2. 停止所有正在播的音效 (1:背景, 2:消除, 3:結束)
    audio.stop(2)
    audio.stop(3)

    -- 3. 清理動畫物件參照，防止死角
    if state.animTable then
        for i = #state.animTable, 1, -1 do
            local anim = state.animTable[i]
            if anim and anim.parent then
                anim:stop() -- 停止動畫監聽器
                anim:removeSelf()
            end
            state.animTable[i] = nil -- 移除 table 內的引用，幫助 GC 回收
        end
        state.animTable = {}
    end

    state.isBusy = false
end

-- 封裝移動函式 (為了配合計時器)
local function moveUp() state.direction = "up"; logic.BackupMove(-1, state); logic.BackupToMain(state); end
local function moveDown() state.direction = "down"; logic.BackupMove(1, state); logic.BackupToMain(state); end
local function moveLeft() state.direction = "left"; logic.BackupMove(-1, state); logic.BackupToMain(state); end
local function moveRight() state.direction = "right"; logic.BackupMove(1, state); logic.BackupToMain(state); end

-- [[ 事件監聽器 ]]

onKeyEvent = function(event)
    if state.isBusy then return end

    local num = 0
    local phase = event.phase
    if (event and event.keyName) then state.key = event.keyName end
    if (not (phase == "down" or phase == "up" or phase == "began")) then return end
    if (phase == "began") then phase = "down" end

    if (phase == "down" and (state.key == "w" or state.key == "a" or state.key == "s" or state.key == "d")) then
        state.isBusy = true

        num = num + 1
        if state.key == "w" then schedule(num * 150, moveUp)
        elseif state.key == "a" then schedule(num * 150, moveLeft)
        elseif state.key == "s" then schedule(num * 150, moveDown)
        elseif state.key == "d" then schedule(num * 150, moveRight)
        end
        
        num = num + 1
        schedule(num * 150, function() logic.eliminate(state, audioFiles); textScore.text = state.ScoreNum; end)
        
        num = num + 1
        schedule(num * 150, function() logic.JudgmentOverlap(state) end)
        
        schedule(num * 150 + 10, function()
            if (state.End == 0) then
                ui.DeleteBlocks(state.NextImage, 4, state)
                state.BlockNum = math.random(5)
                ui.GenerateBlocks(state.NextImage, 0, 0, state)
            end
            state.isBusy = false
        end)
        
        num = num + 1
        schedule(num * 150, checkEnd)

    elseif (not state.isBusy and phase == "down" and state.key == "space") then
        local temp
        if (state.SaveNum == 0) then
            state.SaveNum = state.BlockNum
            ui.GenerateBlocks(state.ReserveImage, 0, 0, state)
            state.BlockNum = math.random(5)
            ui.DeleteBlocks(state.NextImage, 4, state)
            ui.GenerateBlocks(state.NextImage, 0, 0, state)
        elseif (state.SaveNum ~= 0) then
            ui.DeleteBlocks(state.ReserveImage, 4, state)
            ui.GenerateBlocks(state.ReserveImage, 0, 0, state)
            temp = state.SaveNum
            state.SaveNum = state.BlockNum
            state.BlockNum = temp
            ui.DeleteBlocks(state.NextImage, 4, state)
            ui.GenerateBlocks(state.NextImage, 0, 0, state)
        end
    elseif (not state.isBusy and phase == "down" and state.key == "r") then
        state.rotate = (state.rotate + 1) % 4
        ui.DeleteBlocks(state.NextImage, 4, state)
        ui.GenerateBlocks(state.NextImage, 0, 0, state)
    end
end

-- [[ 遊戲入口與初始介面 ]]

resetGame = function()
    cancelAllTimers()
    Runtime:removeEventListener("key", onKeyEvent)

    state.isBusy = true

    state.ScoreNum = 0
    state.SaveNum = 0
    state.End = 0
    state.rotate = 0
    textScore.text = state.ScoreNum

    state.BlockNum = math.random(5)
    state.X = math.random(constants.COLS - #constants.tetrominoes[state.BlockNum][1])
    state.Y = math.random(constants.ROWS - #constants.tetrominoes[state.BlockNum])
    logic.MainGenerateBlocks(state)
    
    state.BlockNum = math.random(5)
    ui.GenerateBlocks(state.NextImage, 0, 0, state)
    Runtime:addEventListener("key", onKeyEvent)

    state.isBusy = false
end

-- 建立啟動畫面
local function CreateInterface()
    buttonStart = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "Start", labelColor = {default = {0, 0, 1}}, fontSize = 20,
        onPress = function()
            resetGame()
            buttonStart:removeSelf(); buttonStart = nil
            if buttonRule then buttonRule:removeSelf(); buttonRule = nil end
            if ruleText then ruleText:removeSelf(); ruleText = nil end
            CreateArrowKeys()
        end
    }

    buttonRule = widget.newButton {
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "規則", labelColor = {default = {0, 0, 1}}, fontSize = 20,
        x = 150, y = 30,
        onPress = function()
            ruleText = display.newText("--Russia2048遊戲--\nWASD對應上下左右移動\nR鍵在Next做旋轉\n空白鍵將Next方塊放入Reserve", 250, 80, native.systemFont, 20)
            buttonRule:removeSelf(); buttonRule = nil
        end
    }

    -- 初始化網格圖片
    for i = 1, constants.ROWS do
        state.MainImage[i] = {}
        for j = 1, constants.COLS do
            state.MainImage[i][j] = display.newImageRect("image/space.png", 35, 35)
            state.MainImage[i][j].x = 50 + j * 35
            state.MainImage[i][j].y = 320 + i * 35
        end
    end

    -- 初始化等待區/保留區
    for i = 1, 4 do
        state.NextImage[i] = {}
        state.ReserveImage[i] = {}
        for j = 1, 4 do
            state.NextImage[i][j] = display.newImageRect("image/space.png", 35, 35)
            state.NextImage[i][j].x = 300 + j * 35
            state.NextImage[i][j].y = 150 + i * 35
            state.ReserveImage[i][j] = display.newImageRect("image/space.png", 35, 35)
            state.ReserveImage[i][j].x = 20 + j * 35
            state.ReserveImage[i][j].y = 150 + i * 35
        end
    end

    -- 文字顯示
    display.newText("Score:", 400, 20, native.systemFont, 20):setTextColor(1, 1, 0)
    textScore = display.newText(state.ScoreNum, 450, 20, native.systemFont, 20)
    display.newText("Reserve:", 80, 150, native.systemFont, 20)
    display.newText("Next:", 340, 150, native.systemFont, 20)
end

-- 執行
CreateInterface()
