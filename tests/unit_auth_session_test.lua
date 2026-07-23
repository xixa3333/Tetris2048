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
T.test("ID registration uses internal email and keeps only the public ID",function()
    local http={}
    function http:request(_,_,body,_,callback)
        T.equal(body.email,"player_01@users.tetris2048.app")
        callback(true,{localId="uid",email=body.email,idToken="token",refreshToken="refresh"},200)
    end
    local auth=AuthService.new(http,{apiKey="key"})
    auth:register("Player_01","123456",function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().account,"player_01")
end)
T.test("Legacy email cannot register but can sign in and migrate to a unique ID",function()
    local requests={}; local auth
    local http={}
    function http:request(_,url,body,_,callback)
        requests[#requests+1]=body
        if url:match("signInWithPassword") then
            callback(true,{localId="uid",email=body.email,idToken="old",refreshToken="old-refresh"},200)
        else callback(true,{email=body.email,idToken="new",refreshToken="new-refresh"},200) end
    end
    auth=AuthService.new(http,{apiKey="key"})
    auth:register("old@example.com","123456",function(ok) T.equal(ok,false) end)
    auth:signIn("old@example.com","123456",function(ok) T.equal(ok,true) end)
    auth:changeAccount("new_id",function(ok) T.equal(ok,true) end)
    T.equal(requests[2].email,"new_id@users.tetris2048.app")
    T.equal(auth:currentUser().account,"new_id")
end)
T.test("Account ID update reports a uniqueness collision without changing the session",function()
    local http={}
    function http:request(_,_,_,_,callback) callback(false,{error={message="EMAIL_EXISTS"}},400) end
    local auth=AuthService.new(http,{apiKey="key"})
    auth.session={uid="u",account="current_id",idToken="token",refreshToken="refresh"}
    auth:changeAccount("taken_id",function(ok,message)
        T.equal(ok,false); T.equal(message,"這個帳號已被使用")
    end)
    T.equal(auth:currentUser().account,"current_id")
end)
T.test("Password reset refuses ID accounts because no personal email is stored",function()
    local auth=AuthService.new({}, {apiKey="key"})
    auth:sendPasswordReset("player_01",function(ok,message)
        T.equal(ok,false); T.truthy(message:match("沒有信箱"))
    end)
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
