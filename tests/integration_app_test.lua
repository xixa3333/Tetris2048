local T=require("test_helper")
local AppController=require("app_controller")
local AppInfo=require("app_info")

local function build(signedIn)
    local user=signedIn and {uid="u",account="u@example.com"} or nil
    local auth={user=user}
    function auth:isSignedIn() return self.user~=nil end
    function auth:currentUser() return self.user end
    function auth:signOut() self.user=nil end
    function auth:signIn(_,_,callback) self.user={uid="u",account="u@example.com"}; callback(true,self.user) end
    function auth:register(email,password,callback) self:signIn(email,password,callback) end
    function auth:restoreSession(callback) callback(false,"NO_SESSION") end
    function auth:sendPasswordReset(_,callback) callback(true,"sent") end
    function auth:changePassword(_,callback) callback(true,"changed") end
    local view={screen=nil}; function view:showCover(actions) self.screen="cover";self.actions=actions end
    function view:showUpdatePrompt(version,open) self.updateVersion=version;self.openUpdate=open end
    function view:showIntro(back) self.screen="intro";self.back=back end
    function view:showAppInfo(info,model,actions) self.screen="appInfo";self.info=info;self.model=model;self.actions=actions end
    function view:showSettings(model,save,back) self.screen="settings";self.settings=model;self.saveSettings=save;self.back=back end
    function view:showAuth(actions) self.screen="auth";self.actions=actions end
    function view:showNickname(save,back) self.screen="nickname";self.saveNickname=save;self.back=back end
    function view:showPasswordChange(save,back) self.screen="password";self.savePassword=save;self.back=back end
    function view:showAccountInfo(account,back) self.screen="account";self.account=account;self.back=back end
    function view:showLegacyMigration(save,back) self.screen="migration";self.saveMigration=save;self.back=back end
    function view:showLeaderboard(title,model,actions) self.screen=title;self.model=model;self.actions=actions end
    function view:showLoading() self.screen="loading" end
    function view:showError() self.screen="error" end
    function view:setStatus(value) self.status=value end
    function view:hide() self.screen=nil end
    local gameView={}; function gameView:setVisible(value) self.visible=value end
    local game={view=gameView,starts=0}; function game:start() self.starts=self.starts+1 end
    function game:pause() self.pauses=(self.pauses or 0)+1 end
    function game:resume() self.resumes=(self.resumes or 0)+1 end
    local localBoard={records={}}
    function localBoard:listAll() return self.records end
    function localBoard:add(uid,account,score) self.records[#self.records+1]={id=tostring(#self.records+1),uid=uid,account=account,score=score} end
    function localBoard:remove(uid,id) self.removed={uid=uid,id=id}; return true end
    local global={adds=0,records={}}; function global:list(callback)
        local ownRank=nil
        for rank,record in ipairs(self.records) do if record.uid=="u" then ownRank=rank; break end end
        callback(true,self.records,ownRank)
    end
    function global:add(_,callback) self.adds=self.adds+1;callback(true) end
    function global:updateNickname(callback) callback(true) end
    local profile={}
    function profile:get(callback) auth.user.nickname="測試玩家"; callback(true,"測試玩家") end
    function profile:save(nickname,callback) auth.user.nickname=nickname; callback(true,nickname) end
    function profile:deleteCurrent(callback) callback(true) end
    local migration={}
    function migration:migrate(account,password,callback)
        auth.user={uid="new-u",account=account,nickname="測試玩家",isLegacy=false}; callback(true,"migrated")
    end
    local settings={value={backgroundVolume=15,effectVolume=40,seed=""}}
    function settings:get() return {backgroundVolume=self.value.backgroundVolume,effectVolume=self.value.effectVolume,seed=self.value.seed} end
    function settings:update(value) self.value=value; return value end
    local update={result={updateAvailable=false}}
    function update:check(callback) callback(true,self.result) end
    local platform={exits=0,urls={}}; function platform:exit() self.exits=self.exits+1 end
    function platform:openURL(url) self.urls[#self.urls+1]=url; return true end
    return AppController.new({view=view,game=game,auth=auth,profile=profile,localBoard=localBoard,
        globalBoard=global,migration=migration,settings=settings,update=update,platform=platform,info=AppInfo,clock=function() return 1 end}),view,game,localBoard,global,platform,update
end

T.test("Cover routes to game and intro without coupling game logic to screens",function()
    local app,view,game=build(false); app:start(); T.equal(view.screen,"cover")
    view.actions.intro(); T.equal(view.screen,"intro"); view.back(); T.equal(view.screen,"cover")
    view.actions.start(); T.equal(game.starts,1); T.equal(game.view.visible,true)
end)

T.test("Cover settings route persists volume and seed then returns to cover",function()
    local app,view=build(false); app:start(); view.actions.settings()
    T.equal(view.screen,"settings"); T.equal(view.settings.backgroundVolume,15)
    view.saveSettings({backgroundVolume=55,effectVolume=70,seed="friends-01"})
    T.equal(view.screen,"cover"); T.equal(app.settings:get().backgroundVolume,55)
    T.equal(app.settings:get().seed,"friends-01")
end)

T.test("Startup update prompt opens only the trusted latest release link",function()
    local app,view,_,_,_,platform,update=build(false)
    update.result={updateAvailable=true,version="2.3.8",url=AppInfo.latestReleaseUrl}
    app:start(); T.equal(view.updateVersion,"2.3.8")
    view.openUpdate(); T.equal(platform.urls[1],AppInfo.latestReleaseUrl)
end)

T.test("Signed-in ID account is immutable and nickname remains independent",function()
    local app,view=build(true); app.auth.user.nickname="原暱稱"; app:showLocalLeaderboard(); view.actions.account()
    T.equal(view.screen,"account"); T.equal(view.account,"u@example.com")
    T.equal(app.auth:currentUser().account,"u@example.com")
    T.equal(app.auth:currentUser().nickname,"原暱稱")
end)

T.test("Legacy email account is prompted once and migrates to an immutable ID",function()
    local app,view=build(true); app.auth.user.isLegacy=true; app:openLeaderboard()
    T.equal(view.screen,"migration"); view.saveMigration("permanent_id","123456")
    T.equal(view.screen,"本機排行榜"); T.equal(app.auth:currentUser().account,"permanent_id")
    view.actions.account(); T.equal(view.screen,"account"); T.equal(view.account,"permanent_id")
end)

T.test("Cover APP information routes through versions and safe GitHub links",function()
    local app,view,_,_,_,platform=build(false); app:start()
    T.equal(view.actions.version,"2.3.7")
    view.actions.info()
    T.equal(app.screen,"appInfo"); T.equal(view.model.items[1].version,"2.3.7")
    view.actions.repository(); view.actions.issues(); view.actions.author()
    T.equal(platform.urls[1],"https://github.com/xixa3333/Tetris2048")
    T.equal(platform.urls[2],"https://github.com/xixa3333/Tetris2048/issues")
    T.equal(platform.urls[3],"https://github.com/xixa3333")
    T.equal(app:openExternal("https://example.com/phishing"),false)
    T.equal(#platform.urls,3)
    view.actions.next(); T.equal(view.model.items[1].version,"2.3.6")
    app:onResume(); T.equal(view.screen,"appInfo"); T.equal(view.model.items[1].version,"2.3.6")
    view.actions.previous(); T.equal(view.model.items[1].version,"2.3.7")
    view.actions.back(); T.equal(view.screen,"cover")
end)

T.test("Auth screen exposes forgot password and signed-in account can change password",function()
    local app,view=build(false); app:openLeaderboard(); view.actions.forgot("u@example.com")
    T.equal(view.status,"sent")
    view.actions.login("u@example.com","123456"); view.actions.password()
    T.equal(view.screen,"password"); view.savePassword("654321")
    T.equal(view.screen,"本機排行榜")
end)

T.test("App resume restores the game and falls back to cover on recovery failure",function()
    local app,view,game=build(false); app:startGame(); app:onSuspend(); app:onResume()
    T.equal(game.pauses,1); T.equal(game.resumes,1)
    game.resume=function() error("GPU lost") end; app:onResume(); T.equal(app.screen,"cover"); T.equal(view.screen,"cover")
end)

T.test("Leaderboard requires login and records every signed-in game",function()
    local app,view,_,localBoard,global=build(false); app:openLeaderboard(); T.equal(view.screen,"auth")
    view.actions.login("u@example.com","123456"); T.equal(view.screen,"本機排行榜")
    app:onGameOver(80); app:onGameOver(20)
    T.equal(#localBoard.records,2); T.equal(global.adds,2)
end)

T.test("Local leaderboard ignores zero and shows scores from every local account",function()
    local app,view,_,localBoard,global=build(true)
    localBoard.records={
        {id="a1",uid="a",account="玩家A",score=40},
        {id="b1",uid="b",account="玩家B",score=20}}
    app:showLocalLeaderboard()
    T.equal(view.screen,"本機排行榜"); T.equal(#view.model.items,2)
    app:onGameOver(0)
    T.equal(#localBoard.records,2); T.equal(global.adds,1)
    view.actions.delete(view.model.items[2])
    T.equal(localBoard.removed.uid,"b"); T.equal(localBoard.removed.id,"b1")
end)

T.test("Local and global leaderboards navigate ten records per page",function()
    local app,view,_,localBoard,global=build(true)
    for index=1,21 do
        localBoard.records[index]={id=tostring(index),uid="u",account="本機",score=100-index}
        global.records[index]={id=tostring(index),uid=tostring(index),nickname="全球",score=100-index}
    end
    global.records[1].uid="u"
    app:showLocalLeaderboard(1)
    T.equal(#view.model.items,10); T.equal(view.model.firstRank,1); T.equal(view.model.totalPages,3)
    view.actions.next(); T.equal(view.model.page,2); T.equal(view.model.firstRank,11)
    view.actions.next(); T.equal(#view.model.items,1); T.equal(view.model.firstRank,21)
    view.actions.globalTab(); T.equal(view.screen,"全球排行榜"); T.equal(view.model.page,1)
    T.equal(view.model.ownRank,1)
    view.actions.next(); T.equal(view.model.page,2); T.equal(#view.model.items,10)
    view.actions.previous(); T.equal(view.model.page,1)
end)
