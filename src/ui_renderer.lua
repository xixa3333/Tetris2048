local constants = require("constants")
local Board = require("board")
local movieclip = require("movieclip")
local widget = require("widget")
local gameOverLayout = require("game_over_layout")

-- Solar2D 顯示層。所有顯示物件都歸屬於明確的 display group，
-- 重新開始時只要銷毀 transient groups，就不會遺留動畫或文字。
local Renderer = {}
Renderer.__index = Renderer

local CELL_SIZE = 35
local EMPTY_IMAGE = "image/space.png"

local function removeGroup(group)
    if group and group.removeSelf then group:removeSelf() end
end

local function replaceImage(group, oldImage, path)
    local x, y = oldImage.x, oldImage.y
    oldImage:removeSelf()
    local image = display.newImageRect(group, path, CELL_SIZE, CELL_SIZE)
    image.x, image.y = x, y
    image.path = path
    return image
end

local function createImageGrid(group, size, originX, originY)
    local images = {}
    for row = 1, size do
        images[row] = {}
        for column = 1, size do
            local image = display.newImageRect(group, EMPTY_IMAGE, CELL_SIZE, CELL_SIZE)
            image.x = originX + column * CELL_SIZE
            image.y = originY + row * CELL_SIZE
            image.path = EMPTY_IMAGE
            images[row][column] = image
        end
    end
    return images
end

function Renderer.new()
    local self = setmetatable({}, Renderer)
    self.sceneGroup = display.newGroup()
    self.boardGroup = display.newGroup()
    self.previewGroup = display.newGroup()
    self.controlsGroup = display.newGroup()
    self.sceneGroup:insert(self.boardGroup)
    self.sceneGroup:insert(self.previewGroup)
    self.sceneGroup:insert(self.controlsGroup)

    self.boardImages = createImageGrid(self.boardGroup, constants.ROWS, 50, 320)
    self.nextImages = createImageGrid(self.previewGroup, 4, 300, 150)
    self.reserveImages = createImageGrid(self.previewGroup, 4, 20, 150)

    self.scoreLabel = display.newText(self.sceneGroup, "Score:", 400, 20, native.systemFont, 20)
    self.scoreLabel:setTextColor(1, 1, 0)
    self.scoreText = display.newText(self.sceneGroup, "0", 450, 20, native.systemFont, 20)
    self.reserveLabel = display.newText(self.sceneGroup, "Reserve:", 80, 150, native.systemFont, 20)
    self.nextLabel = display.newText(self.sceneGroup, "Next:", 340, 150, native.systemFont, 20)

    self:createControls()
    self:clearTransient()
    return self
end

function Renderer:createControls()
    local definitions = {
        {label = "主畫面", command = "home", x = 70, y = 45, width = 120},
        {label = "W", command = "up", x = 250, y = 730},
        {label = "A", command = "left", x = 200, y = 780},
        {label = "S", command = "down", x = 250, y = 780},
        {label = "D", command = "right", x = 300, y = 780},
        {label = "旋轉", command = "rotate", x = 100, y = 780},
        {label = "保留", command = "reserve", x = 400, y = 780}
    }
    for _, definition in ipairs(definitions) do
        local button = widget.newButton({
            defaultFile = "image/explode1.png",
            overFile = "image/explode3.png",
            label = definition.label,
            font = native.systemFontBold,
            fontSize = 20,
            labelColor = {default = {1,1,1}, over = {1,1,0.3}},
            width = definition.width,
            x = definition.x,
            y = definition.y,
            onPress = function()
                if self.commandHandler then self.commandHandler(definition.command) end
                return true
            end
        })
        self.controlsGroup:insert(button)
    end
end

function Renderer:setCommandHandler(handler)
    self.commandHandler = handler
end

function Renderer:setVisible(visible)
    self.sceneGroup.isVisible = visible
end

function Renderer:clearTransient()
    removeGroup(self.animationGroup)
    removeGroup(self.overlayGroup)
    self.animationGroup = display.newGroup()
    self.overlayGroup = display.newGroup()
    self.sceneGroup:insert(self.animationGroup)
    self.sceneGroup:insert(self.overlayGroup)
    self.controlsGroup.isVisible = true
