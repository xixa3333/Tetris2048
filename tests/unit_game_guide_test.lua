local T=require("test_helper")
local guide=require("game_guide")

T.test("Game guide explains rules, scoring, controls, then leaderboards",function()
    local expected={"遊戲規則","得分機制","遊玩方式","排行榜"}
    T.equal(#guide,#expected)
    for index,title in ipairs(expected) do T.equal(guide[index].title,title) end
    T.truthy(guide[1].body:match("10×10"))
    T.truthy(guide[1].body:match("模式1"))
    T.truthy(guide[1].body:match("模式2"))
    T.truthy(guide[2].body:match("10 分"))
    T.truthy(guide[2].body:match("放置新方塊"))
    for _,control in ipairs({"W/A/S/D","R","Space"}) do T.truthy(guide[3].body:match(control)) end
    T.truthy(guide[4].body:match("本機排行榜"))
    T.truthy(guide[4].body:match("全球排行榜"))
    T.truthy(guide[4].body:match("模式1與模式2"))
end)
