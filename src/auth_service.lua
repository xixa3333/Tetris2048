local AccountIdentity=require("account_identity")
local AuthService={}; AuthService.__index=AuthService

local ERRORS={
    EMAIL_EXISTS="帳號 ID 已被使用",
    EMAIL_NOT_FOUND="找不到這個帳號",
    INVALID_LOGIN_CREDENTIALS="帳號或密碼錯誤",
    INVALID_PASSWORD="帳號或密碼錯誤",
    WEAK_PASSWORD="密碼至少需要 6 個字元",
    INVALID_EMAIL="帳號 ID 格式不正確",
    CREDENTIAL_TOO_OLD_LOGIN_AGAIN="登入已過期，請重新登入後再修改資料"
}

-- 只有伺服器明確拒絕（4xx）才代表憑證失效；連不上網路或伺服器暫時故障時
-- 必須保留 refresh token，否則玩家離線開一次遊戲就被登出。
local function isRejected(status)
    local code=tonumber(status) or 0
    return code>=400 and code<500
end

local function formEncode(value)
    return tostring(value):gsub("([^%w%-_%.~])",function(char) return string.format("%%%02X",string.byte(char)) end)
end

function AuthService.new(http,config,sessionStore,accountStore)
    return setmetatable({http=http,config=config,sessionStore=sessionStore,
        accountStore=accountStore,session=nil},AuthService)
end

function AuthService:isSignedIn() return self.session~=nil end
-- 離線快捷登入：身分沿用上次登入結果，但沒有 idToken，雲端操作會被伺服器擋下。
function AuthService:isOffline() return self.session~=nil and self.session.offline==true end
-- 暱稱要寫回 session.json，離線快捷登入才顯示得出玩家名稱。
-- 這裡不比對記憶體中的值：呼叫端可能已經先設過 session.nickname，
-- 比對會讓「記憶體有、檔案沒有」的情況永遠補寫不進去。
function AuthService:rememberNickname(nickname)
    if not self.session or type(nickname)~="string" or nickname=="" then return end
    self.session.nickname=nickname
    if not self.session.offline then self:_save(self.session) end
end
function AuthService:currentUser() return self.session end

function AuthService:_save(session)
    self.session=session
    if self.sessionStore then self.sessionStore:save(session) end
    -- 有憑證才記進快捷登入清單；本機身分不該被當成可直接登入的帳號。
    if self.accountStore and session.uid and session.refreshToken then
        self.accountStore:remember({uid=session.uid,account=session.account,nickname=session.nickname,
            authEmail=session.authEmail,isLegacy=session.isLegacy,refreshToken=session.refreshToken})
    end
end

function AuthService:signOut()
    local uid=self.session and self.session.uid
    self.session=nil
    if self.sessionStore then self.sessionStore:clear() end
    -- 登出只丟掉這個帳號的憑證，快捷登入清單仍保留身分。
    if self.accountStore and uid then self.accountStore:clearCredential(uid) end
end

local function describe(entry)
    return {uid=entry.uid,account=entry.account,nickname=entry.nickname,
        authEmail=entry.authEmail,isLegacy=entry.isLegacy==true,
        hasCredential=entry.refreshToken~=nil,
        name=entry.nickname or entry.account or entry.uid}
end

