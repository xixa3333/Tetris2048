-- Public account IDs are kept separate from Firebase's email-based transport.
-- This module is pure so validation and legacy-account compatibility stay testable.
local AccountIdentity={}
local DOMAIN="users.tetris2048.app"

local function trim(value) return (value or ""):match("^%s*(.-)%s*$") end
local function isEmail(value) return value:match("^[^%s@]+@[^%s@]+%.[^%s@]+$")~=nil end

function AccountIdentity.normalize(value)
    return trim(value):lower()
end

function AccountIdentity.validate(value)
    local id=AccountIdentity.normalize(value)
    if #id<3 or #id>20 then return nil,"帳號 ID 需為 3 到 20 個字元" end
    if not id:match("^[a-z0-9][a-z0-9_.%-]*$") then
        return nil,"帳號 ID 只能使用英文字母、數字、底線、句點與連字號"
    end
    return id
end

function AccountIdentity.toEmail(value)
    local id,message=AccountIdentity.validate(value)
    if not id then return nil,message end
    return id.."@"..DOMAIN,id
end

function AccountIdentity.forSignIn(value)
    local normalized=AccountIdentity.normalize(value)
    if isEmail(normalized) then return normalized,normalized,true end
    local email,idOrMessage=AccountIdentity.toEmail(normalized)
    if not email then return nil,idOrMessage,false end
    return email,idOrMessage,false
end

function AccountIdentity.fromEmail(email)
    local normalized=AccountIdentity.normalize(email)
    return normalized:match("^(.+)@"..DOMAIN:gsub("%.","%%.").."$") or normalized
end

function AccountIdentity.isLegacyEmail(value)
    local normalized=AccountIdentity.normalize(value)
    return isEmail(normalized) and not normalized:match("@"..DOMAIN:gsub("%.","%%.").."$")
end

return AccountIdentity
