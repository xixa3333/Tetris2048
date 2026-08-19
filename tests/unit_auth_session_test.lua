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

T.test("Forgot password sends PASSWORD_RESET for legacy email without exposing password",function()
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

T.test("Legacy email reauthenticates then creates a permanent ID account",function()
    local requests={}
    local http={}
    function http:request(_,url,body,_,callback)
        requests[#requests+1]=body
        if url:match("signInWithPassword") then
            callback(true,{localId="uid",email=body.email,idToken="old",refreshToken="old-refresh"},200)
        else callback(true,{localId="new-uid",email=body.email,idToken="new",refreshToken="new-refresh"},200) end
    end
    local auth=AuthService.new(http,{apiKey="key"})
    auth:signIn("old@example.com","123456",function(ok) T.equal(ok,true) end)
    auth:beginLegacyMigration("new_id","123456",function(ok,context)
        T.equal(ok,true); T.equal(context.oldUser.uid,"uid"); T.equal(context.newUser.uid,"new-uid")
        -- 回滾時要還原成「仍是舊電子信箱帳號」，下次進遊戲才會再提示轉換。
        T.equal(context.oldUser.isLegacy,true); T.equal(context.newUser.isLegacy,false)
    end)
    T.equal(requests[3].email,"new_id@users.tetris2048.app")
    T.equal(auth:currentUser().account,"new_id")
end)

T.test("Old remembered email session is recognized as legacy after upgrading",function()
    local raw=storage(); raw:save({account="old@example.com",refreshToken="old"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(true,{user_id="u",id_token="id",refresh_token="new"},200) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:restoreSession(function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().isLegacy,true); T.equal(auth:currentUser().authEmail,"old@example.com")
end)

T.test("Old remembered ID session reconstructs its synthetic auth address",function()
    local raw=storage(); raw:save({account="player_01",refreshToken="old"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(true,{user_id="u",id_token="id",refresh_token="new"},200) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:restoreSession(function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().isLegacy,false)
    T.equal(auth:currentUser().authEmail,"player_01@users.tetris2048.app")
end)

T.test("Legacy migration reports a permanent ID collision without changing the session",function()
    local http={calls=0}
    function http:request(_,url,body,_,callback)
        self.calls=self.calls+1
        if url:match("signInWithPassword") then callback(true,{localId="u",email="old@example.com",idToken="fresh",refreshToken="r"},200)
        else callback(false,{error={message="EMAIL_EXISTS"}},400) end
    end
    local auth=AuthService.new(http,{apiKey="key"})
    auth.session={uid="u",account="old@example.com",authEmail="old@example.com",isLegacy=true,idToken="token",refreshToken="refresh"}
    auth:beginLegacyMigration("taken_id","123456",function(ok,message)
        T.equal(ok,false); T.equal(message,"帳號 ID 已被使用")
    end)
    T.equal(auth:currentUser().account,"old@example.com")
end)

T.test("Password reset refuses ID accounts because no personal email is stored",function()
    local auth=AuthService.new({}, {apiKey="key"})
    auth:sendPasswordReset("player_01",function(ok,message)
        T.equal(ok,false); T.truthy(message:match("沒有可收信"))
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

T.test("Restored sessions keep the legacy flag recorded at login time",function()
    local raw=storage(); raw:save({account="player_01",authEmail="old@example.com",refreshToken="old",isLegacy=true})
    local http={}
    function http:requestForm(_,_,_,callback) callback(true,{user_id="u",id_token="id",refresh_token="new"},200) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:restoreSession(function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().isLegacy,true)
    T.equal(auth:currentUser().authEmail,"old@example.com")
    local fresh=storage(); fresh:save({account="player_02",refreshToken="old"})
    local modern=AuthService.new(http,{apiKey="key"},SessionStore.new(fresh))
    modern:restoreSession(function(ok) T.equal(ok,true) end)
    T.equal(modern:currentUser().isLegacy,false)
    T.equal(modern:currentUser().authEmail,"player_02@users.tetris2048.app")
end)

T.test("Account migration always requests a secure token for the new ID account",function()
    local bodies={}
    local http={}
    function http:request(_,url,body,_,callback)
        bodies[#bodies+1]={url=url,body=body}
        callback(true,{localId=url:match("signUp") and "new-uid" or "uid",email=body.email,
            idToken="token",refreshToken="refresh"},200)
    end
    local auth=AuthService.new(http,{apiKey="key"})
    auth:signIn("old@example.com","123456",function() end)
    auth:beginLegacyMigration("new_id","123456",function(ok) T.equal(ok,true) end)
    T.equal(#bodies,3)
    -- 重新驗證與建立新帳號都必須換到安全權杖，否則遷移後的 session 會失效。
    T.equal(bodies[2].body.returnSecureToken,true)
    T.truthy(bodies[3].url:match("signUp"))
    T.equal(bodies[3].body.returnSecureToken,true)
    T.equal(bodies[3].body.email,"new_id@users.tetris2048.app")
end)

T.test("A rejected sign-in never creates a session",function()
    local http={}
    function http:request(_,_,_,_,callback) callback(false,{error={message="INVALID_LOGIN_CREDENTIALS"}},400) end
    local auth=AuthService.new(http,{apiKey="key"})
    local reported
    auth:signIn("player_01","123456",function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.equal(reported.message,"帳號或密碼錯誤")
    T.equal(auth:isSignedIn(),false); T.equal(auth:currentUser(),nil)
end)

T.test("Migration validates the new ID before touching the network",function()
    local http={calls=0}
    function http:request() self.calls=self.calls+1 end
    local auth=AuthService.new(http,{apiKey="key"})
    auth.session={uid="uid",account="old@example.com",authEmail="old@example.com",isLegacy=true}
    local reported
    auth:beginLegacyMigration("ab","123456",function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.truthy(reported.message); T.equal(http.calls,0)
    auth:beginLegacyMigration("new_id","123",function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.equal(reported.message,"請輸入目前密碼"); T.equal(http.calls,0)
end)

T.test("A failed migration deletes the new account and restores the old session",function()
    local http={bodies={}}
    function http:request(_,url,body,_,callback)
        self.bodies[#self.bodies+1]={url=url,body=body}; callback(true,{},200)
    end
    local auth=AuthService.new(http,{apiKey="key"})
    local oldUser={uid="uid",account="old@example.com",isLegacy=true,idToken="old"}
    local restored
    auth.session={uid="new-uid",account="new_id",isLegacy=false,idToken="new"}
    auth:rollbackLegacyMigration({oldUser=oldUser,newUser={idToken="new"}},function(ok) restored=ok end)
    T.equal(restored,true); T.equal(auth:currentUser().account,"old@example.com")
    T.truthy(http.bodies[1].url:match("accounts:delete"))
    T.equal(http.bodies[1].body.idToken,"new")
    local incomplete
    auth:rollbackLegacyMigration(nil,function(ok) incomplete=ok end)
    T.equal(incomplete,false)
end)

T.test("Going offline keeps the remembered login for the next attempt",function()
    local raw=storage(); raw:save({account="player_01",refreshToken="keep-me"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(false,{},nil) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    local reported
    auth:restoreSession(function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.equal(reported.message,"NETWORK_UNAVAILABLE")
    T.equal(raw:peek().refreshToken,"keep-me")

    local serverDown={}
    function serverDown:requestForm(_,_,_,callback) callback(false,{},503) end
    AuthService.new(serverDown,{apiKey="key"},SessionStore.new(raw)):restoreSession(function(ok,message)
        T.equal(ok,false); T.equal(message,"NETWORK_UNAVAILABLE")
    end)
    T.equal(raw:peek().refreshToken,"keep-me")
end)

T.test("A rejected refresh token is cleared so the player is asked to sign in again",function()
    local raw=storage(); raw:save({account="player_01",refreshToken="expired"})
    local http={}
    function http:requestForm(_,_,_,callback)
        callback(false,{error={message="TOKEN_EXPIRED"}},400)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    local reported
    auth:restoreSession(function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.equal(reported.message,"SESSION_EXPIRED")
    T.equal(raw:peek().refreshToken,nil); T.equal(auth:isSignedIn(),false)
end)

T.test("Offline start signs the player in with the identity from the last login",function()
    local raw=storage()
    raw:save({refreshToken="keep-me",uid="u1",account="player_01",nickname="玩家一"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(false,{},nil) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    local reported
    auth:restoreSession(function(ok,session) reported={ok=ok,session=session} end)
    T.equal(reported.ok,true)
    T.equal(auth:isSignedIn(),true); T.equal(auth:isOffline(),true)
    T.equal(auth:currentUser().uid,"u1"); T.equal(auth:currentUser().nickname,"玩家一")
    T.equal(auth:currentUser().idToken,nil)
    T.equal(raw:peek().refreshToken,"keep-me")
end)

T.test("Offline shortcut needs a remembered account and never survives a rejected token",function()
    local incomplete=storage(); incomplete:save({refreshToken="token"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(false,{},nil) end
    AuthService.new(http,{apiKey="key"},SessionStore.new(incomplete)):restoreSession(function(ok,message)
        T.equal(ok,false); T.equal(message,"NETWORK_UNAVAILABLE")
    end)
    local rejected=storage(); rejected:save({refreshToken="token",uid="u1",nickname="玩家一"})
    local denied={}
    function denied:requestForm(_,_,_,callback) callback(false,{},401) end
    local auth=AuthService.new(denied,{apiKey="key"},SessionStore.new(rejected))
    auth:restoreSession(function(ok,message) T.equal(ok,false); T.equal(message,"SESSION_EXPIRED") end)
    T.equal(auth:isSignedIn(),false); T.equal(rejected:peek().refreshToken,nil)
end)

T.test("A remembered nickname is stored for the next offline start",function()
    local raw=storage()
    local http={}
    function http:request(_,_,body,_,callback)
        callback(true,{localId="uid",email=body.email,idToken="token",refreshToken="refresh"},200)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:signIn("player_01","123456",function(ok) T.equal(ok,true) end)
    T.equal(raw:peek().uid,"uid"); T.equal(raw:peek().nickname,nil)
    auth:rememberNickname("玩家一")
    T.equal(raw:peek().nickname,"玩家一")
    T.equal(raw:peek().password,nil); T.equal(raw:peek().idToken,nil)
end)

T.test("Offline state is only reported for a real signed-in session",function()
    local http={}
    function http:requestForm() end
    local auth=AuthService.new(http,{apiKey="key"})
    T.equal(auth:isSignedIn(),false); T.equal(auth:isOffline(),false)
    auth.session={uid="u1",account="player_01"}
    T.equal(auth:isOffline(),false)
    auth.session.offline=true
    T.equal(auth:isOffline(),true)
    auth:signOut(); T.equal(auth:isOffline(),false)
end)

T.test("Signing out keeps the account for a shortcut while forgetting removes it",function()
    local raw=storage()
    raw:save({refreshToken="refresh",uid="u1",account="player_01",nickname="玩家一"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(false,{},nil) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))

    auth.session={uid="u1",account="player_01",refreshToken="refresh"}
    auth:signOut()
    T.equal(raw:peek().refreshToken,nil)
    local remembered=auth:rememberedAccount()
    T.equal(remembered.uid,"u1"); T.equal(remembered.nickname,"玩家一"); T.equal(remembered.hasCredential,false)

    -- 登出後不會自動登入，但快捷登入可以用本機身分繼續。
    auth:restoreSession(function(ok,message) T.equal(ok,false); T.equal(message,"NO_SESSION") end)
    auth:signInWithRemembered(function(ok) T.equal(ok,true) end)
    T.equal(auth:isOffline(),true); T.equal(auth:currentUser().nickname,"玩家一")

    auth:forgetAccount("u1")
    T.equal(auth:rememberedAccount(),nil); T.equal(auth:isSignedIn(),false)
    T.equal(raw:peek().uid,nil); T.equal(raw:peek().nickname,nil)
end)

T.test("A shortcut sign-in prefers the stored credential over the local identity",function()
    local raw=storage()
    raw:save({refreshToken="refresh",uid="u1",account="player_01",nickname="玩家一"})
    local http={}
    function http:requestForm(_,_,_,callback) callback(true,{user_id="u1",id_token="id",refresh_token="new"},200) end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:signInWithRemembered(function(ok) T.equal(ok,true) end)
    T.equal(auth:isOffline(),false); T.equal(auth:currentUser().idToken,"id")
    T.equal(raw:peek().refreshToken,"new")
end)

T.test("Forgetting the remembered account works without any network access",function()
    local raw=storage()
    raw:save({refreshToken="refresh",uid="u1",account="player_01",nickname="玩家一",isLegacy=false})
    local http={calls=0}
    function http:request() self.calls=self.calls+1 end
    function http:requestForm() self.calls=self.calls+1 end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    auth:forgetAccount("u1")
    T.equal(http.calls,0)
    T.equal(auth:rememberedAccount(),nil)
    T.equal(raw:peek().refreshToken,nil); T.equal(raw:peek().uid,nil)
    -- 沒有記住的帳號時，快捷登入必須失敗而不是放行。
    local reported
    auth:signInWithRemembered(function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.equal(reported.message,"這台裝置沒有登入過的帳號")
    T.equal(auth:isSignedIn(),false); T.equal(http.calls,0)
end)

T.test("Session storage records the legacy flag as a real boolean",function()
    local raw=storage(); local store=SessionStore.new(raw)
    store:save({refreshToken="refresh",uid="u1",account="old@example.com",isLegacy=true})
    T.equal(raw:peek().isLegacy,true)
    T.equal(store:load().isLegacy,true)
    store:save({refreshToken="refresh",uid="u1",account="player_01"})
    T.equal(raw:peek().isLegacy,false)
    store:clear()
    T.equal(raw:peek().isLegacy,false); T.equal(raw:peek().uid,"u1")
end)

T.test("Account deletion needs a live credential and clears the device",function()
    local raw=storage(); raw:save({refreshToken="refresh",uid="u1",account="player_01",nickname="玩家一"})
    local http={calls=0}
    function http:request(_,url,body,_,callback)
        self.calls=self.calls+1; self.url=url; self.body=body; callback(true,{},200)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw))
    local reported
    auth:deleteAccount(function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,false); T.equal(http.calls,0)

    auth.session={uid="u1",account="player_01",idToken="token"}
    auth:deleteAccount(function(ok,message) reported={ok=ok,message=message} end)
    T.equal(reported.ok,true); T.truthy(http.url:find("accounts:delete"))
    T.equal(http.body.idToken,"token")
    T.equal(auth:isSignedIn(),false); T.equal(auth:rememberedAccount(),nil)
    T.equal(raw:peek().uid,nil)
end)

T.test("Every signed-in account is remembered for the shortcut list",function()
    local AccountStore=require("account_store")
    local raw=storage(); local accountData={}
    local accountStorage={load=function() return accountData end,save=function(_,value) accountData=value end}
    local now=0
    local http={}
    function http:request(_,_,body,_,callback)
        callback(true,{localId=body.email:match("^([^@]+)"),email=body.email,
            idToken="id",refreshToken="refresh-"..body.email:match("^([^@]+)")},200)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw),
        AccountStore.new(accountStorage,function() now=now+1; return now end))
    auth:signIn("player_01","123456",function(ok) T.equal(ok,true) end)
    auth:signIn("player_02","123456",function(ok) T.equal(ok,true) end)
    local accounts=auth:rememberedAccounts()
    T.equal(#accounts,2)
    T.equal(accounts[1].account,"player_02"); T.equal(accounts[1].hasCredential,true)
    T.equal(accounts[2].account,"player_01"); T.equal(accounts[2].name,"player_01")
    for _,entry in ipairs(accountData.accounts) do
        T.equal(entry.password,nil); T.equal(entry.idToken,nil); T.truthy(entry.refreshToken)
    end
end)

T.test("A shortcut sign-in uses the credential stored for that account",function()
    local AccountStore=require("account_store")
    local accountData={accounts={
        {uid="u1",account="player_01",nickname="玩家一",refreshToken="token-1",lastLoginAt=2},
        {uid="u2",account="player_02",lastLoginAt=1}}}
    local accountStorage={load=function() return accountData end,save=function(_,value) accountData=value end}
    local raw=storage()
    local used
    local http={}
    function http:requestForm(_,_,body,callback)
        used=body
        callback(true,{user_id="u1",id_token="id",refresh_token="fresh"},200)
    end
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(raw),AccountStore.new(accountStorage))
    auth:signInWithAccount("u1",function(ok) T.equal(ok,true) end)
    T.truthy(used:find("token%-1"))
    T.equal(auth:isOffline(),false); T.equal(auth:currentUser().nickname,"玩家一")

    -- 沒有憑證的帳號只能取得本機身分。
    auth:signInWithAccount("u2",function(ok) T.equal(ok,true) end)
    T.equal(auth:isOffline(),true); T.equal(auth:currentUser().uid,"u2")
    auth:signInWithAccount("missing",function(ok,message)
        T.equal(ok,false); T.equal(message,"找不到這個快捷登入帳號")
    end)
end)

T.test("Signing out clears only the credential of the account that was in use",function()
    local AccountStore=require("account_store")
    local accountData={accounts={
        {uid="u1",account="player_01",refreshToken="token-1",lastLoginAt=2},
        {uid="u2",account="player_02",refreshToken="token-2",lastLoginAt=1}}}
    local accountStorage={load=function() return accountData end,save=function(_,value) accountData=value end}
    local http={}
    local auth=AuthService.new(http,{apiKey="key"},SessionStore.new(storage()),AccountStore.new(accountStorage))
    auth.session={uid="u1",account="player_01",refreshToken="token-1"}
    auth:signOut()
    local accounts=auth:rememberedAccounts()
    T.equal(#accounts,2)
    for _,entry in ipairs(accounts) do
        if entry.uid=="u1" then T.equal(entry.hasCredential,false) else T.equal(entry.hasCredential,true) end
    end
end)
