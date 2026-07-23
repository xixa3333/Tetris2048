local T = require("test_helper")
local Board = require("board")
local GameState = require("game_state")
local GameLogic = require("game_logic")
local constants = require("constants")

local function counts(grid)
    local result = {}
    for row = 1, #grid do for column = 1, #grid[row] do
        local value = grid[row][column]
        if value ~= 0 then result[value] = (result[value] or 0) + 1 end
    end end
    return result
end

T.test("Autoplay: long games never overwrite a color during movement or placement", function()
    local seed = 2048
    local function random(minimum, maximum)
        seed = (seed * 48271) % 2147483647
        return minimum + (seed % (maximum - minimum + 1))
    end
    local directions = {"up", "down", "left", "right"}
    local state = GameState.new()
    GameLogic.start(state, random)

    for turn = 1, 1000 do
        if state.isGameOver then GameLogic.start(state, random) end
        local beforeMove = counts(state.grid)
        GameLogic.moveBlocks(state, directions[random(1, 4)])
        local afterMove = counts(state.grid)
        for color = 1, #constants.BlockImage do
            T.equal(afterMove[color] or 0, beforeMove[color] or 0,
                "movement overwrote color " .. color .. " on turn " .. turn)
        end

        local previousScore = state.score
        GameLogic.clearCompleted(state)
        T.equal(state.score >= previousScore, true)

        local beforePlacement = Board.copy(state.grid)
        local placement = GameLogic.placeQueuedPiece(state, random)
        for row = 1, #state.grid do for column = 1, #state.grid[row] do
            if beforePlacement[row][column] ~= 0 then
                T.equal(state.grid[row][column], beforePlacement[row][column],
                    "placement overwrote an occupied cell on turn " .. turn)
            end
        end end
        if placement.placed then GameLogic.clearCompleted(state) end
    end
end)
