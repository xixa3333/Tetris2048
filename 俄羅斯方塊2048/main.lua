-- 載入背景音樂和音效檔案
local EliminateMusic = audio.loadStream("music/eliminate.mp3")
local BackGroundMusic = audio.loadStream("music/BackGround.mp3")
local GameOverMusic = audio.loadStream("music/GameOver.mp3")
local socket = require("socket")

-- 載入動畫功能
local movieclip = require("movieclip")
local Forest

-- 設定隨機種子，使用當前時間
math.randomseed(os.time())

-- 播放背景音樂，設置音量和循環播放
audio.play(BackGroundMusic, {channel = 1, loop = -1})
audio.setVolume(0.15, {channel = 1}) -- 背景音樂音量
audio.setVolume(0.4, {channel = 2})  -- 其他音效音量
audio.setVolume(0.4, {channel = 3})

-- 定義方塊圖片資源路徑
local BlockImage = {
    "image/T.png",
    "image/square.png",
    "image/Z.png",
    "image/S.png",
    "image/I.png"
}

-- 定義俄羅斯方塊形狀
local tetrominoes = {
    {{1, 1, 1}, {0, 1, 0}},  -- T形
    {{2, 2}, {2, 2}},        -- 方形
    {{0, 3, 3}, {3, 3, 0}},  -- Z形
    {{4, 4, 0}, {0, 4, 4}},  -- S形
    {{5, 5, 5, 5}}           -- I形
}

-- 定義網格大小
local ROWS = 10  -- 行數
local COLS = 10  -- 列數

-- 初始化分數相關變數
local Score
local ScoreNum = 0

-- 初始化遊戲相關變數
local SaveNum = 0
local BlockNum = 0 -- 等待區方塊編號
local X = 0        -- 主要網格X位置
local Y = 0        -- 主要網格Y位置

-- 定義剪取方塊屬性
local BlockPosition = {0, 0, 0} -- [剪取方塊的顏色, 初始X, 初始Y]
local BlockLength = 0           -- 剪取方塊的長度
local BlockWidth = 0            -- 剪取方塊的寬度

-- 定義主要網格及相關圖像和備份資料
local MainGrid = {}           -- 主要網格
local MainBackupGrid = {}     -- 備份網格
local CutSquare = {}          -- 剪取區
local NextImage = {}          -- 等待區圖片
local MainImage = {}          -- 主要網格圖片
local ReserveImage = {}       -- 保留區圖片

-- 初始化遊戲結束狀態
local End = 0
local END
local EndText

-- 初始化行和列消除計數器
local ROW_eliminate = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local COL_eliminate = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

-- 其他遊戲控制變數
local NoBlankLine = 0
local BlankLine = 0
local tail = 0
local bottom = 0
local direction
local rotate = 0
local widget = require("widget")
local main
local key
local onKeyEvent

-- 定義按鈕
local button, button2,AgainBotton

-- 規則
local rule

local W,A,S,D,R,Space

-- 上下左右移動函數
local function up1(event) key = "w"; onKeyEvent(event); end
local function down1(event) key = "s"; onKeyEvent(event); end
local function left1(event) key = "a"; onKeyEvent(event); end
local function right1(event) key = "d"; onKeyEvent(event); end
local function rotate1(event) key = "r"; onKeyEvent(event); end
local function reserve1(event) key = "space"; onKeyEvent(event); end

local function CreateArrowKeys()
  W = widget.newButton {
    defaultFile = "image/explode1.png",
    overFile = "image/explode3.png",
    label = "W",
    font = native.systemFont,
    fontSize = 20,
    emboss = true,
    onPress = up1,
    x = 250,
    y = 730,
  }

  A = widget.newButton {
    defaultFile = "image/explode1.png",
    overFile = "image/explode3.png",
    label = "A",
    font = native.systemFont,
    fontSize = 20,
    emboss = true,
    onPress = left1,
    x = 200,
    y = 780,
  }

  S = widget.newButton {
    defaultFile = "image/explode1.png",
    overFile = "image/explode3.png",
    label = "S",
    font = native.systemFont,
    fontSize = 20,
    emboss = true,
    onPress = down1,
    x = 250,
    y = 780,
  }

  D = widget.newButton {
    defaultFile = "image/explode1.png",
    overFile = "image/explode3.png",
    label = "D",
    font = native.systemFont,
    fontSize = 20,
    emboss = true,
    onPress = right1,
    x = 300,
    y = 780,
  }

  R = widget.newButton {
    defaultFile = "image/explode1.png",
    overFile = "image/explode3.png",
    label = "旋轉",
    font = native.systemFont,
    fontSize = 20,
    emboss = true,
    onPress = rotate1,
    x = 100,
    y = 780,
  }

  Space = widget.newButton {
    defaultFile = "image/explode1.png",
    overFile = "image/explode3.png",
    label = "保留",
    font = native.systemFont,
    fontSize = 20,
    emboss = true,
    onPress = reserve1,
    x = 400,
    y = 780,
  }
