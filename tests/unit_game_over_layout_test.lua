local T=require("test_helper")
local layout=require("game_over_layout")

T.test("Game Over buttons are vertical and stay between preview panels",function()
    local restart,home=layout.restart,layout.home
    T.equal(restart.x,home.x)
    T.truthy(restart.y<home.y)
    for _,button in ipairs({restart,home}) do
        local left=button.x-button.width/2
        local right=button.x+button.width/2
        local top=button.y-button.height/2
        local bottom=button.y+button.height/2
        T.truthy(left>=180 and right<=323)
        T.truthy(top>=167 and bottom<=307)
    end
end)
