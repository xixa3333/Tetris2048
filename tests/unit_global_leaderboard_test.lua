local T=require("test_helper")
local GlobalLeaderboard=require("global_leaderboard")

local function auth()
    local service={user={uid="u1",account="a@example.com",nickname="小明",idToken="token"}}
    function service:currentUser() return self.user end
    function service:isSignedIn() return self.user~=nil end
    return service
end

T.test("Global leaderboard keeps the stored maximum when a lower score is submitted",function()
    local http={calls={}}
    function http:request(method,url,body,headers,callback)
        self.calls[#self.calls+1]={method=method,url=url,body=body}
        if method=="GET" then callback(true,{fields={uid={stringValue="u1"},score={integerValue="100"}}},200)
        else callback(true,{},200) end
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},auth())
    board:add(40,function(ok) T.equal(ok,true) end)
    T.equal(http.calls[2].method,"PATCH")
    T.equal(http.calls[2].body.fields.score.integerValue,"100")
    T.truthy(http.calls[2].url:match("/scores/u1$"))
end)

T.test("Nickname update preserves an existing global high score",function()
    local service=auth(); service.user.nickname="新暱稱"
    local http={calls={}}
    function http:request(method,url,body,headers,callback)
        self.calls[#self.calls+1]={method=method,body=body}
        if method=="GET" then callback(true,{fields={uid={stringValue="u1"},score={integerValue="88"}}},200)
        else callback(true,{},200) end
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},service)
    board:updateNickname(function(ok) T.equal(ok,true) end)
    T.equal(http.calls[2].body.fields.score.integerValue,"88")
    T.equal(http.calls[2].body.fields.nickname.stringValue,"新暱稱")
end)

T.test("Global leaderboard shows one highest record for every UID and returns own rank",function()
    local http={}
    function http:request(_,_,_,_,callback)
        callback(true,{
            {document={name="scores/old",fields={uid={stringValue="u1"},nickname={stringValue="甲"},score={integerValue="10"}}}},
            {document={name="scores/u1",fields={uid={stringValue="u1"},nickname={stringValue="甲"},score={integerValue="50"}}}},
            {document={name="scores/u2",fields={uid={stringValue="u2"},nickname={stringValue="乙"},score={integerValue="30"}}}}
        },200)
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},auth())
    board:list(function(ok,records,ownRank)
        T.equal(ok,true); T.equal(#records,2)
        T.equal(records[1].uid,"u1"); T.equal(records[1].score,50)
        T.equal(records[1].isCurrent,true); T.equal(records[2].isCurrent,false)
        T.equal(records[2].uid,"u2"); T.equal(ownRank,1)
    end)
end)

T.test("Global leaderboard finds own rank beyond the former 100-player boundary",function()
    local rows={}
    for rank=1,151 do
        local uid=rank==151 and "u1" or "other"..rank
        rows[rank]={document={name="scores/"..uid,fields={uid={stringValue=uid},nickname={stringValue="玩家"..rank},score={integerValue=tostring(1000-rank)}}}}
    end
    local http={}
    function http:request(_,_,body,_,callback)
        T.equal(body.structuredQuery.limit,nil)
        callback(true,rows,200)
    end
    GlobalLeaderboard.new(http,{projectId="p"},auth()):list(function(ok,records,ownRank)
        T.equal(ok,true); T.equal(#records,151); T.equal(ownRank,151)
        T.equal(records[151].isCurrent,true)
    end)
end)
