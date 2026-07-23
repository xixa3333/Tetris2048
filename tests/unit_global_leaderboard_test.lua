local T=require("test_helper")
local GlobalLeaderboard=require("global_leaderboard")
local FirestoreUrl=require("firestore_url")

T.test("Firestore REST URL encodes the default database path",function()
    local url=FirestoreUrl.documents("project")
    T.equal(url,"https://firestore.googleapis.com/v1/projects/project/databases/%28default%29/documents")
end)

local function auth()
    local service={user={uid="u1",account="player1",nickname="玩家一",idToken="token"}}
    function service:currentUser() return self.user end
    function service:isSignedIn() return self.user~=nil end
    return service
end

T.test("Global leaderboard keeps the stored maximum when a lower score is submitted",function()
    local http={calls={}}
    function http:request(method,url,body,headers,callback)
        self.calls[#self.calls+1]={method=method,url=url,body=body}
        if method=="GET" then callback(true,{fields={uid={stringValue="u1"},score={integerValue="100"},mode={integerValue="1"}}},200)
        else callback(true,{},200) end
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},auth())
    board:add(40,function(ok) T.equal(ok,true) end)
    T.equal(http.calls[2].method,"PATCH")
    T.equal(http.calls[2].body.fields.score.integerValue,"100")
    T.truthy(http.calls[2].url:match("/scores/u1$"))
end)

T.test("Global leaderboard stores relaxed mode in the same collection with a mode document id",function()
    local http={calls={}}
    function http:request(method,url,body,headers,callback)
        self.calls[#self.calls+1]={method=method,url=url,body=body}
        if method=="GET" then callback(false,{},404) else callback(true,{},200) end
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},auth())
    board:add(40,function(ok) T.equal(ok,true) end,2)
    T.truthy(http.calls[1].url:match("/scores/u1_mode2$"))
    T.truthy(http.calls[2].url:match("/scores/u1_mode2$"))
    T.equal(http.calls[2].body.fields.mode.integerValue,"2")
end)

T.test("Nickname update preserves existing high scores in both modes",function()
    local service=auth(); service.user.nickname="新暱稱"
    local http={calls={}}
    function http:request(method,url,body,headers,callback)
        self.calls[#self.calls+1]={method=method,url=url,body=body}
        if method=="GET" then callback(true,{fields={uid={stringValue="u1"},score={integerValue="88"},mode={integerValue=url:match("mode2") and "2" or "1"}}},200)
        else callback(true,{},200) end
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},service)
    board:updateNickname(function(ok) T.equal(ok,true) end)
    T.equal(http.calls[2].body.fields.score.integerValue,"88")
    T.equal(http.calls[2].body.fields.nickname.stringValue,"新暱稱")
    T.equal(http.calls[4].body.fields.mode.integerValue,"2")
end)

T.test("Global leaderboard filters mode records and returns own rank",function()
    local http={}
    function http:request(_,_,_,_,callback)
        callback(true,{
            {document={name="scores/u1",fields={uid={stringValue="u1"},nickname={stringValue="甲"},score={integerValue="10"},mode={integerValue="1"}}}},
            {document={name="scores/u1_mode2",fields={uid={stringValue="u1"},nickname={stringValue="甲"},score={integerValue="50"},mode={integerValue="2"}}}},
            {document={name="scores/u2_mode2",fields={uid={stringValue="u2"},nickname={stringValue="乙"},score={integerValue="30"},mode={integerValue="2"}}}}
        },200)
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},auth())
    board:list(function(ok,records,ownRank)
        T.equal(ok,true); T.equal(#records,2)
        T.equal(records[1].uid,"u1"); T.equal(records[1].score,50)
        T.equal(records[1].isCurrent,true); T.equal(records[2].isCurrent,false)
        T.equal(records[2].uid,"u2"); T.equal(ownRank,1)
    end,2)
end)

T.test("Global leaderboard finds own rank beyond the former 100-player boundary",function()
    local rows={}
    for rank=1,151 do
        local uid=rank==151 and "u1" or "other"..rank
        rows[rank]={document={name="scores/"..uid,fields={uid={stringValue=uid},nickname={stringValue="玩家"..rank},score={integerValue=tostring(1000-rank)},mode={integerValue="1"}}}}
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
