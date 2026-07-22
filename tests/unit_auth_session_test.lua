local T=require("test_helper")
local AuthService=require("auth_service")
local SessionStore=require("session_store")

local function storage()
    local value={}; return {load=function() return value end,save=function(_,data) value=data end,peek=function() return value end}
end
T.test("Session store persists refresh token but never password or ID token",function()
    local raw=storage(); local store=SessionStore.new(raw)
    store:save({account="a@example.com",refreshToken="refresh",idToken="secret",password="password"})
    T.equal(raw:peek().refreshToken,"refresh"); T.equal(raw:peek().account,"a@example.com")
    T.equal(raw:peek().password,nil); T.equal(raw:peek().idToken,nil)
end)
T.test("Auth restores remembered login with refresh token",function()
    local raw=storage(); raw:save({account="a@example.com",refreshToken="old"})
    local http={}
    function http:requestForm(method,url,body,callback)
        T.truthy(body:match("grant_type=refresh_token")); callback(true,{user_id="u",id_token="id",refresh_token="new"},200)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:restoreSession(function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().uid,"u"); T.equal(raw:peek().refreshToken,"new")
end)
T.test("Forgot password sends PASSWORD_RESET without exposing password",function()
    local http={}
    function http:request(method,url,body,headers,callback)
        T.equal(body.requestType,"PASSWORD_RESET"); T.equal(body.email,"a@example.com"); T.equal(body.password,nil)
        callback(true,{},200)
    end
    local auth=AuthService.new(http,{apiKey="key"})
    auth:sendPasswordReset("A@example.com",function(ok) T.equal(ok,true) end)
end)
T.test("Password change replaces remembered refresh token",function()
    local raw=storage(); local http={}
    function http:request(method,url,body,headers,callback)
        T.equal(body.idToken,"old-id"); T.equal(body.returnSecureToken,true)
        callback(true,{idToken="new-id",refreshToken="new-refresh"},200)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth.session={uid="u",account="a@example.com",idToken="old-id",refreshToken="old-refresh"}
    auth:changePassword("123456",function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().idToken,"new-id"); T.equal(raw:peek().refreshToken,"new-refresh")
end)
