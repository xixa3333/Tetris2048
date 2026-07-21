local constants = require("constants")
local movieclip = require("movieclip")
local widget = require("widget")

local M = {}

function M.updateImage(imageTable, newPath)
    local x, y = imageTable.x, imageTable.y
    imageTable:removeSelf()
    imageTable = display.newImageRect(newPath, 35, 35)
    imageTable.x, imageTable.y = x, y
    imageTable.ImagePath = newPath
    return imageTable
end

function M.GenerateBlocks(Image, x, y, state)
    local tetro = constants.tetrominoes[state.BlockNum]
    for i = 1, #tetro do
        for j = 1, #tetro[i] do
            if (tetro[i][j] ~= 0) then
                local path = constants.BlockImage[tetro[i][j]]
                if (state.rotate == 0) then
                    Image[i + y][j + x] = M.updateImage(Image[i + y][j + x], path)
                elseif (state.rotate == 1) then
                    Image[j + y][#tetro - i + 1 + x] = M.updateImage(Image[j + y][#tetro - i + 1 + x], path)
                elseif (state.rotate == 2) then
                    Image[#tetro - i + 1 + y][#tetro[i] - j + 1 + x] = M.updateImage(Image[#tetro - i + 1 + y][#tetro[i] - j + 1 + x], path)
                elseif (state.rotate == 3) then
                    Image[j + y][i + x] = M.updateImage(Image[j + y][i + x], path)
                end
            end
        end
    end
end

function M.DeleteBlocks(Image, Len, state)
    for i = 1, Len do
        for j = 1, Len do
            Image[i][j] = M.updateImage(Image[i][j], "image/space.png")
            if(Len == 10) then state.MainGrid[i][j] = 0 end
        end
    end
end

function M.PlayExplosion(x, y, state)
    local anim = movieclip.newAnim({
        "image/explode1.png", "image/explode2.png", "image/explode3.png",
        "image/explode4.png", "image/explode5.png", "image/explode6.png",
        "image/explode7.png", "image/explode8.png", "image/explode9.png"
    })
    
    -- 設定動畫屬性
    anim.x, anim.y = x, y
    anim.width, anim.height = 35, 35
    
    -- 記錄至 state 表中以利後續清理
    state.animTable[#state.animTable + 1] = anim
    
    -- 啟動動畫 (播放完後自我移除)
    anim:play({ startFrame = 1, endFrame = 9, loop = 1, remove = true })
end

return M