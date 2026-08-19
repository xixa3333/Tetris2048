local T=require("test_helper")
local NicknamePolicy=require("nickname_policy")
local ProfileService=require("profile_service")

local function service(response)
    local auth={user={uid="u1",idToken="token"}}
    function auth:currentUser() return self.user end
    local http={calls=0}
    function http:request(method,url,body,headers,callback)
        self.calls=self.calls+1; self.url=url; self.body=body; self.headers=headers
        callback(response.ok,response.data or {},response.status)
    end
    return ProfileService.new(http,{projectId="p"},auth),http,auth
end

T.test("Nickname validation counts Unicode characters instead of UTF-8 bytes",function()
    local sixteen="一二三四五六七八九十甲乙丙丁戊己"
    T.equal(NicknamePolicy.length(sixteen),16)
    T.equal(NicknamePolicy.validate(sixteen),sixteen)
    local value,message=NicknamePolicy.validate(sixteen.."庚")
    T.equal(value,nil); T.equal(message,"暱稱需為 2 到 16 個字元")
    T.equal(NicknamePolicy.validate("  玩家一號  "),"玩家一號")
end)

T.test("Nickname validation rejects short, malformed and control input",function()
    for _,value in ipairs({"A","玩家\n名稱",string.char(0xFF,0xFE)}) do
        local nickname,message=NicknamePolicy.validate(value)
        T.equal(nickname,nil); T.truthy(message)
    end
end)

T.test("Profile creates or modifies a Unicode nickname with authenticated UID",function()
    local profile,http,auth=service({ok=true,status=200})
    profile:save("中文暱稱測試",function(ok,value)
        T.equal(ok,true); T.equal(value,"中文暱稱測試")
    end)
    T.equal(http.calls,1); T.equal(http.body.fields.uid.stringValue,"u1")
    T.truthy(http.url:find("/databases/%%28default%%29/documents/profiles/u1"))
    T.equal(http.url:find("(default)",1,true),nil)
    T.equal(http.body.fields.nickname.stringValue,"中文暱稱測試")
    T.equal(http.headers.Authorization,"Bearer token")
    T.equal(auth.user.nickname,"中文暱稱測試")
end)

T.test("Profile reports actionable Firebase and network errors",function()
    local cases={{status=401,message="登入已過期，請登出後重新登入"},
        {status=403,message="暱稱權限驗證失敗，請重新登入"},
        {status=nil,message="網路連線失敗，暱稱尚未儲存"}}
    for _,case in ipairs(cases) do
        local profile=service({ok=false,status=case.status})
        profile:save("玩家名稱",function(ok,message)
            T.equal(ok,false); T.equal(message,case.message)
        end)
    end
end)

T.test("Profile reads an existing nickname and caches it on the signed-in user",function()
    local profile,http,auth=service({ok=true,status=200,data={fields={nickname={stringValue="舊玩家"}}}})
    local reported
    profile:get(function(ok,nickname) reported={ok=ok,nickname=nickname} end)
    T.equal(reported.ok,true); T.equal(reported.nickname,"舊玩家")
    T.equal(auth.user.nickname,"舊玩家"); T.equal(http.calls,1)
    local missing=service({ok=false,status=404})
    missing:get(function(ok,nickname) T.equal(ok,true); T.equal(nickname,nil) end)
    local broken=service({ok=false,status=500})
    broken:get(function(ok,message) T.equal(ok,false); T.equal(message,"暱稱讀取失敗") end)
end)

T.test("Profile deletion accepts an already missing document during migration",function()
    local removed=service({ok=false,status=404})
    removed:deleteCurrent(function(ok) T.equal(ok,true) end)
    local refused=service({ok=false,status=403})
    refused:deleteCurrent(function(ok) T.equal(ok,false) end)
end)

T.test("Nickname validation accepts the last two-byte UTF-8 lead byte",function()
    local nko=string.char(0xDF,0x81)
    T.equal(NicknamePolicy.length(nko:rep(3)),3)
    T.equal(NicknamePolicy.validate(nko:rep(3)),nko:rep(3))
end)

T.test("Nickname validation accepts the highest UTF-8 continuation byte",function()
    local highest=string.char(0xDF,0xBF)
    T.equal(NicknamePolicy.length(highest:rep(2)),2)
    T.equal(NicknamePolicy.validate(highest:rep(2)),highest:rep(2))
    T.equal(NicknamePolicy.validate(string.char(0xDF,0xC0):rep(2)),nil)
end)

T.test("Nickname validation accepts the lowest two-byte UTF-8 lead byte",function()
    local copyright=string.char(0xC2,0xA9)
    T.equal(NicknamePolicy.length(copyright:rep(2)),2)
    T.equal(NicknamePolicy.validate(copyright:rep(2)),copyright:rep(2))
    -- 0xC1 是過長編碼的開頭，必須被拒絕。
    T.equal(NicknamePolicy.validate(string.char(0xC1,0xA9):rep(2)),nil)
    -- 三位元組與四位元組的最小開頭位元組也要當成合法字元。
    local thai=string.char(0xE0,0xB8,0x81)
    T.equal(NicknamePolicy.length(thai:rep(3)),3)
    T.equal(NicknamePolicy.validate(thai:rep(3)),thai:rep(3))
    local emoji=string.char(0xF0,0x9F,0x98,0x80)
    T.equal(NicknamePolicy.length(emoji:rep(2)),2)
    T.equal(NicknamePolicy.validate(emoji:rep(2)),emoji:rep(2))
end)

T.test("A local identity without a credential never crashes the profile request",function()
    local auth={user={uid="u1"}}
    function auth:currentUser() return self.user end
    local http={calls=0}
    function http:request(_,_,_,headers,callback)
        self.calls=self.calls+1; self.headers=headers; callback(false,{},401)
    end
    local profile=ProfileService.new(http,{projectId="p"},auth)
    local ok,message=pcall(function()
        profile:get(function(success) T.equal(success,false) end)
        profile:save("玩家一",function(success) T.equal(success,false) end)
        profile:deleteCurrent(function(success) T.equal(success,false) end)
    end)
    T.equal(ok,true,tostring(message))
    T.equal(http.headers,nil); T.equal(http.calls,3)
end)
