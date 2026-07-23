local AccountIdentity=require("account_identity")
local AuthService={}; AuthService.__index=AuthService
local ERRORS={EMAIL_EXISTS="這個帳號已被使用",EMAIL_NOT_FOUND="找不到這個帳號",
    INVALID_LOGIN_CREDENTIALS="帳號或密碼錯誤",INVALID_PASSWORD="帳號或密碼錯誤",
    WEAK_PASSWORD="密碼至少需要 6 個字元",INVALID_EMAIL="帳號 ID 格式不正確",
    CREDENTIAL_TOO_OLD_LOGIN_AGAIN="為了安全，請重新登入後再修改資料"}
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
    local code=data.error and data.error.message or "NETWORK_ERROR"
    return ERRORS[code] or fallback or "登入服務暫時無法使用"
end
function AuthService:_authenticate(action,account,password,allowLegacy,callback)
    local email,publicAccount,isLegacy=AccountIdentity.forSignIn(account)
    if not email then callback(false,publicAccount); return end
    if isLegacy and not allowLegacy then callback(false,"新帳號請使用一般 ID，不需輸入電子郵件"); return end
    if #(password or "")<6 then callback(false,"密碼至少需要 6 個字元"); return end
    local url="https://identitytoolkit.googleapis.com/v1/accounts:"..action.."?key="..self.config.apiKey
    self.http:request("POST",url,{email=email,password=password,returnSecureToken=true},nil,function(ok,data)
        if not ok then callback(false,self:_message(data)); return end
        local session={uid=data.localId,account=AccountIdentity.fromEmail(data.email),idToken=data.idToken,refreshToken=data.refreshToken}
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
        local session={uid=data.user_id,account=saved.account,idToken=data.id_token,refreshToken=data.refresh_token}
        self:_save(session); callback(true,session)
    end)
end

function AuthService:sendPasswordReset(account,callback)
    if not AccountIdentity.isLegacyEmail(account) then
        callback(false,"一般 ID 沒有信箱，請登入後修改密碼"); return
    end
    local email=AccountIdentity.normalize(account)
    local url="https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key="..self.config.apiKey
    self.http:request("POST",url,{requestType="PASSWORD_RESET",email=email},nil,function(ok,data)
        if ok then callback(true,"密碼重設信已寄出") else callback(false,self:_message(data,"無法寄出重設信")) end
    end)
end

function AuthService:changeAccount(account,callback)
    if not self.session then callback(false,"請先登入"); return end
    local email,idOrMessage=AccountIdentity.toEmail(account)
    if not email then callback(false,idOrMessage); return end
    local url="https://identitytoolkit.googleapis.com/v1/accounts:update?key="..self.config.apiKey
    self.http:request("POST",url,{idToken=self.session.idToken,email=email,returnSecureToken=true},nil,function(ok,data)
        if not ok then callback(false,self:_message(data,"帳號 ID 修改失敗")); return end
        self.session.account=idOrMessage
        self.session.idToken=data.idToken or self.session.idToken
        self.session.refreshToken=data.refreshToken or self.session.refreshToken
        self:_save(self.session); callback(true,"帳號 ID 已修改")
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
