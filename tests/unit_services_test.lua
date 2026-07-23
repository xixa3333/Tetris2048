local T=require("test_helper")
local LocalLeaderboard=require("local_leaderboard")
local AuthService=require("auth_service")

local function memoryStorage()
    local storage={data={}}
    function storage:load() return self.data end
    function storage:save(data) self.data=data end
    return storage
end

T.test("Local leaderboard aggregates local accounts, sorts scores, and deletes one record",function()
    local board=LocalLeaderboard.new(memoryStorage())
    local low=board:add("a","a@example.com",10,100)
    board:add("a","a@example.com",30,101)
    board:add("b","b@example.com",999,102)
    local records=board:list("a")
    T.equal(#records,2); T.equal(records[1].score,30)
    T.equal(board:remove("a",low.id),true); T.equal(#board:list("a"),1)
    T.equal(#board:list("b"),1)
    local all=board:listAll()
    T.equal(#all,2); T.equal(all[1].account,"b@example.com"); T.equal(all[1].uid,"b")
end)

T.test("Local leaderboard ignores zero scores and floors positive decimals",function()
    local board=LocalLeaderboard.new(memoryStorage())
    T.equal(board:add("u","u@example.com",-3.5,1),nil)
    T.equal(board:add("u","u@example.com",0,2),nil)
    T.equal(#board:listAll(),0)
    T.equal(board:add("u","u@example.com",12.9,2).score,12)
end)

T.test("Auth validates input before network access",function()
    local http={calls=0}; function http:request() self.calls=self.calls+1 end
    local auth=AuthService.new(http,{apiKey="test"}); local message
    auth:register("a@","123456",function(ok,errorText) T.equal(ok,false); message=errorText end)
    T.equal(http.calls,0); T.truthy(message)
    auth:signIn("a@example.com","123",function(ok,errorText) T.equal(ok,false); message=errorText end)
    T.equal(http.calls,0)
end)

T.test("Auth stores and clears a successful Firebase session",function()
    local http={}; function http:request(_,_,body,_,callback)
        T.equal(body.returnSecureToken,true)
        callback(true,{localId="uid",email="a@example.com",idToken="token",refreshToken="refresh"})
    end
    local auth=AuthService.new(http,{apiKey="test"})
    auth:signIn("A@example.com","123456",function(ok) T.equal(ok,true) end)
    T.equal(auth:currentUser().uid,"uid"); auth:signOut(); T.equal(auth:isSignedIn(),false)
end)
