-- Composition root：只負責建立 Solar2D adapters 並組裝應用程式。
-- 遊戲規則與流程分別位於 game_logic.lua、game_controller.lua。
local GameState = require("game_state")
local GameLogic = require("game_logic")
local GameController = require("game_controller")
local Renderer = require("ui_renderer")

math.randomseed(os.time())

local audioFiles = {
    eliminate = audio.loadStream("music/eliminate.mp3"),
    background = audio.loadStream("music/BackGround.mp3"),
    gameOver = audio.loadStream("music/GameOver.mp3")
}

local scheduler = {}
function scheduler:after(delay, callback)
    return timer.performWithDelay(delay, callback, 1)
end
function scheduler:cancel(handle)
    if handle then pcall(timer.cancel, handle) end
end

local sound = {}
function sound:playBackground()
    audio.stop(1)
    audio.play(audioFiles.background, {channel = 1, loops = -1})
    audio.setVolume(0.15, {channel = 1})
end
function sound:playEliminate()
    audio.play(audioFiles.eliminate, {channel = 2, loops = 0})
    audio.setVolume(0.4, {channel = 2})
end
function sound:playGameOver()
    audio.stop(1)
    audio.play(audioFiles.gameOver, {channel = 3, loops = 0})
    audio.setVolume(0.4, {channel = 3})
end

local input = {listener = nil}
local keyCommands = {
    w = "up", s = "down", a = "left", d = "right",
    r = "rotate", space = "reserve"
}
function input:start(handler)
    self:stop()
    self.listener = function(event)
        local phase = event.phase == "began" and "down" or event.phase
        if phase == "down" and keyCommands[event.keyName] then
            handler(keyCommands[event.keyName])
            return true
        end
        return false
    end
    Runtime:addEventListener("key", self.listener)
end
function input:stop()
    if self.listener then
        Runtime:removeEventListener("key", self.listener)
        self.listener = nil
    end
end

local view = Renderer.new()
local controller = GameController.new({
    state = GameState.new(),
    logic = GameLogic,
    view = view,
    scheduler = scheduler,
    sound = sound,
    input = input,
    random = math.random
})

view:setCommandHandler(function(command) controller:handle(command) end)
controller:start()