end

-- start按鈕被按下時的處理函數
local function b_Press(event)
  print(event)
  main()
  button:removeSelf() -- 刪除按鈕
  button = nil
  if (button2 ~= nil) then
      button2:removeSelf()
      button2 = nil
  end
  if (rule ~= nil) then
    rule:removeSelf()
    rule = nil
  end
  CreateArrowKeys()
end

-- 規則按鈕被按下時的處理函數
local function b_Release(event)
    rule = display.newText("--Russia2048遊戲--\nWASD對應上下左右移動\nR鍵在Next做旋轉\n空白鍵將Next方塊放入Reserve", 250, 80, system.nativeFont, 20)
    button2:removeSelf()
    button2 = nil
end

-- 建立前端介面
local function CreateInterface()
    button = widget.newButton {
        defaultFile = "image/explode1.png",
        overFile = "image/explode3.png",
        label = "Start",
        font = native.systemFont,
        labelColor = {default = {0, 0, 1}},
        fontSize = 20,
        emboss = true,
        onPress = b_Press,
    }

    button2 = widget.newButton {
        defaultFile = "image/explode1.png",
        overFile = "image/explode3.png",
        label = "規則",
        font = native.systemFont,
        labelColor = {default = {0, 0, 1}},
        fontSize = 20,
        emboss = true,
        onPress = b_Release,
        x = 150,
        y = 30,
    }

    -- 初始化主要網格圖片和位置
    for i = 1, ROWS do
        MainGrid[i] = {}
        MainBackupGrid[i] = {}
        MainImage[i] = {}
        CutSquare[i] = {}
        for j = 1, COLS do
            MainGrid[i][j] = 0
            MainBackupGrid[i][j] = 0
            CutSquare[i][j] = 0
            MainImage[i][j] = display.newImageRect("image/space.png", 35, 35)
            MainImage[i][j].x = 50 + j * 35
            MainImage[i][j].y = 320 + i * 35
        end
    end

    -- 初始化等待區和保留區圖片
    for i = 1, 4 do
        NextImage[i] = {}
        ReserveImage[i] = {}
        for j = 1, 4 do
            NextImage[i][j] = display.newImageRect("image/space.png", 35, 35)
            NextImage[i][j].x = 300 + j * 35
            NextImage[i][j].y = 150 + i * 35
            ReserveImage[i][j] = display.newImageRect("image/space.png", 35, 35)
            ReserveImage[i][j].x = 20 + j * 35
            ReserveImage[i][j].y = 150 + i * 35
        end
    end

    -- 顯示分數和標題文字
    local Text = display.newText("Score:", 400, 20, system.nativeFont, 20)
    Score = display.newText(ScoreNum, 450, 20, system.nativeFont, 20)
    Text:setTextColor(1, 1, 0)
    Text2 = display.newText("Reserve:", 80, 150, system.nativeFont, 20)
    Text3 = display.newText("Next:", 340, 150, system.nativeFont, 20)
end

-- 換圖片的函數
local function updateImage(imageTable, newPath)
    local x, y = imageTable.x, imageTable.y -- 保存原始位置
    imageTable:removeSelf() -- 移除舊圖片
    imageTable = display.newImageRect(newPath, 35, 35) -- 建立新圖片
    imageTable.x, imageTable.y = x, y -- 恢復原始位置
    imageTable.ImagePath = newPath -- 更新路徑
    return imageTable
end