end

local function renderShape(group, images, piece, rotation)
    for row = 1, 4 do
        for column = 1, 4 do
            images[row][column] = replaceImage(group, images[row][column], EMPTY_IMAGE)
        end
    end
    if not piece then return end
    local shape = Board.rotate(constants.tetrominoes[piece], rotation or 0)
    for row = 1, #shape do
        for column = 1, #shape[row] do
            if shape[row][column] ~= 0 then
                images[row][column] = replaceImage(group, images[row][column], constants.BlockImage[shape[row][column]])
            end
        end
    end
end

function Renderer:render(state)
    for row = 1, constants.ROWS do
        for column = 1, constants.COLS do
            local value = state.grid[row][column]
            local path = value == 0 and EMPTY_IMAGE or constants.BlockImage[value]
            if self.boardImages[row][column].path ~= path then
                self.boardImages[row][column] = replaceImage(self.boardGroup, self.boardImages[row][column], path)
            end
        end
    end
    renderShape(self.previewGroup, self.nextImages, state.nextPiece, state.rotation)
    renderShape(self.previewGroup, self.reserveImages, state.reservedPiece, 0)
    self.scoreText.text = tostring(state.score)
end

function Renderer:recover(state)
    -- Android 從背景回來時 GPU texture 可能已被系統回收；強制重建圖片，
    -- 避免 display object 還在但內容全黑。
    for row=1,constants.ROWS do for column=1,constants.COLS do self.boardImages[row][column].path=nil end end
    for row=1,4 do for column=1,4 do
        self.nextImages[row][column].path=nil; self.reserveImages[row][column].path=nil
    end end
    self:render(state)
end

function Renderer:playClearAnimation(cells)
    for _, cell in ipairs(cells) do
        local image = self.boardImages[cell.row][cell.column]
        local animation = movieclip.newAnim({
            "image/explode1.png", "image/explode2.png", "image/explode3.png",
            "image/explode4.png", "image/explode5.png", "image/explode6.png",
            "image/explode7.png", "image/explode8.png", "image/explode9.png"
        })
        self.animationGroup:insert(animation)
        animation.x, animation.y = image.x, image.y
        animation.width, animation.height = CELL_SIZE, CELL_SIZE
        animation:play({startFrame = 1, endFrame = 9, loop = 1, remove = true})
    end
end

function Renderer:showGameOver(onRestart, onHome)
    removeGroup(self.overlayGroup)
    self.overlayGroup = display.newGroup()
    self.sceneGroup:insert(self.overlayGroup)
    self.controlsGroup.isVisible = false

    local title = display.newText(self.overlayGroup, "GAME OVER", 250, 70, native.systemFont, 50)
    title:setTextColor(1, 0, 0)
    local restartButton = widget.newButton({
        defaultFile = "image/explode1.png",
        overFile = "image/explode3.png",
        label = "重新開始",
        font = native.systemFontBold,
        labelColor = {default = {1,1,1}, over = {1,1,0.3}},
        fontSize = 20,
        x = gameOverLayout.restart.x,
        y = gameOverLayout.restart.y,
        width = gameOverLayout.restart.width,
        height = gameOverLayout.restart.height,
        onPress = function() onRestart(); return true end
    })
    self.overlayGroup:insert(restartButton)
    local homeButton = widget.newButton({
        defaultFile = "image/explode1.png", overFile = "image/explode3.png",
        label = "回到主畫面", font = native.systemFontBold, fontSize = 20,
        labelColor = {default = {1,1,1}, over = {1,1,0.3}},
        x = gameOverLayout.home.x, y = gameOverLayout.home.y,
        width = gameOverLayout.home.width, height = gameOverLayout.home.height,
        onPress = function() onHome(); return true end
    })
    self.overlayGroup:insert(homeButton)
end

function Renderer:destroy()
    removeGroup(self.sceneGroup)
    self.sceneGroup = nil
end

return Renderer
