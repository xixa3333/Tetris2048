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

local function formEncode(value)
    return tostring(value):gsub("([^%w%-_%.~])",function(char) return string.format("%%%02X",string.byte(char)) end)
end

function AuthService.new(http,config,sessionStore)
    return setmetatable({http=http,config=config,sessionStore=sessionStore,session=nil},AuthService)
end

function AuthService:isSignedIn() return self.session~=nil end
function AuthService:currentUser() return self.session end

function AuthService:_save(session)
    self.session=session
    if self.sessionStore then self.sessionStore:save(session) end
end

function AuthService:signOut()
    self.session=nil
    if self.sessionStore then self.sessionStore:clear() end
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

function AuthService:restoreSession(callback)
    local saved=self.sessionStore and self.sessionStore:load()
    if not saved then callback(false,"NO_SESSION"); return end
    local body="grant_type=refresh_token&refresh_token="..formEncode(saved.refreshToken)
    local url="https://securetoken.googleapis.com/v1/token?key="..self.config.apiKey
    self.http:requestForm("POST",url,body,function(ok,data)
        if not ok then self:signOut(); callback(false,"SESSION_EXPIRED"); return end
        local legacy=saved.isLegacy==true or AccountIdentity.isLegacyEmail(saved.account)
        local authEmail=saved.authEmail
        if not authEmail then
            if legacy then authEmail=AccountIdentity.normalize(saved.account)
            else authEmail=AccountIdentity.toEmail(saved.account) end
        end
        local session={uid=data.user_id,account=saved.account,authEmail=authEmail,
            isLegacy=legacy,idToken=data.id_token,refreshToken=data.refresh_token}
        self:_save(session); callback(true,session)
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