local function GenerateBlocks(Image,x,y) --[建立方塊]
  -- 遍歷指定的方塊數組
  for i = 1, #tetrominoes[BlockNum] do
    for j = 1, #tetrominoes[BlockNum][i] do
      -- 如果當前單元格不為0，根據旋轉角度更新影像
      if (tetrominoes[BlockNum][i][j] ~= 0) then
        if (rotate == 0) then
          Image[i + y][j + x] = updateImage(Image[i + y][j + x], BlockImage[tetrominoes[BlockNum][i][j]])
        end
        if (rotate == 1) then
          Image[j + y][#tetrominoes[BlockNum] - i + 1 + x] = updateImage(Image[j + y][#tetrominoes[BlockNum] - i + 1 + x], BlockImage[tetrominoes[BlockNum][i][j]])
        end
        if (rotate == 2) then
          Image[#tetrominoes[BlockNum] - i + 1 + y][#tetrominoes[BlockNum][i] - j + 1 + x] = updateImage(Image[#tetrominoes[BlockNum] - i + 1 + y][#tetrominoes[BlockNum][i] - j + 1 + x], BlockImage[tetrominoes[BlockNum][i][j]])
        end
        if (rotate == 3) then
          Image[j + y][i + x] = updateImage(Image[j + y][i + x], BlockImage[tetrominoes[BlockNum][i][j]])
        end
      end
    end
  end
end

local function MainGenerateBlocks() --[在主要網格隨機建立方塊]
  -- 在主畫面上生成方塊
  GenerateBlocks(MainImage, X, Y)
  for i = 1, #tetrominoes[BlockNum] do
    for j = 1, #tetrominoes[BlockNum][1] do
      -- 根據旋轉角度更新主網格
      if (rotate == 0) then MainGrid[i + Y][j + X] = tetrominoes[BlockNum][i][j] end
      if (rotate == 1) then MainGrid[j + Y][#tetrominoes[BlockNum] - i + 1 + X] = tetrominoes[BlockNum][i][j] end
      if (rotate == 2) then MainGrid[#tetrominoes[BlockNum] - i + 1 + Y][#tetrominoes[BlockNum][i] - j + 1 + X] = tetrominoes[BlockNum][i][j] end
      if (rotate == 3) then MainGrid[j + Y][i + X] = tetrominoes[BlockNum][i][j] end
    end
  end
end

local function DeleteBlocks(Image,Len) --[刪除方塊]
  -- 將指定影像中所有單元格重設為空白
  for i = 1, Len do
    for j = 1, Len do
      Image[i][j] = updateImage(Image[i][j], "image/space.png")
      if(Len==10)then MainGrid[i][j] = 0 end
    end
  end
end

local function JudgmentOverlap() --[判斷建立的方塊是否重疊]
  for z = 0, 400 do
    local flag = 0
    -- 根據旋轉角度隨機生成新方塊的位置
    if (rotate == 0 or rotate == 2) then
      X = math.random(COLS - #tetrominoes[BlockNum][1] + 1) - 1
      Y = math.random(ROWS - #tetrominoes[BlockNum] + 1) - 1
    elseif (rotate == 1 or rotate == 3) then
      X = math.random(ROWS - #tetrominoes[BlockNum] + 1) - 1
      Y = math.random(COLS - #tetrominoes[BlockNum][1] + 1) - 1
    end

    -- 檢查新方塊是否與已有方塊重疊
    for i = 1, #tetrominoes[BlockNum] do
      for j = 1, #tetrominoes[BlockNum][i] do
        if (tetrominoes[BlockNum][i][j] ~= 0 and 
           ((rotate == 0 and MainGrid[i + Y][j + X] ~= 0) or
            (rotate == 1 and MainGrid[j + Y][#tetrominoes[BlockNum] - i + 1 + X] ~= 0) or
            (rotate == 2 and MainGrid[#tetrominoes[BlockNum] - i + 1 + Y][#tetrominoes[BlockNum][i] - j + 1 + X] ~= 0) or
            (rotate == 3 and MainGrid[j + Y][i + X] ~= 0))) then
          flag = 1
          break
        end
      end
      if (flag == 1) then break end
    end

    -- 如果未重疊，生成新方塊；如果嘗試400次仍重疊，結束遊戲
    if (flag == 0) then break end
    if (z == 400) then End = 1 end
  end
  if (End == 0) then MainGenerateBlocks() end
end

local function MaintoCut(i, j)
  -- 將指定的主網格方塊移動到剪取區
  CutSquare[i][j] = MainGrid[i][j]
  MainImage[i][j] = updateImage(MainImage[i][j], "image/space.png") -- 更新主網格影像為空白
  MainGrid[i][j] = 0 -- 將主網格該位置清空
end

local function ExtendCut(i, j)
  -- 向指定方向延伸剪取，將相同的方塊加入剪取區
  
  local Y, X, Y1, X1, Y2, X2, Z1, X3, Y3

  -- 確定方向相關的索引
  if direction == "up" or direction == "down" then
    Z1 = j
  elseif direction == "left" or direction == "right" then
    Z1 = i
  end

  -- 計算下一個可能剪取的方塊位置
  if direction == "up" then
    X3, Y3 = i - 1, j
  elseif direction == "down" then
    X3, Y3 = i + 1, j
  elseif direction == "left" then
    X3, Y3 = i, j - 1
  elseif direction == "right" then
    X3, Y3 = i, j + 1
  end

  -- 如果下一個方塊符合條件，則遞歸剪取
  if X3 > 0 and Y3 > 0 and MainGrid[X3][Y3] ~= 0 and CutSquare[i][j] == MainGrid[X3][Y3] then
    MaintoCut(X3, Y3)
    ExtendCut(X3, Y3)
  end

  -- 向其他方向延伸
  for z = Z1 - 1, 1, -1 do
    if direction == "up" or direction == "down" then
      Y, X = i, z
      Y2, X2 = Y, X + 1
    elseif direction == "left" or direction == "right" then
      Y, X = z, j
      Y2, X2 = Y + 1, X
    end

    -- 計算新的位置
    if direction == "up" then
      Y1, X1 = Y - 1, X
    elseif direction == "down" then
      Y1, X1 = Y + 1, X
    elseif direction == "left" then
      Y1, X1 = Y, X - 1
    elseif direction == "right" then
      Y1, X1 = Y, X + 1
    end

    -- 如果滿足條件則繼續剪取
    if BlockPosition[1] == MainGrid[Y][X] and MainGrid[Y][X] == CutSquare[Y2][X2] then
      if MainGrid[Y1][X1] ~= 0 then
        MaintoCut(Y1, X1)
        ExtendCut(Y1, X1)
      end
      -- 更新方塊的初始位置
      if (direction == "up" or direction == "down") and BlockPosition[2] > z then BlockPosition[2] = z end
      if (direction == "left" or direction == "right") and BlockPosition[3] > z then BlockPosition[3] = z end
      MaintoCut(Y, X)
    elseif MainGrid[Y][X] == 0 then
      break -- 如果空白則停止
    end
  end
end

local function cut(i, j)
  -- 嘗試從主網格剪取指定位置的方塊
  if MainGrid[i][j] ~= 0 and (BlockPosition[1] == 0 or (BlockPosition[1] == MainGrid[i][j] and
    ((j < 10 and MainGrid[i][j] == CutSquare[i][j + 1]) or
     (i < 10 and MainGrid[i][j] == CutSquare[i + 1][j]) or
     (j > 1 and MainGrid[i][j] == CutSquare[i][j - 1]) or
     (i > 1 and MainGrid[i][j] == CutSquare[i - 1][j])))) then

    if BlockPosition[1] == 0 then
      -- 初始化剪取位置
      BlockPosition = {MainGrid[i][j], j, i}
    end

    bottom = i + 1
    if BlockPosition[2] > j then BlockPosition[2] = j end -- 更新起始 X 座標

    -- 將方塊移至剪取區
    MaintoCut(i, j)
    NoBlankLine = 1 -- 記錄本行有有效方塊

    -- 如果上下方塊相同則繼續延伸
    if i > 1 and CutSquare[i][j] == CutSquare[i - 1][j] then
      ExtendCut(i, j)
    end
  end

  -- 判斷是否到達本行結尾
  if (NoBlankLine == 1 and j < COLS and MainGrid[i][j + 1] == 0) or (NoBlankLine == 1 and j == COLS) then
    NoBlankLine = 0
    if tail < j then tail = j end -- 更新尾部位置
    return 1
  end

  if j == COLS and BlockPosition[1] ~= 0 then
    BlankLine = 1 -- 記錄空白行
  end
  return 0
end

-- 省略後續類似 `cut2`, `cut3`, `cut4` 註釋邏輯，與 `cut` 結構相似。

local function cut2(i,j)
  --為初始抓到的方塊/此方塊跟剪取區上下左右方塊一樣
      if(MainGrid[i][j]~=0 and (BlockPosition[1]==0 or (BlockPosition[1]==MainGrid[i][j] and ((j<10 and MainGrid[i][j]==CutSquare[i][j+1]) or (i<10 and MainGrid[i][j]==CutSquare[i+1][j]) or (j>1 and MainGrid[i][j]==CutSquare[i][j-1]) or (i>1 and MainGrid[i][j]==CutSquare[i-1][j])))))then
        if(BlockPosition[1]==0)then --為初始抓到方塊處理
          BlockPosition={MainGrid[i][j],j,i} 
          bottom=i+1
        end
        
        if(BlockPosition[3]>i)then BlockPosition[3]=i end
        if(BlockPosition[2]>j)then BlockPosition[2]=j end--x初始位置
        
        --把主要網格方塊剪到剪取區
        MaintoCut(i,j)
        NoBlankLine=1--代表此行抓到值了
        
        if(i<10 and CutSquare[i][j]==CutSquare[i+1][j])then--如果此方塊跟剪取區下面的方塊一樣再做處理
          ExtendCut(i,j)
        end
      end
        
      if((NoBlankLine==1 and j<COLS and MainGrid[i][j+1]==0) or (NoBlankLine==1 and j==COLS))then --判斷這邊是方塊尾端
        NoBlankLine=0
        if(tail<j) then tail=j end--將尾的值更新
        return 1
      end
      if(j==COLS and BlockPosition[1]~=0)then BlankLine=1 end--判斷這列沒抓到值
      return 0
end

local function cut3(i,j)
  --為初始抓到的方塊/此方塊跟剪取區上下左右方塊一樣
      if(MainGrid[i][j]~=0 and (BlockPosition[1]==0 or (BlockPosition[1]==MainGrid[i][j] and ((j<10 and MainGrid[i][j]==CutSquare[i][j+1]) or (i<10 and MainGrid[i][j]==CutSquare[i+1][j]) or (j>1 and MainGrid[i][j]==CutSquare[i][j-1]) or (i>1 and MainGrid[i][j]==CutSquare[i-1][j])))))then
        if(BlockPosition[1]==0)then --為初始抓到方塊處理
          BlockPosition={MainGrid[i][j],j,i} 
        end
        
        bottom=j+1
        if(BlockPosition[3]>i)then BlockPosition[3]=i end--會變的y初始位置
        
        --把主要網格方塊剪到剪取區(可做成副程式)
        MaintoCut(i,j)
        NoBlankLine=1--代表此行抓到值了
        
        if(i>1 and CutSquare[i][j]==CutSquare[i][j-1])then--如果此方塊跟剪取區左邊的方塊一樣再做處理
          ExtendCut(i,j)
        end
      end
        
      if((NoBlankLine==1 and i<ROWS and MainGrid[i+1][j]==0) or (NoBlankLine==1 and i==ROWS))then --判斷這邊是方塊尾端
        NoBlankLine=0
        if(tail<i) then tail=i end--將尾的值更新
        return 1
      end
      if(i==ROWS and BlockPosition[1]~=0)then BlankLine=1 end--判斷這行沒抓到值
      return 0
end

local function cut4(i,j)
  --為初始抓到的方塊/此方塊跟剪取區上下左右方塊一樣
      if(MainGrid[i][j]~=0 and (BlockPosition[1]==0 or (BlockPosition[1]==MainGrid[i][j] and ((j<10 and MainGrid[i][j]==CutSquare[i][j+1]) or (i<10 and MainGrid[i][j]==CutSquare[i+1][j]) or (j>1 and MainGrid[i][j]==CutSquare[i][j-1]) or (i>1 and MainGrid[i][j]==CutSquare[i-1][j])))))then
        if(BlockPosition[1]==0)then --為初始抓到方塊處理
          BlockPosition={MainGrid[i][j],j,i} 
          bottom=j+1
        end
        
        if(BlockPosition[3]>i)then BlockPosition[3]=i end--會變的y初始位置
        if(BlockPosition[2]>j)then BlockPosition[2]=j end
        
        --把主要網格方塊剪到剪取區
        MaintoCut(i,j)
        NoBlankLine=1--代表此行抓到值了
        
        if(i>1 and CutSquare[i][j]==CutSquare[i][j+1])then--如果此方塊跟剪取區右邊的方塊一樣再做處理
          ExtendCut(i,j)
        end
      end
        
      if((NoBlankLine==1 and i<ROWS and MainGrid[i+1][j]==0) or (NoBlankLine==1 and i==ROWS))then --判斷這邊是方塊尾端
        NoBlankLine=0
        if(tail<i) then tail=i end--將尾的值更新
        return 1
      end
      if(i==ROWS and BlockPosition[1]~=0)then BlankLine=1 end--判斷這行沒抓到值
      return 0
end

local function move_cut() -- 剪取方塊
  NoBlankLine=0
  BlankLine=0
  tail=0
  BlockPosition={0,0,0} -- [剪取方塊的顏色, 初始x, 初始y]
  BlockLength=0 -- 剪取方塊的長度
  BlockWidth=0 -- 剪取方塊的寬度
  bottom=0 -- 剪取區底部
  
  -- 根據方向進行處理
  if(direction=="up")then
    for i=1,ROWS do -- 從上往下遍歷
      for j=1,COLS do
        if(cut(i,j)==1)then break end -- 如果到達尾端停止
      end
      if(BlankLine==1)then -- 如果有空行則停止
        BlankLine=0
        break
      end
    end
    BlockLength=bottom-BlockPosition[3] -- 計算方塊長度
    BlockWidth=tail-BlockPosition[2]+1 -- 計算方塊寬度
    
  elseif(direction=="down")then
    for i=ROWS,1,-1 do -- 從下往上遍歷
      for j=1,COLS do
        if(cut2(i,j)==1)then break end
      end
      if(BlankLine==1)then
        BlankLine=0
        break
      end
    end
    BlockLength=bottom-BlockPosition[3]
    BlockWidth=tail-BlockPosition[2]+1
    
  elseif(direction=="left")then
    for i=1,ROWS do -- 從左往右遍歷
      for j=1,COLS do
        if(cut3(j,i)==1)then break end
      end
      if(BlankLine==1)then
        BlankLine=0
        break
      end
    end
    BlockLength=tail-BlockPosition[3]+1
    BlockWidth=bottom-BlockPosition[2]
    
  elseif(direction=="right")then
    for i=ROWS,1,-1 do -- 從右往左遍歷
      for j=1,COLS do
        if(cut4(j,i)==1)then break end
      end
      if(BlankLine==1)then
        BlankLine=0
        break
      end
    end
    BlockLength=tail-BlockPosition[3]+1
    BlockWidth=bottom-BlockPosition[2]
  end
end

-- 用於將所有方塊移動到備用區的最上面
local function BackupMove(AddSub)
  while true do
    local HaveBlocks = 0
    local InitialVacancy, BackupInitialVacancy, X, Y, len
    move_cut() -- 剪取當前方塊

    -- 判斷備用區的初始空缺區域
    if (direction == "up" or direction == "down") then
      InitialVacancy = BlockPosition[3]
      BackupInitialVacancy = BlockPosition[3]
      len = 11 - BlockLength
    else
      InitialVacancy = BlockPosition[2]
      BackupInitialVacancy = BlockPosition[2]
      len = 11 - BlockWidth
    end

    -- 從當前位置向上尋找空間
    while (true) do
      if (direction == "up" or direction == "down") then
        X = BlockPosition[2]
        Y = InitialVacancy
      else
        X = InitialVacancy
        Y = BlockPosition[3]
      end
      local flag = 0
      for i = Y, Y + BlockLength - 1 do
        for j = X, X + BlockWidth - 1 do
          -- 如果遇到障礙物，則停止
          if (MainBackupGrid[i][j] ~= 0 and CutSquare[BlockPosition[3] + i - Y][BlockPosition[2] + j - X] ~= 0) then
            BackupInitialVacancy = BackupInitialVacancy + 1 * AddSub * -1
            flag = 1
            break
          end
        end
        if (flag == 1) then break end
        -- 如果是空間，則繼續移動
        if (i == Y + BlockLength - 1) then BackupInitialVacancy = BackupInitialVacancy - 1 * AddSub * -1 end
      end
      InitialVacancy = BackupInitialVacancy
      if (flag == 1) then break end
      if (BackupInitialVacancy == 0 and AddSub == -1) then
        InitialVacancy = 1
        break
      end
      if (BackupInitialVacancy == len + 1 and AddSub == 1) then
        InitialVacancy = len
        break
      end
    end

    -- 設定 Y 或 X 座標
    if (direction == "up" or direction == "down") then
      Y = InitialVacancy
    else
      X = InitialVacancy
    end

    -- 將剪取的方塊放入備用區
    for i = Y, Y + BlockLength - 1 do
      for j = X, X + BlockWidth - 1 do
        if (j < 11 and i < 11 and CutSquare[BlockPosition[3] + i - Y][BlockPosition[2] + j - X] ~= 0) then
          MainBackupGrid[i][j] = CutSquare[BlockPosition[3] + i - Y][BlockPosition[2] + j - X]
          CutSquare[BlockPosition[3] + i - Y][BlockPosition[2] + j - X] = 0
        end
      end
    end

    -- 如果主區域已經沒有方塊，則退出循環
    for i = 1, ROWS do
      for j = 1, COLS do
        if (MainGrid[i][j] ~= 0) then HaveBlocks = 1 end
      end
    end
    if (HaveBlocks == 0) then break end
  end
end

-- 將備用區的方塊移回主區域，並更新圖片
local function BackupToMain()
  for i = 1, ROWS do
    for j = 1, COLS do
      if (MainGrid[i][j] ~= MainBackupGrid[i][j]) then
        MainGrid[i][j] = MainBackupGrid[i][j]
        if (MainGrid[i][j] ~= 0) then
          MainImage[i][j] = updateImage(MainImage[i][j], BlockImage[MainGrid[i][j]])
        end
        MainBackupGrid[i][j] = 0
      end
    end
  end
end

-- 上下左右移動函數
local function up() direction = "up"; BackupMove(-1); BackupToMain() end
local function down() direction = "down"; BackupMove(1); BackupToMain() end
local function left() direction = "left"; BackupMove(-1); BackupToMain() end
local function right() direction = "right"; BackupMove(1); BackupToMain() end

-- 消除指定方塊的處理
local function Block_elimination(z, i)
  MainImage[z][i] = updateImage(MainImage[z][i], "image/space.png")
  MainGrid[z][i] = 0

  -- 動畫效果
  Forest = movieclip.newAnim({
    "image/explode1.png", "image/explode2.png", "image/explode3.png",
    "image/explode4.png", "image/explode5.png", "image/explode6.png",
    "image/explode7.png", "image/explode8.png", "image/explode9.png"
  })
  Forest:play({ startFrame = 1, endFrame = 9, loop = 1, remove = true })
  Forest.x, Forest.y = MainImage[z][i].x, MainImage[z][i].y
  Forest.width, Forest.height = 35, 35
end

local function eliminate_change(str, i) -- 方塊消除轉換
  -- 方塊消除加分
  ScoreNum = ScoreNum + 10
  Score.text = ScoreNum

  -- 播放消除音效
  audio.play(EliminateMusic, { channel = 2, loop = 0 })

  -- 根據消除類型執行消除邏輯
  if (str == "COL") then
    COL_eliminate[i] = 0 -- 清除該行的消除標記
    for z = 1, COLS do
      Block_elimination(i, z) -- 消除該行所有方塊
    end
  end
  if (str == "ROW") then
    ROW_eliminate[i] = 0 -- 清除該列的消除標記
    for z = 1, COLS do
      Block_elimination(z, i) -- 消除該列所有方塊
    end
  end
end

local function eliminate() -- 整排消除邏輯
  -- 檢查橫行是否滿行
  for i = 1, ROWS do
    for j = 1, COLS do
      if (MainGrid[i][j] == 0) then break end -- 若有空格則跳出
      if (j == 10) then
        COL_eliminate[i] = 1 -- 標記該行需消除
      end
    end
  end

  -- 檢查直行是否滿行
  for i = 1, ROWS do
    for j = 1, COLS do
      if (MainGrid[j][i] == 0) then break end -- 若有空格則跳出
      if (j == 10) then
        ROW_eliminate[i] = 1 -- 標記該列需消除
      end
    end
  end

  -- 執行消除
  for i = 1, 10 do
    if (COL_eliminate[i] == 1) then eliminate_change("COL", i) end -- 消除滿行
    if (ROW_eliminate[i] == 1) then eliminate_change("ROW", i) end -- 消除滿列
  end
end

local function put() -- 放置新方塊到主網格
  JudgmentOverlap() -- 檢查並將方塊放入主網格
end

local function NextPut() -- 放入等待區的下一個方塊
  if (End == 0) then
    DeleteBlocks(NextImage,4) -- 清空等待區
    BlockNum = math.random(5) -- 隨機生成新方塊
    GenerateBlocks(NextImage, 0, 0) -- 將新方塊顯示到等待區
  end
end

function onKeyEvent(event) -- 處理玩家的按鍵輸入
  local num = 0,phase
  if(event and event.keyName)then key = event.keyName end
  
  if(event.phase=="down" or event.phase=="up")then phase = event.phase -- 判斷按鍵的 "down" 或 "up" 狀態
  elseif(event.phase=="began")then phase = "down" end
  
  if (phase == "down" and (key == "w" or key == "a" or key == "s" or key == "d")) then
    num = num + 1
    if key == "w" then
      timer.performWithDelay(num * 150, up, 1)
    elseif key == "a" then
      timer.performWithDelay(num * 150, left, 1)
    elseif key == "s" then
      timer.performWithDelay(num * 150, down, 1)
    elseif key == "d" then
      timer.performWithDelay(num * 150, right, 1)
    end
    num = num + 1
    timer.performWithDelay(num * 150, eliminate, 1) -- 執行消除
    num = num + 1
    timer.performWithDelay(num * 150, put, 1) -- 放置方塊
    timer.performWithDelay(num * 150 + 10, NextPut, 1) -- 更新下一個方塊
    num = num + 1
    timer.performWithDelay(num * 150, END, 1) -- 檢查遊戲結束
  elseif (phase == "down" and key == "space") then
    -- 處理切換儲存區的邏輯
    local temp
    if (SaveNum == 0) then
      SaveNum = BlockNum
      GenerateBlocks(ReserveImage, 0, 0)
      BlockNum = math.random(5)
      DeleteBlocks(NextImage,4)
      GenerateBlocks(NextImage, 0, 0)
    elseif (SaveNum ~= 0) then
      DeleteBlocks(ReserveImage,4)
      GenerateBlocks(ReserveImage, 0, 0)
      temp = SaveNum
      SaveNum = BlockNum
      BlockNum = temp
      DeleteBlocks(NextImage,4)
      GenerateBlocks(NextImage, 0, 0)
    end
  elseif (phase == "down" and key == "r") then
    rotate = (rotate + 1) % 4 -- 旋轉方塊
    DeleteBlocks(NextImage,4)
    GenerateBlocks(NextImage, 0, 0)
  end
end

local function Again(event)
  EndText:removeSelf()
  EndText = nil
  AgainBotton:removeSelf()
  AgainBotton = nil
  ScoreNum = 0
  Score.text = ScoreNum
  DeleteBlocks(ReserveImage,4)
  DeleteBlocks(NextImage,4)
  DeleteBlocks(MainImage,10)
  main()
  CreateArrowKeys()
  End=0
end

function END() -- 確認遊戲是否結束
  if (End == 1) then
    audio.stop(1)
    audio.play(GameOverMusic, { channel = 3, loop = 0 })
    Runtime:removeEventListener("key", onKeyEvent) -- 移除按鍵監聽
    EndText = display.newText("GAME OVER", 200, 70, system.nativeFont, 50)
    EndText:setTextColor(1, 0, 0) -- 顯示遊戲結束文字

    AgainBotton = widget.newButton {
      defaultFile = "image/explode1.png",
      overFile = "image/explode3.png",
      label = "重新",
      font = native.systemFont,
      fontSize = 20,
      emboss = true,
      onPress = Again,
      x = 250,
      y = 230,
    }

    W:removeSelf()
    W = nil
    A:removeSelf()
    A = nil
    S:removeSelf()
    S = nil
    D:removeSelf()
    D = nil
    R:removeSelf()
    R = nil
    Space:removeSelf()
    Space = nil
  end
end

function main() -- 遊戲主邏輯
  BlockNum = math.random(5) -- 隨機生成一個方塊
  X = math.random(COLS - #tetrominoes[BlockNum][1])
  Y = math.random(ROWS - #tetrominoes[BlockNum])
  MainGenerateBlocks() -- 將方塊放置到主網格
  BlockNum = math.random(5)
  GenerateBlocks(NextImage, 0, 0) -- 顯示下一個方塊
  Runtime:addEventListener("key", onKeyEvent) -- 添加按鍵監聽
end

CreateInterface() -- 創建遊戲界面