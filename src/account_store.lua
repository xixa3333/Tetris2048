-- 這台裝置登入過的帳號清單，供登入頁的快捷登入使用。
-- 每筆保存公開識別（uid／帳號 ID／暱稱）與該帳號的 refresh token；
-- 不保存密碼與短效 ID Token。清單依最後登入時間由新到舊排序，
-- 超過上限就丟掉最舊的，避免裝置上累積無限多組憑證。
local AccountStore={}; AccountStore.__index=AccountStore
local LIMIT=5

local function sanitize(entry)
    if type(entry)~="table" or type(entry.uid)~="string" or entry.uid=="" then return nil end
    return {uid=entry.uid,account=entry.account,nickname=entry.nickname,
        authEmail=entry.authEmail,isLegacy=entry.isLegacy==true,
        refreshToken=type(entry.refreshToken)=="string" and entry.refreshToken~="" and entry.refreshToken or nil,
        lastLoginAt=tonumber(entry.lastLoginAt) or 0}
end

function AccountStore.new(storage,clock)
    return setmetatable({storage=assert(storage),clock=clock or os.time},AccountStore)
end

function AccountStore:_load()
    local data=self.storage:load()
    local entries={}
    for _,entry in ipairs(type(data)=="table" and data.accounts or {}) do
        local clean=sanitize(entry)
        if clean then entries[#entries+1]=clean end
    end
    table.sort(entries,function(left,right)
        if left.lastLoginAt==right.lastLoginAt then return tostring(left.uid)<tostring(right.uid) end
        return left.lastLoginAt>right.lastLoginAt
    end)
    return entries
end

function AccountStore:_save(entries)
    while #entries>LIMIT do table.remove(entries) end
    self.storage:save({accounts=entries})
    return entries
end

function AccountStore:list() return self:_load() end

function AccountStore:find(uid)
    for _,entry in ipairs(self:_load()) do if entry.uid==uid then return entry end end
    return nil
end

-- 登入成功後記住帳號；同一個 uid 會覆寫並移到清單最前面。
function AccountStore:remember(account)
    local clean=sanitize(account)
    if not clean then return nil end
    local entries=self:_load()
    for index=#entries,1,-1 do
        if entries[index].uid==clean.uid then
            clean.nickname=clean.nickname or entries[index].nickname
            clean.refreshToken=clean.refreshToken or entries[index].refreshToken
            table.remove(entries,index)
        end
    end
    clean.lastLoginAt=self.clock()
    table.insert(entries,1,clean)
    self:_save(entries)
    return clean
end

-- 登出：只丟掉該帳號的憑證，身分留著讓玩家還能離線看本機排行榜。
function AccountStore:clearCredential(uid)
    local entries=self:_load()
    for _,entry in ipairs(entries) do
        if entry.uid==uid then entry.refreshToken=nil end
    end
    self:_save(entries)
end

-- 移除快捷登入選項，不影響雲端帳號與排行榜紀錄。
function AccountStore:forget(uid)
    local entries=self:_load()
    for index=#entries,1,-1 do
        if entries[index].uid==uid then table.remove(entries,index) end
    end
    self:_save(entries)
end

function AccountStore:limit() return LIMIT end

return AccountStore
