local T=require("test_helper")
local UpdateService=require("update_service")

T.test("Update checker compares semantic release versions",function()
    T.equal(UpdateService.isNewer("v2.3.9","2.3.8"),true)
    T.equal(UpdateService.isNewer("2.4.0","2.3.7"),true)
    T.equal(UpdateService.isNewer("v2.3.7","2.3.7"),false)
    T.equal(UpdateService.isNewer("2.3.6","2.3.7"),false)
    T.equal(UpdateService.isNewer("invalid","2.3.7"),false)
end)

T.test("Update checker returns only the configured trusted download URL",function()
    local http={}
    function http:request(method,url,body,headers,callback)
        T.equal(method,"GET"); T.equal(headers["User-Agent"],"Tetris2048-update-check")
        callback(true,{tag_name="v2.3.9",html_url="https://example.com/phishing"})
    end
    local service=UpdateService.new(http,{currentVersion="2.3.8",latestReleaseApiUrl="https://api.github.test/latest",
        latestReleaseUrl="https://github.com/xixa3333/Tetris2048/releases/latest"})
    service:check(function(ok,result)
        T.equal(ok,true); T.equal(result.updateAvailable,true); T.equal(result.version,"2.3.9")
        T.equal(result.url,"https://github.com/xixa3333/Tetris2048/releases/latest")
    end)
end)

T.test("Update checker prompts an older mobile build to open the latest release",function()
    local requested
    local http={request=function(_,method,url,_,headers,callback)
        requested={method=method,url=url,userAgent=headers["User-Agent"]}
        callback(true,{tag_name="v2.3.9"})
    end}
    local service=UpdateService.new(http,{currentVersion="2.3.8",latestReleaseApiUrl="https://api.github.com/repos/xixa3333/Tetris2048/releases/latest",
        latestReleaseUrl="https://github.com/xixa3333/Tetris2048/releases/latest"})
    service:check(function(ok,result)
        T.equal(ok,true)
        T.equal(result.updateAvailable,true)
        T.equal(result.url,"https://github.com/xixa3333/Tetris2048/releases/latest")
    end)
    T.equal(requested.method,"GET")
    T.equal(requested.userAgent,"Tetris2048-update-check")
end)

T.test("Update checker silently reports network and malformed response failures",function()
    for _,response in ipairs({{ok=false,value={}},{ok=true,value={}}}) do
        local http={request=function(_,_,_,_,_,callback) callback(response.ok,response.value) end}
        UpdateService.new(http,{currentVersion="2.3.7",latestReleaseApiUrl="api",latestReleaseUrl="download"})
            :check(function(ok) T.equal(ok,false) end)
    end
end)
