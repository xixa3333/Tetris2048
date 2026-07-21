local AuthService = {}
AuthService.__index = AuthService

local ERROR_TEXT = {
    EMAIL_EXISTS = "這個帳號已被使用",
    EMAIL_NOT_FOUND = "找不到這個帳號",
    INVALID_LOGIN_CREDENTIALS = "帳號或密碼錯誤",
    INVALID_PASSWORD = "帳號或密碼錯誤",
    WEAK_PASSWORD = "密碼至少需要 6 個字元",
    INVALID_EMAIL = "帳號必須是有效的電子郵件"
}

function AuthService.new(http, config)
    return setmetatable({http = http, config = config, session = nil}, AuthService)
end

function AuthService:isSignedIn() return self.session ~= nil end
function AuthService:currentUser() return self.session end
function AuthService:signOut() self.session = nil end

function AuthService:_authenticate(action, email, password, callback)
    email = (email or ""):lower():match("^%s*(.-)%s*$")
    if not email:match("^[^%s@]+@[^%s@]+%.[^%s@]+$") then
        callback(false, "帳號必須是有效的電子郵件")
        return
    end
    if #(password or "") < 6 then
        callback(false, "密碼至少需要 6 個字元")
        return
    end
    local url = "https://identitytoolkit.googleapis.com/v1/accounts:" .. action ..
        "?key=" .. self.config.apiKey
    self.http:request("POST", url, {
        email = email, password = password, returnSecureToken = true
    }, nil, function(ok, data)
        if ok then
            self.session = {
                uid = data.localId, account = data.email,
                idToken = data.idToken, refreshToken = data.refreshToken
            }
            callback(true, self.session)
            return
        end
        local code = data.error and data.error.message or "NETWORK_ERROR"
        callback(false, ERROR_TEXT[code] or "登入服務暫時無法使用")
    end)
end

function AuthService:register(email, password, callback)
    self:_authenticate("signUp", email, password, callback)
end

function AuthService:signIn(email, password, callback)
    self:_authenticate("signInWithPassword", email, password, callback)
end

return AuthService
