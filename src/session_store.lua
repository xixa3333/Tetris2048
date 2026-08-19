-- 只保存 Firebase Refresh Token 與公開識別資料，不保存密碼或短效 ID Token。
-- uid 與暱稱都是公開資訊（本機排行榜本來就存著），記下來才能在離線時
-- 用上次登入的身分顯示本機排行榜並寫入新紀錄。
local SessionStore={}; SessionStore.__index=SessionStore
function SessionStore.new(storage) return setmetatable({storage=assert(storage)},SessionStore) end
-- 憑證（refreshToken）與身分（uid／帳號 ID／暱稱）分開保存：
-- 憑證代表雲端權限，登出就要丟掉；身分只是本機顯示資料，留著才能離線快捷登入。
function SessionStore:load()
    local data=self.storage:load()
    if type(data)~="table" then return nil end
    local session={uid=data.uid,account=data.account,nickname=data.nickname,
        authEmail=data.authEmail,isLegacy=data.isLegacy}
    if type(data.refreshToken)=="string" and data.refreshToken~="" then session.refreshToken=data.refreshToken end
    if not session.refreshToken and not session.uid then return nil end
    return session
end
function SessionStore:save(session)
    self.storage:save({refreshToken=session.refreshToken,uid=session.uid,account=session.account,
        nickname=session.nickname,authEmail=session.authEmail,isLegacy=session.isLegacy==true})
end
-- 登出：只丟掉雲端憑證，保留最近登入過的帳號供離線快捷登入。
function SessionStore:clear()
    local data=self.storage:load()
    if type(data)~="table" then self.storage:save({}); return end
    self.storage:save({uid=data.uid,account=data.account,nickname=data.nickname,
        authEmail=data.authEmail,isLegacy=data.isLegacy==true})
end
-- 完全忘記這台裝置上的帳號，帳號轉換等情境才需要。
function SessionStore:forget() self.storage:save({}) end
return SessionStore
