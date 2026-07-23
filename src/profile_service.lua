local NicknamePolicy=require("nickname_policy")
local FirestoreUrl=require("firestore_url")
local ProfileService={}; ProfileService.__index=ProfileService

local function stringField(value) return {stringValue=tostring(value)} end

function ProfileService.new(http,config,auth)
    local base=FirestoreUrl.documents(config.projectId).."/profiles/"
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
    local valid,message=NicknamePolicy.validate(nickname)
    if not valid then callback(false,message); return end
    nickname=valid
    self.http:request("PATCH",self.base..user.uid,{fields={
        uid=stringField(user.uid),nickname=stringField(nickname)
    }},self:_headers(),function(ok,_,status)
        if ok then user.nickname=nickname; callback(true,nickname)
        elseif status==401 then callback(false,"登入已過期，請登出後重新登入")
        elseif status==403 then callback(false,"暱稱權限驗證失敗，請重新登入")
        elseif status==400 then callback(false,"暱稱格式不符合伺服器規則")
        elseif status==nil or status==0 then callback(false,"網路連線失敗，暱稱尚未儲存")
        else callback(false,"暱稱儲存失敗（錯誤 "..tostring(status).."）") end
    end)
end
function ProfileService:deleteCurrent(callback)
    local user=self.auth:currentUser(); if not user then callback(false); return end
    self.http:request("DELETE",self.base..user.uid,nil,self:_headers(),function(ok,_,status)
        callback(ok or status==404)
    end)
end
return ProfileService
