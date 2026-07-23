local GlobalLeaderboard={}; GlobalLeaderboard.__index=GlobalLeaderboard
local function field(value)
    if type(value)=="number" then return {integerValue=tostring(value)} end
    return {stringValue=tostring(value)}
end
local function decode(document)
    local f=document.fields or {}
    return {id=(document.name or ""):match("([^/]+)$"),uid=f.uid and f.uid.stringValue,
        nickname=f.nickname and f.nickname.stringValue or "玩家",
        score=tonumber(f.score and f.score.integerValue) or 0,
        playedAt=f.updatedAt and f.updatedAt.timestampValue}
end
function GlobalLeaderboard.new(http,config,auth)
    local base="https://firestore.googleapis.com/v1/projects/"..config.projectId.."/databases/(default)/documents"
    return setmetatable({http=http,auth=auth,base=base},GlobalLeaderboard)
end
function GlobalLeaderboard:_headers()
    local user=self.auth:currentUser()
    return user and {Authorization="Bearer "..user.idToken} or nil
end
function GlobalLeaderboard:_write(user,score,callback)
    self.http:request("PATCH",self.base.."/scores/"..user.uid,{fields={
        uid=field(user.uid),nickname=field(user.nickname),
        score=field(math.floor(score)),updatedAt={timestampValue=os.date("!%Y-%m-%dT%H:%M:%SZ")},
        version=field("2.3.5")
    }},self:_headers(),callback)
end
function GlobalLeaderboard:add(score,callback)
    local user=self.auth:currentUser()
    if not user then callback(false,"請先登入"); return end
    if not user.nickname then callback(false,"請先設定暱稱"); return end
    local url=self.base.."/scores/"..user.uid
    self.http:request("GET",url,nil,self:_headers(),function(ok,data,status)
        if status==404 then self:_write(user,score,callback); return end
        if not ok then callback(false,data); return end
        local current=decode(data)
        -- 分數較低時仍以原最高分寫回，以便同步玩家修改後的暱稱。
        self:_write(user,math.max(current.score,math.floor(score)),callback)
    end)
end
function GlobalLeaderboard:updateNickname(callback)
    local user=self.auth:currentUser()
    if not user or not user.nickname then callback(false,"請先設定暱稱"); return end
    self.http:request("GET",self.base.."/scores/"..user.uid,nil,self:_headers(),function(ok,data,status)
        if status==404 then callback(true); return end
        if not ok then callback(false,data); return end
        self:_write(user,decode(data).score,callback)
    end)
end
function GlobalLeaderboard:list(callback)
    if not self.auth:isSignedIn() then callback(false,"請先登入"); return end
    local query={structuredQuery={from={{collectionId="scores"}},
        orderBy={{field={fieldPath="score"},direction="DESCENDING"}}}}
    self.http:request("POST",self.base..":runQuery",query,self:_headers(),function(ok,data)
        if not ok then callback(false,data); return end
        local bestByUid={}
        for _,row in ipairs(data) do
            if row.document then
                local record=decode(row.document)
                if record.uid and (not bestByUid[record.uid] or record.score>bestByUid[record.uid].score) then
                    bestByUid[record.uid]=record
                end
            end
        end
        local records={}
        for _,record in pairs(bestByUid) do records[#records+1]=record end
        table.sort(records,function(a,b)
            if a.score==b.score then return a.nickname<b.nickname end
            return a.score>b.score
        end)
        local user=self.auth:currentUser(); local ownRank=nil
        for rank,record in ipairs(records) do
            record.isCurrent=user~=nil and record.uid==user.uid
            if record.isCurrent then ownRank=rank end
        end
        callback(true,records,ownRank)
    end)
end
function GlobalLeaderboard:migrateFrom(oldUser,callback)
    local newUser=self.auth:currentUser()
    if not newUser or not oldUser then callback(false,"帳號轉換狀態錯誤"); return end
    local oldUrl=self.base.."/scores/"..oldUser.uid
    local oldHeaders={Authorization="Bearer "..oldUser.idToken}
    self.http:request("GET",oldUrl,nil,oldHeaders,function(ok,data,status)
        if status==404 then callback(true); return end
        if not ok then callback(false,"舊排行榜讀取失敗"); return end
        local oldScore=decode(data).score
        self:_write(newUser,oldScore,function(written)
            if not written then callback(false,"排行榜轉移失敗"); return end
            self.http:request("DELETE",oldUrl,nil,oldHeaders,function(deleted,_,deleteStatus)
                callback(deleted or deleteStatus==404,(deleted or deleteStatus==404) and nil or "舊排行榜清理失敗")
            end)
        end)
    end)
end
function GlobalLeaderboard:deleteCurrent(callback)
    local user=self.auth:currentUser(); if not user then callback(false); return end
    self.http:request("DELETE",self.base.."/scores/"..user.uid,nil,self:_headers(),function(ok,_,status)
        callback(ok or status==404)
    end)
end
return GlobalLeaderboard
