local ProfileService={}; ProfileService.__index=ProfileService

local function stringField(value) return {stringValue=tostring(value)} end

function ProfileService.new(http,config,auth)
    local base="https://firestore.googleapis.com/v1/projects/"..config.projectId.."/databases/(default)/documents/profiles/"
    return setmetatable({http=http,auth=auth,base=base},ProfileService)
end
function ProfileService:_headers()
    local user=self.auth:currentUser()
    return user and {Authorization="Bearer "..user.idToken} or nil
end
function ProfileService:get(callback)
    local user=self.auth:currentUser(); if not user then callback(false,"請先登入"); return end
    self.http:request("GET",self.base..user.uid,nil,self:_headers(),function(ok,data,status)
        if status==404 then callback(true,nil); return end
        if not ok then callback(false,"暱稱讀取失敗"); return end
        local nickname=data.fields and data.fields.nickname and data.fields.nickname.stringValue
        user.nickname=nickname; callback(true,nickname)
    end)
end
function ProfileService:save(nickname,callback)
    local user=self.auth:currentUser(); if not user then callback(false,"請先登入"); return end
    nickname=(nickname or ""):match("^%s*(.-)%s*$")
    if #nickname<2 or #nickname>16 then callback(false,"暱稱需為 2 到 16 個字元"); return end
    self.http:request("PATCH",self.base..user.uid,{fields={
        uid=stringField(user.uid),nickname=stringField(nickname)
    }},self:_headers(),function(ok)
        if ok then user.nickname=nickname; callback(true,nickname)
        else callback(false,"暱稱儲存失敗") end
    end)
end
function ProfileService:deleteCurrent(callback)
    local user=self.auth:currentUser(); if not user then callback(false); return end
    self.http:request("DELETE",self.base..user.uid,nil,self:_headers(),function(ok,_,status)
        callback(ok or status==404)
    end)
end
return ProfileService
