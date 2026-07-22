local T=require("test_helper")
local SessionStore=require("session_store")
T.test("Privacy boundary rejects malformed remembered session",function()
    local store=SessionStore.new({load=function() return {account="a@example.com",password="leak"} end,save=function() end})
    T.equal(store:load(),nil)
end)
T.test("Privacy boundary clears remembered token on logout",function()
    local saved={refreshToken="token"}; local store=SessionStore.new({load=function() return saved end,save=function(_,data) saved=data end})
    store:clear(); T.equal(saved.refreshToken,nil)
end)
T.test("Security boundary rejects short password before network",function()
    local AuthService=require("auth_service"); local http={calls=0}
    function http:request() self.calls=self.calls+1 end
    local auth=AuthService.new(http,{apiKey="key"}); auth.session={idToken="id"}
    auth:changePassword("123",function(ok) T.equal(ok,false) end); T.equal(http.calls,0)
end)
T.test("Privacy boundary keeps credentials out of shared local score records",function()
    local LocalLeaderboard=require("local_leaderboard"); local saved={}
    local board=LocalLeaderboard.new({load=function() return saved end,save=function(_,data) saved=data end})
    local record=board:add("uid","暱稱",10,1)
    T.equal(record.account,"暱稱"); T.equal(record.password,nil); T.equal(record.refreshToken,nil)
end)
