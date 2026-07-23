-- GitHub release lookup kept outside controllers and views for easy testing.
local UpdateService={}; UpdateService.__index=UpdateService

local function parts(value)
    local numbers={}
    for number in tostring(value or ""):gsub("^[vV]",""):gmatch("%d+") do
        numbers[#numbers+1]=tonumber(number)
        if #numbers==3 then break end
    end
    return numbers
end

function UpdateService.isNewer(candidate,current)
    local left,right=parts(candidate),parts(current)
    if #left==0 or #right==0 then return false end
    for index=1,3 do
        local a,b=left[index] or 0,right[index] or 0
        if a~=b then return a>b end
    end
    return false
end

function UpdateService.new(http,config)
    return setmetatable({http=assert(http),currentVersion=assert(config.currentVersion),
        apiUrl=assert(config.latestReleaseApiUrl),downloadUrl=assert(config.latestReleaseUrl)},UpdateService)
end

function UpdateService:check(callback)
    self.http:request("GET",self.apiUrl,nil,{Accept="application/vnd.github+json",
        ["User-Agent"]="Tetris2048-update-check"},function(ok,response)
        if not ok or type(response.tag_name)~="string" then callback(false); return end
        callback(true,{updateAvailable=UpdateService.isNewer(response.tag_name,self.currentVersion),
            version=response.tag_name:gsub("^[vV]",""),url=self.downloadUrl})
    end)
end

return UpdateService
