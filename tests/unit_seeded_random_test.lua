local T=require("test_helper")
local SeededRandom=require("seeded_random")

T.test("Equal seeds reproduce the same bounded random sequence",function()
    local first,second=SeededRandom.new("friends-01"),SeededRandom.new("friends-01")
    for _=1,100 do T.equal(first(1,97),second(1,97)) end
end)
T.test("Different seeds diverge and every boundary remains valid",function()
    local first,second=SeededRandom.new("A"),SeededRandom.new("B"); local differs=false
    for _=1,1000 do
        local a,b=first(3,8),second(3,8); T.truthy(a>=3 and a<=8); T.truthy(b>=3 and b<=8)
        if a~=b then differs=true end
    end
    T.equal(differs,true)
end)
T.test("Random factory resets seeded games and preserves unseeded fallback",function()
    local settings={get=function() return {seed="same"} end}; local factory=SeededRandom.factory(settings)
    T.equal(factory()(1,100),factory()(1,100))
    local fallback=function() return 7 end; settings.get=function() return {seed=""} end
    T.equal(SeededRandom.factory(settings,fallback)(),fallback)
end)
T.test("A published seed keeps producing the same piece order across releases",function()
    local stream=SeededRandom.new("friends-01"); local drawn={}
    for _=1,6 do drawn[#drawn+1]=stream(1,7) end
    -- 玩家用同一組種子挑戰同一關，改版時這串順序不可以改變。
    T.equal(table.concat(drawn,","),"7,5,7,4,2,7")
    local other=SeededRandom.new("friends-02"); local otherDrawn={}
    for _=1,6 do otherDrawn[#otherDrawn+1]=other(1,7) end
    T.equal(table.concat(otherDrawn,","),"7,5,1,1,1,6")
end)
T.test("Calling the generator without bounds returns a repeatable unit fraction",function()
    local stream=SeededRandom.new("friends-01")
    local first,second=stream(),stream()
    T.equal(string.format("%.9f",first),"0.788085923")
    T.equal(string.format("%.9f",second),"0.360108944")
    T.equal(first>=0 and first<1,true)
    local repeated=SeededRandom.new("friends-01")
    T.equal(repeated(),first)
end)
