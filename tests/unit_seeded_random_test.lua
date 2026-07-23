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
