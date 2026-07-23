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
