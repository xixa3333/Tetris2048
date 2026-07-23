-- UTF-8 aware nickname normalization shared by profile writes and tests.
local NicknamePolicy={}

local function utf8Length(value)
    local count,index=0,1
    while index<=#value do
        local first=value:byte(index)
        local width
        if first<0x80 then width=1
        elseif first>=0xC2 and first<=0xDF then width=2
        elseif first>=0xE0 and first<=0xEF then width=3
        elseif first>=0xF0 and first<=0xF4 then width=4
        else return nil end
        if index+width-1>#value then return nil end
        for offset=1,width-1 do
            local byte=value:byte(index+offset)
            if byte<0x80 or byte>0xBF then return nil end
        end
        count,index=count+1,index+width
    end
    return count
end

function NicknamePolicy.validate(value)
    local nickname=tostring(value or ""):match("^%s*(.-)%s*$")
    if nickname:find("[%z\1-\31\127]") then return nil,"暱稱不能包含換行或控制字元" end
    local length=utf8Length(nickname)
    if not length then return nil,"暱稱包含無效字元" end
    if length<2 or length>16 then return nil,"暱稱需為 2 到 16 個字元" end
    return nickname
end

function NicknamePolicy.length(value) return utf8Length(tostring(value or "")) end

return NicknamePolicy
