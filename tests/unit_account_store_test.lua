local T=require("test_helper")
local AccountStore=require("account_store")

local function build()
    local data={}
    local storage={}
    function storage:load() return data end
    function storage:save(value) data=value end
    local now=100
    return AccountStore.new(storage,function() now=now+1; return now end),function() return data end
end

T.test("Accounts are listed newest first and re-logging in moves one to the front",function()
    local store=build()
    store:remember({uid="a",account="alpha",nickname="A",refreshToken="ta"})
    store:remember({uid="b",account="beta",nickname="B",refreshToken="tb"})
    local list=store:list()
    T.equal(#list,2); T.equal(list[1].uid,"b"); T.equal(list[2].uid,"a")
    store:remember({uid="a",account="alpha",nickname="A2",refreshToken="ta2"})
    list=store:list()
    T.equal(#list,2); T.equal(list[1].uid,"a"); T.equal(list[1].nickname,"A2")
    T.equal(list[1].refreshToken,"ta2")
end)

T.test("Re-remembering an account keeps the nickname and credential it already had",function()
    local store=build()
    store:remember({uid="a",account="alpha",nickname="A",refreshToken="ta"})
    store:remember({uid="a",account="alpha"})
    local entry=store:find("a")
    T.equal(entry.nickname,"A"); T.equal(entry.refreshToken,"ta")
end)

T.test("Signing out drops the credential but keeps the account for offline use",function()
    local store,raw=build()
    store:remember({uid="a",account="alpha",nickname="A",refreshToken="ta"})
    store:clearCredential("a")
    T.equal(store:find("a").refreshToken,nil); T.equal(store:find("a").nickname,"A")
    T.equal(#store:list(),1)
    for _,entry in ipairs(raw().accounts) do T.equal(entry.password,nil); T.equal(entry.idToken,nil) end
end)

T.test("Forgetting removes only the selected account",function()
    local store=build()
    store:remember({uid="a",account="alpha",refreshToken="ta"})
    store:remember({uid="b",account="beta",refreshToken="tb"})
    store:forget("a")
    T.equal(#store:list(),1); T.equal(store:list()[1].uid,"b")
    store:forget("missing")
    T.equal(#store:list(),1)
end)

T.test("Boundary: malformed entries are ignored and the list is capped",function()
    local store=build()
    T.equal(store:remember({account="no-uid"}),nil)
    T.equal(store:remember("nonsense"),nil)
    T.equal(#store:list(),0)
    for index=1,store:limit()+3 do store:remember({uid="u"..index,account="a"..index,refreshToken="t"}) end
    local list=store:list()
    T.equal(#list,store:limit())
    T.equal(list[1].uid,"u"..(store:limit()+3))
    T.equal(store:find("u1"),nil)
end)
