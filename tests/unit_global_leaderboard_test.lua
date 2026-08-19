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

T.test("Nickname update stops and reports the first failed write",function()
    local service=auth(); service.user.nickname="新暱稱"
    local http={calls=0}
    function http:request(method,_,_,_,callback)
        self.calls=self.calls+1
        if method=="GET" then callback(true,{fields={score={integerValue="10"}}},200)
        else callback(false,"寫入失敗",500) end
    end
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},service):updateNickname(function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"寫入失敗"); T.equal(http.calls,2)
end)

T.test("Account migration succeeds when the old account never uploaded a score",function()
    local http={methods={}}
    function http:request(method,_,_,_,callback)
        self.methods[#self.methods+1]=method; callback(false,{},404)
    end
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},auth()):migrateFrom({uid="old",idToken="old-token"},function(ok)
        reported=ok
    end)
    T.equal(reported,true); T.equal(#http.methods,1); T.equal(http.methods[1],"GET")
end)

T.test("Account migration treats an already deleted old record as done",function()
    local http={methods={}}
    function http:request(method,_,_,_,callback)
        self.methods[#self.methods+1]=method
        if method=="GET" then callback(true,{fields={score={integerValue="70"}}},200)
        elseif method=="PATCH" then callback(true,{},200)
        else callback(false,{},404) end
    end
    local reported={}
    GlobalLeaderboard.new(http,{projectId="p"},auth()):migrateFrom({uid="old",idToken="old-token"},function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,true); T.equal(reported.message,nil)
    T.equal(table.concat(http.methods,","),"GET,PATCH,DELETE")
end)

T.test("Deleting a global record without a signed-in account fails closed",function()
    local http={calls=0}
    function http:request() self.calls=self.calls+1 end
    local service=auth(); service.user=nil
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},service):deleteCurrent(function(ok) reported=ok end)
    T.equal(reported,false); T.equal(http.calls,0)
end)

T.test("Account migration reports a failed transfer instead of losing the old score",function()
    local http={methods={}}
    function http:request(method,_,_,_,callback)
        self.methods[#self.methods+1]=method
        if method=="GET" then callback(true,{fields={score={integerValue="70"}}},200)
        else callback(false,{},500) end
    end
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},auth()):migrateFrom({uid="old",idToken="old-token"},function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"新排行榜寫入失敗")
    -- 寫入失敗就不能刪掉舊紀錄，否則分數會直接消失。
    T.equal(table.concat(http.methods,","),"GET,PATCH")
end)

T.test("A failed score lookup never overwrites the stored record",function()
    local http={methods={}}
    function http:request(method,_,_,_,callback)
        self.methods[#self.methods+1]=method; callback(false,"讀取失敗",500)
    end
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},auth()):add(120,function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"讀取失敗")
    T.equal(table.concat(http.methods,","),"GET")
end)

T.test("Migration refuses incomplete account data and reports a failed cleanup",function()
    local http={calls=0}
    function http:request() self.calls=self.calls+1 end
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},auth()):migrateFrom(nil,function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"帳號移轉資料不完整"); T.equal(http.calls,0)

    local failing={}
    function failing:request(method,_,_,_,callback)
        if method=="GET" then callback(true,{fields={score={integerValue="30"}}},200)
        elseif method=="PATCH" then callback(true,{},200)
        else callback(false,{},500) end
    end
    local cleanup
    GlobalLeaderboard.new(failing,{projectId="p"},auth()):migrateFrom({uid="old",idToken="t"},function(ok,message)
        cleanup={ok=ok,message=message}
    end)
    T.equal(cleanup.ok,false); T.equal(cleanup.message,"舊排行榜刪除失敗")
end)

T.test("Malformed rows are dropped and duplicated accounts keep their best score",function()
    local http={}
    function http:request(_,_,_,_,callback)
        callback(true,{
            {document={name="scores/u1",fields={uid={stringValue="u1"},nickname={stringValue="甲"},score={integerValue="10"},mode={integerValue="1"}}}},
            {document={name="scores/u1_old",fields={uid={stringValue="u1"},nickname={stringValue="甲"},score={integerValue="40"},mode={integerValue="1"}}}},
            {document={name="scores/broken",fields={nickname={stringValue="無主"},score={integerValue="999"},mode={integerValue="1"}}}},
            {readTime="2026-01-01T00:00:00Z"}
        },200)
    end
    GlobalLeaderboard.new(http,{projectId="p"},auth()):list(function(ok,records)
        T.equal(ok,true); T.equal(#records,1)
        T.equal(records[1].uid,"u1"); T.equal(records[1].score,40)
    end,1)
end)

T.test("Uploading a score requires a signed-in account with a nickname",function()
    local http={calls=0}
    function http:request() self.calls=self.calls+1 end
    local service=auth(); service.user=nil
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},service):add(50,function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"請先登入")
    service.user={uid="u1",account="player1",idToken="token"}
    GlobalLeaderboard.new(http,{projectId="p"},service):add(50,function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"請先設定暱稱")
    T.equal(http.calls,0)
end)

T.test("A local identity without a credential never crashes a leaderboard request",function()
    local service=auth(); service.user.idToken=nil; service.user.nickname="玩家一"
    local http={calls=0}
    function http:request(_,_,_,headers,callback)
        self.calls=self.calls+1; self.headers=headers; callback(false,{},401)
    end
    local board=GlobalLeaderboard.new(http,{projectId="p"},service)
    local ok,message=pcall(function()
        board:add(50,function(success) T.equal(success,false) end)
        board:list(function(success) T.equal(success,false) end)
        board:deleteCurrent(function(success) T.equal(success,false) end)
    end)
    T.equal(ok,true,tostring(message))
    T.equal(http.headers,nil); T.equal(http.calls,3)
end)

T.test("A failed nickname read stops the update instead of reporting success",function()
    local service=auth(); service.user.nickname="新暱稱"
    local http={calls=0}
    function http:request(method,_,_,_,callback)
        self.calls=self.calls+1
        if method=="GET" then callback(false,"讀取失敗",500) else callback(true,{},200) end
    end
    local reported
    GlobalLeaderboard.new(http,{projectId="p"},service):updateNickname(function(ok,message)
        reported={ok=ok,message=message}
    end)
    T.equal(reported.ok,false); T.equal(reported.message,"讀取失敗"); T.equal(http.calls,1)
end)
