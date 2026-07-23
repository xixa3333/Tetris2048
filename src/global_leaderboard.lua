local FirestoreUrl=require("firestore_url")
local GlobalLeaderboard={}; GlobalLeaderboard.__index=GlobalLeaderboard

local function field(value)
    if type(value)=="number" then return {integerValue=tostring(value)} end
    return {stringValue=tostring(value)}
end

local function collection()
    return "scores"
end

local function normalizeMode(mode)
    return tonumber(mode)==2 and 2 or 1
end

local function documentId(user,mode)
    if normalizeMode(mode)==2 then return user.uid.."_mode2" end
    return user.uid
end

local function decode(document)
    local f=document.fields or {}
    return {id=(document.name or ""):match("([^/]+)$"),uid=f.uid and f.uid.stringValue,
        nickname=f.nickname and f.nickname.stringValue or "玩家",
        score=tonumber(f.score and f.score.integerValue) or 0,
        mode=tonumber(f.mode and f.mode.integerValue) or 1,
        playedAt=f.updatedAt and f.updatedAt.timestampValue}
end

function GlobalLeaderboard.new(http,config,auth)
    local base=FirestoreUrl.documents(config.projectId)
    return setmetatable({http=http,auth=auth,base=base},GlobalLeaderboard)
end

function GlobalLeaderboard:_headers()
    local user=self.auth:currentUser()
    return user and {Authorization="Bearer "..user.idToken} or nil
end

function GlobalLeaderboard:_write(user,score,callback,mode)
    local normalizedMode=normalizeMode(mode)
    self.http:request("PATCH",self.base.."/"..collection().."/"..documentId(user,normalizedMode),{fields={
        uid=field(user.uid),nickname=field(user.nickname),
        score=field(math.floor(score)),updatedAt={timestampValue=os.date("!%Y-%m-%dT%H:%M:%SZ")},
        version=field("2.3.9"),mode=field(normalizedMode)
    }},self:_headers(),callback)
end

function GlobalLeaderboard:add(score,callback,mode)
    local user=self.auth:currentUser()
    if not user then callback(false,"請先登入"); return end
    if not user.nickname then callback(false,"請先設定暱稱"); return end
    local normalizedMode=normalizeMode(mode)
    local url=self.base.."/"..collection().."/"..documentId(user,normalizedMode)
    self.http:request("GET",url,nil,self:_headers(),function(ok,data,status)
        if status==404 then self:_write(user,score,callback,normalizedMode); return end
        if not ok then callback(false,data); return end
        self:_write(user,math.max(decode(data).score,math.floor(score)),callback,normalizedMode)
    end)
end

function GlobalLeaderboard:updateNickname(callback)
    local user=self.auth:currentUser()
    if not user or not user.nickname then callback(false,"請先設定暱稱"); return end
    local modes,index={1,2},1
    local function nextMode()
        local mode=modes[index]; index=index+1
        if not mode then callback(true); return end
        self.http:request("GET",self.base.."/"..collection().."/"..documentId(user,mode),nil,self:_headers(),function(ok,data,status)
            if status==404 then nextMode(); return end
            if not ok then callback(false,data); return end
            self:_write(user,decode(data).score,function(written,message)
                if written then nextMode() else callback(false,message) end
            end,mode)
        end)
    end
    nextMode()
end

function GlobalLeaderboard:list(callback,mode)
    if not self.auth:isSignedIn() then callback(false,"請先登入"); return end
    local normalizedMode=normalizeMode(mode)
    local query={structuredQuery={from={{collectionId=collection()}},
        orderBy={{field={fieldPath="score"},direction="DESCENDING"}}}}
    self.http:request("POST",self.base..":runQuery",query,self:_headers(),function(ok,data)
        if not ok then callback(false,data); return end
        local bestByUid={}
        for _,row in ipairs(data or {}) do
            if row.document then
                local record=decode(row.document)
                if record.mode==normalizedMode and record.uid and (not bestByUid[record.uid] or record.score>bestByUid[record.uid].score) then
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
    if not newUser or not oldUser then callback(false,"帳號移轉資料不完整"); return end
    local oldUrl=self.base.."/scores/"..oldUser.uid
    local oldHeaders={Authorization="Bearer "..oldUser.idToken}
    self.http:request("GET",oldUrl,nil,oldHeaders,function(ok,data,status)
        if status==404 then callback(true); return end
        if not ok then callback(false,"舊排行榜讀取失敗"); return end
        self:_write(newUser,decode(data).score,function(written)
            if not written then callback(false,"新排行榜寫入失敗"); return end
            self.http:request("DELETE",oldUrl,nil,oldHeaders,function(deleted,_,deleteStatus)
                callback(deleted or deleteStatus==404,(deleted or deleteStatus==404) and nil or "舊排行榜刪除失敗")
            end)
        end,1)
    end)
end

function GlobalLeaderboard:deleteCurrent(callback,mode)
    local user=self.auth:currentUser(); if not user then callback(false); return end
    self.http:request("DELETE",self.base.."/"..collection().."/"..documentId(user,mode),nil,self:_headers(),function(ok,_,status)
        callback(ok or status==404)
    end)
end

return GlobalLeaderboard
