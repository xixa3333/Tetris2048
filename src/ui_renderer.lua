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
local INNER_STROKE = 1
local OUTER_STROKE = 5

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

local function createFrameGrid(group, size, originX, originY)
    local frames = {}
    for row = 1, size do
        frames[row] = {}
        for column = 1, size do
            local frame = display.newRect(group, originX + column * CELL_SIZE, originY + row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
            frame:setFillColor(0, 0, 0, 0)
            frame:setStrokeColor(0, 0, 0)
            frame.strokeWidth = INNER_STROKE
            frame.isVisible = false
            frames[row][column] = frame
        end
    end
    return frames
end

local function syncFrame(frame, visible)
    frame.isVisible = visible
    if visible then frame:toFront() end
end

local function drawEdge(group, x1, y1, x2, y2)
    local line = display.newLine(group, x1, y1, x2, y2)
    line:setStrokeColor(0, 0, 0)
    line.strokeWidth = OUTER_STROKE
    return line
end

local function drawObjectOutlines(group, grid, objectGrid, originX, originY, rows, columns)
    local half = CELL_SIZE * 0.5
    local offsets = {
        {row = -1, column = 0, edge = "top"},
        {row = 1, column = 0, edge = "bottom"},
        {row = 0, column = -1, edge = "left"},
        {row = 0, column = 1, edge = "right"}
    }
    for row = 1, rows do
        for column = 1, columns do
            if grid[row] and grid[row][column] ~= 0 then
                local objectId = objectGrid and objectGrid[row] and objectGrid[row][column]
                local centerX, centerY = originX + column * CELL_SIZE, originY + row * CELL_SIZE
                for _, offset in ipairs(offsets) do
                    local nextRow, nextColumn = row + offset.row, column + offset.column
                    local sameObject
                    if objectGrid then
                        sameObject = objectId
                            and objectGrid[nextRow]
                            and objectGrid[nextRow][nextColumn] == objectId
                    else
                        sameObject = grid[nextRow]
                            and grid[nextRow][nextColumn] == grid[row][column]
                    end
                    if not sameObject then
                        if offset.edge == "top" then
                            drawEdge(group, centerX - half, centerY - half, centerX + half, centerY - half)
                        elseif offset.edge == "bottom" then
                            drawEdge(group, centerX - half, centerY + half, centerX + half, centerY + half)
                        elseif offset.edge == "left" then
                            drawEdge(group, centerX - half, centerY - half, centerX - half, centerY + half)
                        else
                            drawEdge(group, centerX + half, centerY - half, centerX + half, centerY + half)
                        end
                    end
                end
            end
        end
    end
end

local function objectGridForShape(shape)
    local objects = Board.new(4, 4)
    for row = 1, #shape do
        for column = 1, #shape[row] do
            if shape[row][column] ~= 0 then objects[row][column] = 1 end
        end
    end
    return objects
end

local function drawPreviewOutline(group, piece, rotation, originX, originY)
    if not piece then return end
    local shape = Board.rotate(constants.tetrominoes[piece], rotation or 0)
    drawObjectOutlines(group, shape, objectGridForShape(shape), originX, originY, 4, 4)
end

local function boundsForMoves(moves)
    local top, left, bottom, right
    for _, move in ipairs(moves) do
        top = math.min(top or move.fromRow, move.fromRow)
        left = math.min(left or move.fromColumn, move.fromColumn)
        bottom = math.max(bottom or move.fromRow, move.fromRow)
        right = math.max(right or move.fromColumn, move.fromColumn)
    end
    return top, left, bottom, right
end

local function buildAnimationShape(moves)
    local top, left, bottom, right = boundsForMoves(moves)
    local rows, columns = bottom - top + 1, right - left + 1
    local grid, objects = Board.new(rows, columns), Board.new(rows, columns)
    for _, move in ipairs(moves) do
        local row, column = move.fromRow - top + 1, move.fromColumn - left + 1
        grid[row][column] = move.value
        objects[row][column] = move.objectId or 1
    end
    return grid, objects, top, left
end

local function groupMovesByObject(moves)
    local groups, order = {}, {}
    for _, move in ipairs(moves or {}) do
        if move.fromRow ~= move.toRow or move.fromColumn ~= move.toColumn then
            local key = move.componentId or move.objectId or ("cell:" .. move.fromRow .. ":" .. move.fromColumn)
            if not groups[key] then
                groups[key] = {}
                order[#order + 1] = key
            end
            groups[key][#groups[key] + 1] = move
        end
    end
    return groups, order
end

local function copyStaticCells(state, moves)
    local grid = Board.copy(state.grid)
    local objects = state.mode == 2 and state.objectGrid and Board.copy(state.objectGrid) or nil
    for _, move in ipairs(moves or {}) do
        if move.fromRow ~= move.toRow or move.fromColumn ~= move.toColumn then
            grid[move.toRow][move.toColumn] = 0
            if objects then objects[move.toRow][move.toColumn] = 0 end
        end
    end
    return grid, objects
end

function Renderer.new()
    local self = setmetatable({}, Renderer)
    self.sceneGroup = display.newGroup()
    self.boardGroup = display.newGroup()
    self.previewGroup = display.newGroup()
    self.outlineGroup = display.newGroup()
    self.controlsGroup = display.newGroup()
    self.sceneGroup:insert(self.boardGroup)
    self.sceneGroup:insert(self.previewGroup)
    self.sceneGroup:insert(self.outlineGroup)
    self.sceneGroup:insert(self.controlsGroup)

    self.boardImages = createImageGrid(self.boardGroup, constants.ROWS, 50, 320)
    self.nextImages = createImageGrid(self.previewGroup, 4, 300, 150)
    self.reserveImages = createImageGrid(self.previewGroup, 4, 20, 150)
    self.boardFrames = createFrameGrid(self.boardGroup, constants.ROWS, 50, 320)
    self.nextFrames = createFrameGrid(self.previewGroup, 4, 300, 150)
    self.reserveFrames = createFrameGrid(self.previewGroup, 4, 20, 150)

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

function Renderer:clearAnimation()
    removeGroup(self.animationGroup)
    self.animationGroup = display.newGroup()
    self.sceneGroup:insert(self.animationGroup)
end

local function renderShape(group, outlineGroup, images, frames, piece, rotation, originX, originY)
    for row = 1, 4 do
        for column = 1, 4 do
            images[row][column] = replaceImage(group, images[row][column], EMPTY_IMAGE)
            syncFrame(frames[row][column], false)
        end
    end
    if not piece then return end
    local shape = Board.rotate(constants.tetrominoes[piece], rotation or 0)
    for row = 1, #shape do
        for column = 1, #shape[row] do
            if shape[row][column] ~= 0 then
                images[row][column] = replaceImage(group, images[row][column], constants.BlockImage[shape[row][column]])
                syncFrame(frames[row][column], true)
            end
        end
    end
    drawObjectOutlines(outlineGroup, shape, objectGridForShape(shape), originX, originY, 4, 4)
end

function Renderer:render(state)
    removeGroup(self.outlineGroup)
    self.outlineGroup = display.newGroup()
    self.sceneGroup:insert(self.outlineGroup)
    for row = 1, constants.ROWS do
        for column = 1, constants.COLS do
            local value = state.grid[row][column]
            local path = value == 0 and EMPTY_IMAGE or constants.BlockImage[value]
            if self.boardImages[row][column].path ~= path then
                self.boardImages[row][column] = replaceImage(self.boardGroup, self.boardImages[row][column], path)
            end
            syncFrame(self.boardFrames[row][column], value ~= 0)
        end
    end
    local outlineObjects = state.mode == 2 and state.objectGrid or nil
    drawObjectOutlines(self.outlineGroup, state.grid, outlineObjects, 50, 320, constants.ROWS, constants.COLS)
    renderShape(self.previewGroup, self.outlineGroup, self.nextImages, self.nextFrames,
        state.gameOverPiece or state.nextPiece,
        state.gameOverPiece and state.gameOverRotation or state.rotation,
        300, 150)
    renderShape(self.previewGroup, self.outlineGroup, self.reserveImages, self.reserveFrames, state.reservedPiece, 0, 20, 150)
    self.scoreText.text = tostring(state.score)
end

function Renderer:recover(state)
    -- Android 從背景回來時 GPU texture 可能已被系統回收；強制重建圖片，
    -- 避免 display object 還在但內容全黑。
    for row=1,constants.ROWS do for column=1,constants.COLS do self.boardImages[row][column].path=nil end end
    for row=1,4 do for column=1,4 do
        self.nextImages[row][column].path=nil; self.reserveImages[row][column].path=nil
        self.nextFrames[row][column].isVisible=false; self.reserveFrames[row][column].isVisible=false
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

function Renderer:playMoveAnimation(moves, duration, state)
    self:clearAnimation()
    removeGroup(self.outlineGroup)
    self.outlineGroup = display.newGroup()
    self.sceneGroup:insert(self.outlineGroup)
    if state then
        local staticGrid, staticObjects = copyStaticCells(state, moves)
        drawObjectOutlines(self.outlineGroup, staticGrid, staticObjects, 50, 320, constants.ROWS, constants.COLS)
        drawPreviewOutline(self.outlineGroup,
            state.gameOverPiece or state.nextPiece,
            state.gameOverPiece and state.gameOverRotation or state.rotation,
            300, 150)
        drawPreviewOutline(self.outlineGroup, state.reservedPiece, 0, 20, 150)
    end
    for _, move in ipairs(moves or {}) do
        if move.fromRow ~= move.toRow or move.fromColumn ~= move.toColumn then
            local source = self.boardImages[move.fromRow][move.fromColumn]
            self.boardImages[move.fromRow][move.fromColumn] = replaceImage(
                self.boardGroup, source, EMPTY_IMAGE
            )
        end
    end
    local groups, order = groupMovesByObject(moves)
    for _, key in ipairs(order) do
        local objectMoves = groups[key]
        local grid, objects, top, left = buildAnimationShape(objectMoves)
        local animationObject = display.newGroup()
        self.animationGroup:insert(animationObject)
        local originX, originY = left * CELL_SIZE, top * CELL_SIZE
        animationObject.x = 50 + (left - 1) * CELL_SIZE
        animationObject.y = 320 + (top - 1) * CELL_SIZE
        for _, move in ipairs(objectMoves) do
            local image = display.newImageRect(
                animationObject, constants.BlockImage[move.value], CELL_SIZE, CELL_SIZE
            )
            image.x = (move.fromColumn - left + 1) * CELL_SIZE
            image.y = (move.fromRow - top + 1) * CELL_SIZE
        end
        drawObjectOutlines(animationObject, grid, objects, originX - left * CELL_SIZE, originY - top * CELL_SIZE, #grid, #grid[1])
        local firstMove = objectMoves[1]
        local dx = (firstMove.toColumn - firstMove.fromColumn) * CELL_SIZE
        local dy = (firstMove.toRow - firstMove.fromRow) * CELL_SIZE
        transition.to(animationObject, {time = duration or 180, x = animationObject.x + dx, y = animationObject.y + dy})
    end
end

function Renderer:playPlacementAnimation(cells, duration)
    self:clearAnimation()
    for _, cell in ipairs(cells or {}) do
        local target = self.boardImages[cell.row][cell.column]
        local image = display.newImageRect(
            self.animationGroup, constants.BlockImage[cell.value], CELL_SIZE, CELL_SIZE
        )
        image.x, image.y = target.x, target.y
        image.xScale, image.yScale, image.alpha = 0.2, 0.2, 0.25
        transition.to(image, {time = duration or 180, xScale = 1, yScale = 1, alpha = 1})
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
