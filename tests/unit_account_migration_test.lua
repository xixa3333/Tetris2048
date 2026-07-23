local T=require("test_helper")
local AccountMigration=require("account_migration")

local function services(failAt)
    local auth={session={uid="old",nickname="舊玩家",isLegacy=true},commits=0,rollbacks=0}
    function auth:beginLegacyMigration(_,_,callback)
        self.session={uid="new",account="new_id",nickname="舊玩家",isLegacy=false}
        callback(true,{oldUser={uid="old",nickname="舊玩家",idToken="old-token"},newUser=self.session})
    end
    function auth:currentUser() return self.session end
    function auth:commitLegacyMigration() self.commits=self.commits+1 end
    function auth:rollbackLegacyMigration(context,callback) self.rollbacks=self.rollbacks+1; self.session=context.oldUser; callback(true) end
    local profile={deleted=0}
    function profile:save(_,callback) callback(failAt~="profile",failAt=="profile" and "profile failed" or nil) end
    function profile:deleteCurrent(callback) self.deleted=self.deleted+1; callback(true) end
    local global={deleted=0}
    function global:migrateFrom(_,callback) callback(failAt~="score",failAt=="score" and "score failed" or nil) end
    function global:deleteCurrent(callback) self.deleted=self.deleted+1; callback(true) end
    return auth,profile,global
end

T.test("Legacy migration commits only after profile and score transfer",function()
    local auth,profile,global=services()
    AccountMigration.new(auth,profile,global):migrate("new_id","123456",function(ok) T.equal(ok,true) end)
    T.equal(auth.commits,1); T.equal(auth.rollbacks,0); T.equal(global.deleted,0)
end)

T.test("Legacy migration cleans partial data and restores old session on failure",function()
    for _,failure in ipairs({"profile","score"}) do
        local auth,profile,global=services(failure)
        AccountMigration.new(auth,profile,global):migrate("new_id","123456",function(ok) T.equal(ok,false) end)
        T.equal(auth.commits,0); T.equal(auth.rollbacks,1)
        T.equal(profile.deleted,1); T.equal(global.deleted,1); T.equal(auth.session.uid,"old")
    end
end)
