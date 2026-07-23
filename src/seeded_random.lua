-- Park-Miller PRNG. A fresh generator per game makes a seed replayable.
local SeededRandom={}
local MODULUS=2147483647

local function hash(seed)
    local value=1
    for index=1,#seed do value=(value*131+seed:byte(index))%(MODULUS-1) end
    return value+1
end
function SeededRandom.new(seed)
    local state=hash(tostring(seed))
    return function(minimum,maximum)
        state=(state*16807)%MODULUS
        if minimum==nil then return (state-1)/(MODULUS-1) end
        if maximum==nil then maximum=minimum; minimum=1 end
        return minimum+(state%(maximum-minimum+1))
    end
end
function SeededRandom.factory(settings,fallback)
    return function()
        local seed=settings:get().seed
        if seed~="" then return SeededRandom.new(seed) end
        return fallback or math.random
    end
end
return SeededRandom