-- 這台裝置記住的帳號，由新到舊。只回傳公開識別，不外流憑證。
function AuthService:rememberedAccounts()
    local accounts={}
    for _,entry in ipairs(self.accountStore and self.accountStore:list() or {}) do
        accounts[#accounts+1]=describe(entry)
    end
    if #accounts>0 then return accounts end
    -- 舊版只在 session.json 記過一個帳號，仍要能出現在快捷登入清單裡。
    local saved=self.sessionStore and self.sessionStore:load()
    if saved and saved.uid then accounts[1]=describe(saved) end
    return accounts
end

function AuthService:rememberedAccount()
    return self:rememberedAccounts()[1]
end

-- 移除快捷登入選項；如果移掉的正是目前登入中的帳號就一併登出。
function AuthService:forgetAccount(uid)
    if self.accountStore then self.accountStore:forget(uid) end
    if self.session and self.session.uid==uid then
        self.session=nil
        if self.sessionStore then self.sessionStore:forget() end
    elseif not self.accountStore then
        if self.sessionStore then self.sessionStore:forget() end
    end
end

-- 只忘記這台裝置記住的帳號，不會刪除雲端帳號，也不會動到排行榜紀錄。
function AuthService:forgetRememberedAccount()
    self.session=nil
    if self.sessionStore then self.sessionStore:forget() end
end

-- 快捷登入：有憑證就換成完整登入，換不到（離線或已登出）就退回本機身分。
-- 本機身分沒有 idToken，任何雲端寫入都會被伺服器擋下，只能讀寫本機排行榜。
function AuthService:signInWithAccount(uid,callback)
    local entry=self.accountStore and self.accountStore:find(uid)
    local saved=entry and describe(entry)
    if not saved then
        local fallback=self:rememberedAccount()
        if fallback and fallback.uid==uid then saved=fallback end
    end
    if not saved then callback(false,"找不到這個快捷登入帳號"); return end
    if not saved.hasCredential then callback(self:_useRememberedIdentity(saved)); return end
    local token=entry and entry.refreshToken
    if not token then
        local stored=self.sessionStore and self.sessionStore:load()
        token=stored and stored.refreshToken
    end
    self:_exchangeToken(token,saved,function(ok,result)
        if ok then callback(true,result); return end
        if result=="SESSION_EXPIRED" then callback(false,"登入已過期，請輸入密碼重新登入"); return end
        callback(self:_useRememberedIdentity(saved))
    end)
end

function AuthService:signInWithRemembered(callback)
    local saved=self:rememberedAccount()
    if not saved then callback(false,"這台裝置沒有登入過的帳號"); return end
    self:signInWithAccount(saved.uid,callback)
end

function AuthService:_useRememberedIdentity(saved)
    self.session={uid=saved.uid,account=saved.account,nickname=saved.nickname,
        authEmail=saved.authEmail,isLegacy=saved.isLegacy,offline=true}
    return true,self.session
end

function AuthService:_message(data,fallback)
    local code=data and data.error and data.error.message or "NETWORK_ERROR"
    return ERRORS[code] or fallback or "連線失敗，請稍後再試"
end

function AuthService:_authenticate(action,account,password,allowLegacy,callback)
    local email,publicAccount,isLegacy=AccountIdentity.forSignIn(account)
    if not email then callback(false,publicAccount); return end
    if isLegacy and not allowLegacy then callback(false,"請使用帳號 ID 註冊；舊電子信箱帳號只能登入後轉換"); return end
    if #(password or "")<6 then callback(false,"密碼至少需要 6 個字元"); return end
    local url="https://identitytoolkit.googleapis.com/v1/accounts:"..action.."?key="..self.config.apiKey
    self.http:request("POST",url,{email=email,password=password,returnSecureToken=true},nil,function(ok,data)
        if not ok then callback(false,self:_message(data)); return end
        local authEmail=AccountIdentity.normalize(data.email)
        local session={uid=data.localId,account=AccountIdentity.fromEmail(authEmail),authEmail=authEmail,
            isLegacy=AccountIdentity.isLegacyEmail(authEmail),idToken=data.idToken,refreshToken=data.refreshToken}
        self:_save(session); callback(true,session)
    end)
end

function AuthService:register(account,password,callback) self:_authenticate("signUp",account,password,false,callback) end
function AuthService:signIn(account,password,callback) self:_authenticate("signInWithPassword",account,password,true,callback) end

-- 換發憑證。自動登入與快捷登入共用同一段流程，差別只在用哪一筆帳號的 token。
function AuthService:_exchangeToken(refreshToken,saved,callback)
    if not refreshToken then callback(false,"NO_SESSION"); return end
    local body="grant_type=refresh_token&refresh_token="..formEncode(refreshToken)
    local url="https://securetoken.googleapis.com/v1/token?key="..self.config.apiKey
    self.http:requestForm("POST",url,body,function(ok,data,status)
        if not ok then
            if isRejected(status) then
                -- 伺服器明確拒絕才代表憑證失效，這時要丟掉憑證但保留身分。
                if self.sessionStore and (not self.session or self.session.uid==saved.uid) then self.sessionStore:clear() end
                if self.accountStore and saved.uid then self.accountStore:clearCredential(saved.uid) end
                if self.session and self.session.uid==saved.uid then self.session=nil end
                callback(false,"SESSION_EXPIRED"); return
            end
            callback(false,"NETWORK_UNAVAILABLE"); return
        end
        local legacy=saved.isLegacy==true or AccountIdentity.isLegacyEmail(saved.account)
        local authEmail=saved.authEmail
        if not authEmail then
            if legacy then authEmail=AccountIdentity.normalize(saved.account)
            else authEmail=AccountIdentity.toEmail(saved.account) end
        end
        local session={uid=data.user_id or saved.uid,account=saved.account,nickname=saved.nickname,
            authEmail=authEmail,isLegacy=legacy,idToken=data.id_token,refreshToken=data.refresh_token}
        self:_save(session); callback(true,session)
    end)
end

function AuthService:restoreSession(callback)
    local saved=self.sessionStore and self.sessionStore:load()
    -- 已登出的裝置只剩身分沒有憑證，不自動登入；玩家要按快捷登入才會用本機身分。
    if not saved or not saved.refreshToken then callback(false,"NO_SESSION"); return end
    self:_exchangeToken(saved.refreshToken,saved,function(ok,result)
        if ok then callback(true,result); return end
        if result=="SESSION_EXPIRED" then callback(false,"SESSION_EXPIRED"); return end
        -- 連不上伺服器：沿用記住的身分做快捷登入，並保留 refresh token 下次再換。
        if not saved.uid then callback(false,"NETWORK_UNAVAILABLE"); return end
        local remembered={uid=saved.uid,account=saved.account,nickname=saved.nickname,
            authEmail=saved.authEmail,
            isLegacy=saved.isLegacy==true or AccountIdentity.isLegacyEmail(saved.account)}
        callback(self:_useRememberedIdentity(remembered))
    end)
end

function AuthService:sendPasswordReset(account,callback)
    if not AccountIdentity.isLegacyEmail(account) then
        callback(false,"ID 帳號沒有可收信的電子信箱。基於帳號安全，請登入後在排行榜頁修改密碼，或聯絡作者協助處理。")
        return
    end
    local email=AccountIdentity.normalize(account)
    local url="https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key="..self.config.apiKey
    self.http:request("POST",url,{requestType="PASSWORD_RESET",email=email},nil,function(ok,data)
        if ok then callback(true,"已寄出忘記密碼信，請到信箱收信")
        else callback(false,self:_message(data,"忘記密碼信寄送失敗")) end
    end)
end

function AuthService:beginLegacyMigration(account,password,callback)
    local current=self.session
    if not current or not current.isLegacy then callback(false,"目前不是舊電子信箱帳號"); return end
    local targetEmail,idOrMessage=AccountIdentity.toEmail(account)
    if not targetEmail then callback(false,idOrMessage); return end
    if #(password or "")<6 then callback(false,"請輸入目前密碼"); return end
    local signInUrl="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="..self.config.apiKey
    self.http:request("POST",signInUrl,{email=current.authEmail or current.account,password=password,returnSecureToken=true},nil,function(ok,data)
        if not ok or data.localId~=current.uid then callback(false,self:_message(data,"目前密碼驗證失敗")); return end
        local oldUser={uid=data.localId,account=current.account,authEmail=data.email,
            isLegacy=true,nickname=current.nickname,idToken=data.idToken,refreshToken=data.refreshToken}
        local signUpUrl="https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="..self.config.apiKey
        self.http:request("POST",signUpUrl,{email=targetEmail,password=password,returnSecureToken=true},nil,function(created,result)
            if not created then callback(false,self:_message(result,"帳號 ID 建立失敗")); return end
            local newUser={uid=result.localId,account=idOrMessage,authEmail=result.email,isLegacy=false,
                nickname=current.nickname,idToken=result.idToken,refreshToken=result.refreshToken}
            self.session=newUser
            callback(true,{oldUser=oldUser,newUser=newUser})
        end)
    end)
end

function AuthService:commitLegacyMigration()
    if self.session then self:_save(self.session) end
end

function AuthService:rollbackLegacyMigration(context,callback)
    local newUser=context and context.newUser; local oldUser=context and context.oldUser
    if not newUser or not oldUser then callback(false); return end
    local url="https://identitytoolkit.googleapis.com/v1/accounts:delete?key="..self.config.apiKey
    self.http:request("POST",url,{idToken=newUser.idToken},nil,function()
        self:_save(oldUser); callback(true)
    end)
end

-- 刪除 Firebase 帳號本身。呼叫前必須先刪掉雲端資料，因為刪帳號後就沒有憑證了。
function AuthService:deleteAccount(callback)
    if not self.session or not self.session.idToken then
        callback(false,"請先在有網路時重新登入，才能刪除帳號"); return
    end
    local url="https://identitytoolkit.googleapis.com/v1/accounts:delete?key="..self.config.apiKey
    self.http:request("POST",url,{idToken=self.session.idToken},nil,function(ok,data)
        if not ok then callback(false,self:_message(data,"帳號刪除失敗")); return end
        self.session=nil
        if self.sessionStore then self.sessionStore:forget() end
        callback(true,"帳號已刪除")
    end)
end

function AuthService:changePassword(password,callback)
    if not self.session then callback(false,"請先登入"); return end
    if #(password or "")<6 then callback(false,"密碼至少需要 6 個字元"); return end
    local url="https://identitytoolkit.googleapis.com/v1/accounts:update?key="..self.config.apiKey
    self.http:request("POST",url,{idToken=self.session.idToken,password=password,returnSecureToken=true},nil,function(ok,data)
        if not ok then callback(false,self:_message(data,"密碼修改失敗")); return end
        self.session.idToken=data.idToken or self.session.idToken
        self.session.refreshToken=data.refreshToken or self.session.refreshToken
        self:_save(self.session); callback(true,"密碼已修改")
    end)
end

return AuthService
