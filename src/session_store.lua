-- 只保存 Firebase Refresh Token 與公開帳號識別，不保存密碼或短效 ID Token。
local SessionStore={}; SessionStore.__index=SessionStore
function SessionStore.new(storage) return setmetatable({storage=assert(storage)},SessionStore) end
function SessionStore:load()
    local data=self.storage:load()
    if type(data)~="table" or type(data.refreshToken)~="string" or data.refreshToken=="" then return nil end
    return {refreshToken=data.refreshToken,account=data.account,authEmail=data.authEmail,isLegacy=data.isLegacy}
end
function SessionStore:save(session)
    self.storage:save({refreshToken=session.refreshToken,account=session.account,
        authEmail=session.authEmail,isLegacy=session.isLegacy==true})
end
function SessionStore:clear() self.storage:save({}) end
return SessionStore
