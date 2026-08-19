local T=require("test_helper")
local AppController=require("app_controller")
local AppInfo=require("app_info")
local SettingsService=require("settings_service")

local function build(signedIn)
    local user=signedIn and {uid="u",account="u@example.com",nickname="Player"} or nil
    local auth={user=user}
    function auth:isSignedIn() return self.user~=nil end
    function auth:currentUser() return self.user end
    function auth:signOut() self.user=nil end
    function auth:signIn(_,_,callback) self.calledWith="signIn"; self.user={uid="u",account="u@example.com",nickname="Player"}; callback(true,self.user) end
    function auth:register(email,password,callback) self:signIn(email,password,callback); self.calledWith="register" end
    function auth:restoreSession(callback) callback(false,"NO_SESSION") end
    function auth:isOffline() return self.offline==true end
    function auth:rememberedAccounts() return self.remembered or {} end
    function auth:signInWithAccount(uid,callback)
        for _,entry in ipairs(self.remembered or {}) do
            if entry.uid==uid then
                self.user={uid=entry.uid,account=entry.account,nickname=entry.nickname,
                    offline=entry.hasCredential~=true}
                self.offline=self.user.offline
                callback(true,self.user); return
            end
        end
        callback(false,"找不到這個快捷登入帳號")
    end
    function auth:forgetAccount(uid)
        local kept={}
        for _,entry in ipairs(self.remembered or {}) do
            if entry.uid~=uid then kept[#kept+1]=entry end
        end
        self.remembered=kept
        if self.user and self.user.uid==uid then self.user=nil end
    end
    function auth:rememberNickname(nickname) if self.user then self.user.nickname=nickname end end
    function auth:sendPasswordReset(_,callback) callback(true,"sent") end
    function auth:changePassword(_,callback) callback(true,"changed") end
    function auth:deleteAccount(callback) self.deleted=true; self.user=nil; self.remembered=nil; callback(true,"帳號已刪除") end

    local view={screen=nil}
    function view:showCover(actions) self.screen="cover"; self.actions=actions end
    function view:showModeSelect(start,back) self.screen="modeSelect"; self.startMode=start; self.back=back end
    function view:showUpdatePrompt(version,open) self.updatePrompts=(self.updatePrompts or 0)+1; self.updateVersion=version; self.openUpdate=open end
    function view:showIntro(back) self.screen="intro"; self.back=back end
    function view:showAppInfo(info,model,actions) self.screen="appInfo"; self.info=info; self.model=model; self.actions=actions end
    function view:showSettings(model,save,back,preview) self.screen="settings"; self.settings=model; self.saveSettings=save; self.back=back; self.previewSettings=preview end
    function view:showAuth(actions) self.screen="auth"; self.actions=actions end
    function view:showShortcutAccounts(accounts,actions) self.screen="shortcut"; self.accounts=accounts; self.actions=actions end
    function view:showNickname(save,back) self.screen="nickname"; self.saveNickname=save; self.back=back end
    function view:showPasswordChange(save,back) self.screen="password"; self.savePassword=save; self.back=back end
    function view:showAccountInfo(account,back,onDelete) self.screen="account"; self.account=account; self.back=back; self.deleteAccount=onDelete end
    function view:showLegacyMigration(save,back) self.screen="migration"; self.saveMigration=save; self.back=back end
    function view:showLeaderboard(title,model,actions,deletable) self.screen=title; self.model=model; self.actions=actions; self.deletable=deletable end
    function view:showLoading() self.screen="loading" end
    function view:showError() self.screen="error" end
    function view:setStatus(value) self.status=value end
    function view:showNotice(message) self.notices=(self.notices or 0)+1; self.notice=message end
    function view:confirm(message,onConfirm) self.confirmed=message; onConfirm() end
    function view:hide() self.screen=nil end

    local gameView={}
    function gameView:setVisible(value) self.visible=value end
    local game={view=gameView,starts=0}
    function game:start() self.starts=self.starts+1 end
    function game:setMode(mode) self.mode=mode end
    function game:pause() self.pauses=(self.pauses or 0)+1 end
    function game:resume() self.resumes=(self.resumes or 0)+1 end

    local localBoard={records={}}
    function localBoard:listAll(mode)
        local records={}
        for _,record in ipairs(self.records) do if (record.mode or 1)==(mode or 1) then records[#records+1]=record end end
        return records
    end
    function localBoard:list(uid,mode)
        local records={}
        for _,record in ipairs(self.records) do
            if record.uid==uid and (record.mode or 1)==(mode or 1) then records[#records+1]=record end
        end
        table.sort(records,function(left,right) return left.score>right.score end)
        return records
    end
    function localBoard:add(uid,account,score,playedAt,mode)
        self.records[#self.records+1]={id=tostring(#self.records+1),uid=uid,account=account,score=score,playedAt=playedAt,mode=mode or 1}
    end
    function localBoard:remove(uid,id) self.removed={uid=uid,id=id}; return true end

    local global={adds=0,records={},deletes={}}

    function global:list(callback,mode)
        local records={}
        for _,record in ipairs(self.records) do if (record.mode or 1)==(mode or 1) then records[#records+1]=record end end
        local ownRank=nil
        for rank,record in ipairs(records) do if record.uid=="u" then ownRank=rank; break end end
        callback(true,records,ownRank)
    end
    function global:add(_,callback,mode) self.adds=self.adds+1; self.lastMode=mode or 1; callback(true) end
    function global:updateNickname(callback) callback(true) end
    function global:deleteCurrent(callback,mode) self.deletes[#self.deletes+1]=mode; callback(true) end

    local profile={}
    function profile:get(callback) auth.user.nickname="Player"; callback(true,"Player") end
    function profile:save(nickname,callback) auth.user.nickname=nickname; callback(true,nickname) end
    function profile:deleteCurrent(callback) self.deleted=true; callback(true) end
    local migration={}
    function migration:migrate(account,password,callback) auth.user={uid="new-u",account=account,nickname="Player",isLegacy=false}; callback(true,"migrated") end
    local storage={data={},writes=0}
    function storage:load() return self.data end
    function storage:save(data) self.writes=self.writes+1; self.data=data end
    local settings=SettingsService.new(storage)
    local update={result={updateAvailable=false}}
    function update:check(callback) callback(true,self.result) end
    local platform={exits=0,urls={}}
    function platform:exit() self.exits=self.exits+1 end
    function platform:openURL(url) self.urls[#self.urls+1]=url; return true end
    local sound={plays=0,stops=0,samples=0}
    function sound:playBackground() self.plays=self.plays+1 end
    function sound:stopBackground() self.stops=self.stops+1 end
    function sound:playEliminate() self.samples=self.samples+1 end

    return AppController.new({view=view,game=game,auth=auth,profile=profile,localBoard=localBoard,
        globalBoard=global,migration=migration,settings=settings,update=update,platform=platform,info=AppInfo,sound=sound,
        musicTracks={{id="BackGround_01_A.mp3",name="A"},{id="BackGround_02_B.mp3",name="B"}},clock=function() return 1 end}),
        view,game,localBoard,global,platform,update,sound,storage
end

T.test("Cover routes to mode selection, game and intro",function()
    local app,view,game,_,_,_,_,sound=build(false); app:start(); T.equal(view.screen,"cover"); T.equal(sound.plays,1)
    view.actions.intro(); T.equal(view.screen,"intro"); view.back(); T.equal(view.screen,"cover")
    view.actions.start(); T.equal(view.screen,"modeSelect")
    view.startMode(1); T.equal(game.starts,1); T.equal(game.mode,1); T.equal(game.view.visible,true)
end)

T.test("Mode selection starts classic or relaxed rules before the game screen",function()
    local app,view,game=build(false); app:start(); view.actions.start()
    view.startMode(2); T.equal(app.currentMode,2); T.equal(game.mode,2)
end)

T.test("Cover settings route persists volume and seed then returns to cover",function()
    local app,view=build(false); app:start(); view.actions.settings()
    T.equal(view.screen,"settings"); view.saveSettings({backgroundVolume=55,effectVolume=70,seed="friends-01"})
    T.equal(view.screen,"cover"); T.equal(app.settings:get().backgroundVolume,55); T.equal(app.settings:get().seed,"friends-01")
    T.equal(#view.settings.musicTracks,2)
end)

T.test("Startup update prompt opens only the trusted latest release link",function()
    local app,view,_,_,_,platform,update=build(false)
    update.result={updateAvailable=true,version="2.3.9",url=AppInfo.latestReleaseUrl}
    app:start(); T.equal(view.updateVersion,"2.3.9")
    view.openUpdate(); T.equal(platform.urls[1],AppInfo.latestReleaseUrl)
end)

T.test("Signed-in ID account is immutable and nickname remains independent",function()
    local app,view=build(true); app.auth.user.nickname="Player"; app:showLocalLeaderboard(); view.actions.account()
    T.equal(view.screen,"account"); T.equal(view.account,"u@example.com")
    T.equal(app.auth:currentUser().nickname,"Player")
end)

T.test("Legacy email account is prompted once and migrates to an immutable ID",function()
    local app,view=build(true); app.auth.user.isLegacy=true; app:openLeaderboard()
    T.equal(view.screen,"migration"); view.saveMigration("permanent_id","123456")
    T.equal(view.screen,"本機排行榜 - 模式1"); T.equal(app.auth:currentUser().account,"permanent_id")
end)

T.test("Cover APP information routes through versions and safe GitHub links",function()
    local app,view,_,_,_,platform=build(false); app:start()
    T.equal(view.actions.version,"2.5.0"); T.equal(view.actions.displayName,"BlockMerge 2048"); view.actions.info()
    T.equal(app.screen,"appInfo"); T.equal(view.model.items[1].version,"2.5.0")
    view.actions.repository(); view.actions.issues(); view.actions.author()
    T.equal(platform.urls[1],"https://github.com/xixa3333/Tetris2048")
    T.equal(platform.urls[2],"https://github.com/xixa3333/Tetris2048/issues")
    T.equal(platform.urls[3],"https://github.com/xixa3333")
    T.equal(app:openExternal("https://testflight.apple.com/join/vpY5718p"),false)
    T.equal(app:openExternal("https://example.com/phishing"),false)
    view.actions.next(); T.equal(view.model.items[1].version,"2.4.1")
    app:onResume(); T.equal(view.screen,"appInfo"); T.equal(view.model.items[1].version,"2.4.1")
    view.actions.previous(); T.equal(view.model.items[1].version,"2.5.0")
end)

T.test("Auth screen exposes forgot password and signed-in account can change password",function()
    local app,view=build(false); app:openLeaderboard(); view.actions.forgot("u@example.com")
    T.equal(view.status,"sent")
    view.actions.login("u@example.com","123456"); view.actions.password()
    T.equal(view.screen,"password"); view.savePassword("654321")
    T.equal(view.screen,"本機排行榜 - 模式1")
end)

T.test("App resume restores the game and falls back to cover on recovery failure",function()
    local app,view,game,_,_,_,_,sound=build(false); app:startGame(); app:onSuspend(); app:onResume()
    T.equal(game.pauses,1); T.equal(game.resumes,1); T.equal(sound.stops,1); T.equal(sound.plays,1)
    game.resume=function() error("GPU lost") end; app:onResume(); T.equal(app.screen,"cover"); T.equal(view.screen,"cover")
end)

T.test("Leaderboard requires login and records every signed-in game by mode",function()
    local app,view,_,localBoard,global=build(false); app:openLeaderboard(); T.equal(view.screen,"auth")
    view.actions.login("u@example.com","123456"); T.equal(app.auth.calledWith,"signIn")
    app:startGame(2); app:onGameOver(80); app:onGameOver(20)
    T.equal(#localBoard.records,2); T.equal(localBoard.records[1].mode,2); T.equal(global.adds,2); T.equal(global.lastMode,2)
    -- 注入的時鐘是紀錄時間的唯一來源。
    T.equal(localBoard.records[1].playedAt,1)
    app.auth:signOut(); app:openLeaderboard(); view.actions.register("new@example.com","123456")
    T.equal(app.auth.calledWith,"register")
end)

T.test("Local leaderboard ignores zero and filters records by selected mode",function()
    local app,view,_,localBoard,global=build(true)
    localBoard.records={{id="a1",uid="a",account="PlayerA",score=40,mode=1},{id="b1",uid="b",account="PlayerB",score=20,mode=2}}
    app:showLocalLeaderboard(); T.equal(view.screen,"本機排行榜 - 模式1"); T.equal(#view.model.items,1)
    view.actions.mode2(); T.equal(view.screen,"本機排行榜 - 模式2"); T.equal(#view.model.items,1)
    -- 0 分既不進本機排行榜，也不會產生任何雲端寫入。
    app:onGameOver(0); T.equal(#localBoard.records,2); T.equal(global.adds,0)
    app:onGameOver("abc"); T.equal(#localBoard.records,2); T.equal(global.adds,0)
    view.actions.delete(view.model.items[1]); T.equal(localBoard.removed.uid,"b"); T.equal(localBoard.removed.id,"b1")
end)

T.test("Local and global leaderboards navigate ten records per page by mode",function()
    local app,view,_,localBoard,global=build(true)
    for index=1,21 do
        localBoard.records[index]={id=tostring(index),uid="u",account="Player",score=100-index,mode=1}
        global.records[index]={id=tostring(index),uid=tostring(index),nickname="Player",score=100-index,mode=1}
    end
    global.records[1].uid="u"
    app:showLocalLeaderboard(1); T.equal(#view.model.items,10); T.equal(view.model.totalPages,3)
    view.actions.next(); T.equal(view.model.page,2); view.actions.next(); T.equal(#view.model.items,1)
    view.actions.previous(); T.equal(view.model.page,2)
    view.actions.previous(); T.equal(view.model.page,1); T.equal(#view.model.items,10)
    view.actions.next(); T.equal(view.model.page,2)
    view.actions.globalTab(); T.equal(view.screen,"全球排行榜 - 模式1"); T.equal(view.model.ownRank,1)
    view.actions.next(); T.equal(view.model.page,2); view.actions.previous(); T.equal(view.model.page,1)
end)

T.test("Grouped screens restore themselves in the foreground while mode selection falls back",function()
    local app,view=build(true)
    app:showSettings(); app:onResume(); T.equal(app.screen,"settings"); T.equal(view.screen,"settings")
    app:showModeSelect(); app:onResume(); T.equal(app.screen,"cover"); T.equal(view.screen,"cover")
    for index=1,21 do app.localBoard.records[index]={id=tostring(index),uid="u",account="Player",score=100-index,mode=1} end
    app:showLocalLeaderboard(2); app:onResume()
    T.equal(app.screen,"localLeaderboard"); T.equal(view.model.page,2)
end)

T.test("Shared back and suspend transitions are declared once on the parent states",function()
    local app,view,game=build(true)
    app:showLocalLeaderboard(); view.actions.back(); T.equal(app.screen,"cover")
    app:showAccountInfo(); T.equal(app.screen,"account")
    app:onSuspend(); T.equal(game.pauses,nil)
    app:startGame(1); app:onSuspend(); T.equal(game.pauses,1)
end)

T.test("Startup stays silent when the release check finds nothing newer",function()
    local app,view,_,_,_,_,update=build(false)
    app:start(); T.equal(view.updatePrompts,nil); T.equal(view.updateVersion,nil)
    local offline,offlineView=build(false)
    offline.update.check=function(_,callback) callback(false) end
    offline:start(); T.equal(offlineView.updatePrompts,nil); T.equal(offlineView.screen,"cover")
    T.equal(update.result.updateAvailable,false)
end)

T.test("Only local records can be deleted by the player",function()
    local app,view=build(true)
    app:showLocalLeaderboard(); T.equal(view.deletable,true); T.truthy(view.actions.delete)
    app:showGlobalLeaderboard(); T.equal(view.deletable,false)
end)

T.test("APP keeps running when no audio service is available",function()
    local app,view,game=build(false); app.sound=nil
    app:start(); T.equal(view.screen,"cover")
    app:startGame(1); app:onSuspend(); app:onResume()
    T.equal(game.pauses,1); T.equal(game.resumes,1); T.equal(app.screen,"game")
end)

T.test("Missing collaborators are rejected before the APP can start",function()
    local required={"view","game","auth","profile","localBoard","globalBoard","migration",
        "settings","update","platform","info"}
    local function complete()
        local dependencies={}
        for _,key in ipairs(required) do dependencies[key]={} end
        return dependencies
    end
    T.equal(pcall(AppController.new,{}),false)
    T.equal(pcall(AppController.new,complete()),true)
    for _,key in ipairs(required) do
        local dependencies=complete(); dependencies[key]=nil
        T.equal(pcall(AppController.new,dependencies),false,"missing dependency was accepted: "..key)
    end
end)

T.test("Remembered logins load the player profile before the cover is redrawn",function()
    local app,view=build(false)
    local loaded=0
    app.auth.restoreSession=function(self,callback) self.user={uid="u",account="player_01"}; callback(true,self.user) end
    app.profile.get=function(_,callback) loaded=loaded+1; app.auth.user.nickname="玩家"; callback(true,"玩家") end
    app:showCover(); app:restoreLogin()
    T.equal(loaded,1); T.equal(view.screen,"cover")
    T.equal(app.auth:currentUser().nickname,"玩家")
    local offline=build(false); local skipped=0
    offline.profile.get=function(_,callback) skipped=skipped+1; callback(true,nil) end
    offline:restoreLogin(); T.equal(skipped,0)
end)

T.test("External links stay restricted to GitHub even if the info file changes",function()
    local app,_,_,_,_,platform=build(false)
    app.info={currentVersion="9.9.9",displayName="測試",versions={},
        repositoryUrl="https://evil.example.com/repo",
        issuesUrl="https://github.com/xixa3333/Tetris2048/issues",
        authorUrl="https://github.com/xixa3333",
        latestReleaseUrl="https://github.com/xixa3333/Tetris2048/releases/latest"}
    T.equal(app:openExternal("https://evil.example.com/repo"),false)
    T.equal(#platform.urls,0)
    T.equal(app:openExternal("https://github.com/xixa3333/Tetris2048/issues"),true)
    T.equal(#platform.urls,1)
end)

T.test("Settings preview applies immediately but only saving keeps it",function()
    local app,view,_,_,_,_,_,sound,storage=build(false)
    app:showSettings()
    local model=view.settings
    model.backgroundVolume=90; model.backgroundTrack="BackGround_02_B.mp3"
    view.previewSettings(model,"background")
    T.equal(app.settings:get().backgroundVolume,90)
    T.equal(app.settings:get().backgroundTrack,"BackGround_02_B.mp3")
    T.equal(storage.writes,0); T.equal(sound.samples,0)

    model.effectVolume=80; view.previewSettings(model,"effect")
    T.equal(app.settings:get().effectVolume,80); T.equal(sound.samples,1)

    view.back()
    T.equal(view.screen,"cover")
    T.equal(app.settings:get().backgroundVolume,15)
    T.equal(app.settings:get().effectVolume,40)
    T.equal(app.settings:get().backgroundTrack,"")
    T.equal(storage.writes,0)
end)

T.test("Saved settings survive leaving the screen and later previews",function()
    local app,view,_,_,_,_,_,_,storage=build(false)
    app:showSettings()
    local model=view.settings
    model.backgroundVolume=70; model.seed="friends-01"
    view.previewSettings(model,"background")
    view.saveSettings(model)
    T.equal(view.screen,"cover"); T.equal(storage.writes,1)
    T.equal(app.settings:get().backgroundVolume,70); T.equal(app.settings:get().seed,"friends-01")

    app:showSettings()
    local second=view.settings
    second.backgroundVolume=5
    view.previewSettings(second,"background")
    T.equal(app.settings:get().backgroundVolume,5)
    app:onResume()
    -- 回前景會重繪設定頁，未儲存的預覽在離開狀態時就被還原。
    T.equal(view.screen,"settings"); T.equal(app.settings:get().backgroundVolume,70)
    T.equal(storage.writes,1)
end)

T.test("An offline player keeps playing, records locally and skips cloud writes",function()
    local app,view,_,localBoard,global=build(true)
    app.auth.offline=true
    app:openLeaderboard()
    T.equal(view.screen,"本機排行榜 - 模式1")
    T.equal(view.model.playerName,"Player"); T.equal(view.model.offline,true)
    app:startGame(1); app:onGameOver(120)
    T.equal(#localBoard.records,1); T.equal(localBoard.records[1].score,120)
    -- 離線期間不做無謂的雲端請求，恢復連線後由全球排行榜自動補傳。
    T.equal(global.adds,0)
    app.auth.offline=false; app:onGameOver(150)
    T.equal(#localBoard.records,2); T.equal(global.adds,1)
end)

T.test("A device that never signed in still keeps its scores locally",function()
    local app,view,_,localBoard,global=build(false)
    app:startGame(1); app:onGameOver(60)
    T.equal(#localBoard.records,1)
    T.equal(localBoard.records[1].uid,"local-guest")
    T.equal(localBoard.records[1].account,"訪客")
    T.equal(global.adds,0)
    -- 之後登入不會把訪客紀錄併到帳號上，但本機排行榜仍然看得到。
    app:openLeaderboard(); view.actions.login("u@example.com","123456")
    T.equal(view.screen,"本機排行榜 - 模式1")
    T.equal(#view.model.items,1); T.equal(view.model.items[1].uid,"local-guest")
    T.equal(view.model.playerName,"Player"); T.equal(view.model.offline,false)
end)

T.test("Scores played offline are uploaded automatically once the APP starts online",function()
    local app,_,_,localBoard,global=build(true)
    -- 先模擬離線期間留下的本機紀錄。
    localBoard.records={{id="1",uid="u",account="Player",score=90,mode=1},
        {id="2",uid="u",account="Player",score=45,mode=2}}
    app.auth.restoreSession=function(self,callback) callback(true,self.user) end
    app:restoreLogin()
    T.equal(global.adds,2); T.equal(global.lastMode,2)
    -- 分數沒有變化就不會重複上傳。
    app:openLeaderboard(); T.equal(global.adds,2)
end)

T.test("Syncing waits until the session really has a connection",function()
    local app,_,_,localBoard,global=build(true)
    localBoard.records={{id="1",uid="u",account="Player",score=90,mode=1}}
    app.auth.offline=true
    app.auth.restoreSession=function(self,callback) callback(true,self.user) end
    app:restoreLogin()
    T.equal(global.adds,0)
    -- 回到前景時重新換發憑證，成功後才會補傳。
    app.auth.restoreSession=function(self,callback) self.offline=false; callback(true,self.user) end
    app:onResume()
    T.equal(global.adds,1)
    T.equal(app.auth:isOffline(),false)
end)

T.test("Only the best local score of each mode is uploaded",function()
    local app,_,_,localBoard,global=build(true)
    localBoard.records={{id="1",uid="u",account="Player",score=10,mode=1},
        {id="2",uid="u",account="Player",score=70,mode=1},
        {id="3",uid="u",account="Player",score=30,mode=1}}
    local uploaded={}
    global.add=function(self,score,callback,mode) self.adds=self.adds+1; uploaded[#uploaded+1]=score; callback(true) end
    app:syncLocalScores()
    T.equal(#uploaded,1); T.equal(uploaded[1],70)
end)

T.test("An offline session may only read the local board and record new scores",function()
    local app,view,_,localBoard,global=build(true)
    app.auth.offline=true
    localBoard.records={{id="1",uid="u",account="Player",score=40,mode=1}}
    app:openLeaderboard()
    T.equal(view.screen,"本機排行榜 - 模式1")

    -- 需要憑證的功能一律擋下，不會離開排行榜也不會送出請求。
    for _,action in ipairs({"globalTab","nickname","password"}) do
        view.actions[action]()
        T.equal(view.screen,"本機排行榜 - 模式1","offline action left the screen: "..action)
    end
    T.equal(view.notices,3); T.truthy(view.notice:find("離線中"))
    T.equal(global.adds,0); T.equal(app.auth:isSignedIn(),true)

    -- 純本機的操作照常可用。
    view.actions.mode2(); T.equal(view.screen,"本機排行榜 - 模式2")
    view.actions.mode1(); app:onGameOver(90)
    T.equal(#localBoard.records,2); T.equal(global.adds,0)
    view.actions.delete(view.model.items[1]); T.equal(localBoard.removed.uid,"u")
    view.actions.back(); T.equal(view.screen,"cover")

    -- 恢復連線後功能全部回來。
    app.auth.offline=false; app:showLocalLeaderboard(1)
    view.actions.nickname(); T.equal(view.screen,"nickname")
    T.equal(view.notices,3)
end)

T.test("Logging out keeps the remembered account for a shortcut sign-in",function()
    local app,view,_,localBoard,global=build(true)
    localBoard.records={{id="1",uid="u",account="Player",score=40,mode=1}}
    app:showLocalLeaderboard(1)
    view.actions.logout()
    T.equal(view.screen,"cover"); T.equal(app.auth:isSignedIn(),false)

    -- 已登出但這台裝置記得帳號：登入畫面提供快捷登入入口。
    app.auth.remembered={{uid="u",account="u@example.com",nickname="Player",name="Player",hasCredential=false}}
    app:openLeaderboard()
    T.equal(view.screen,"auth"); T.truthy(view.actions.shortcut)
    view.actions.shortcut()
    T.equal(view.screen,"shortcut"); T.equal(#view.accounts,1); T.equal(view.accounts[1].name,"Player")
    view.actions.select(view.accounts[1])
    T.equal(view.screen,"本機排行榜 - 模式1")
    T.equal(app.auth:isSignedIn(),true); T.equal(app.auth:isOffline(),true)
    T.equal(view.model.playerName,"Player"); T.equal(view.model.offline,true)
    -- 沒有憑證就沒有雲端權限。
    view.actions.globalTab(); T.equal(view.screen,"本機排行榜 - 模式1")
    app:onGameOver(75); T.equal(#localBoard.records,2); T.equal(global.adds,0)
end)

T.test("A shortcut sign-in with a valid credential restores full access",function()
    local app,view,_,localBoard,global=build(false)
    localBoard.records={{id="1",uid="u",account="Player",score=55,mode=1}}
    app.auth.remembered={{uid="u",account="u@example.com",nickname="Player",name="Player",hasCredential=true}}
    app:openLeaderboard()
    view.actions.shortcut()
    T.equal(view.screen,"shortcut")
    view.actions.select(view.accounts[1])
    T.equal(app.auth:isSignedIn(),true); T.equal(app.auth:isOffline(),false)
    T.equal(view.screen,"本機排行榜 - 模式1"); T.equal(view.model.offline,false)
    T.equal(global.adds,1)
    view.actions.nickname(); T.equal(view.screen,"nickname")
end)

T.test("The shortcut screen lists every remembered account newest first",function()
    local app,view=build(false)
    app.auth.remembered={
        {uid="u2",account="second",nickname="乙",name="乙",hasCredential=true},
        {uid="u1",account="first",name="first",hasCredential=false}}
    app:openLeaderboard(); view.actions.shortcut()
    T.equal(#view.accounts,2)
    T.equal(view.accounts[1].name,"乙"); T.equal(view.accounts[1].hasCredential,true)
    T.equal(view.accounts[2].name,"first"); T.equal(view.accounts[2].hasCredential,false)
    view.actions.select(view.accounts[2])
    T.equal(app.auth:currentUser().uid,"u1"); T.equal(app.auth:isOffline(),true)
end)

T.test("A device with no remembered account has no shortcut",function()
    local app,view=build(false)
    app:openLeaderboard()
    T.equal(view.screen,"auth"); T.equal(view.actions.shortcut,nil); T.equal(view.shortcutName,nil)
end)

T.test("Removing one shortcut account keeps the others and the local records",function()
    local app,view,_,localBoard=build(false)
    localBoard.records={{id="1",uid="u",account="Player",score=40,mode=1}}
    app.auth.remembered={
        {uid="u",account="u@example.com",nickname="Player",name="Player",hasCredential=false},
        {uid="v",account="other",name="other",hasCredential=true}}
    app:openLeaderboard(); view.actions.shortcut()
    T.equal(#view.accounts,2)
    view.actions.forget(view.accounts[1])
    T.truthy(view.confirmed:find("不會刪除帳號"))
    T.equal(view.screen,"shortcut"); T.equal(#view.accounts,1); T.equal(view.accounts[1].uid,"v")

    -- 移除最後一個帳號後回到登入畫面，快捷登入入口消失。
    view.actions.forget(view.accounts[1])
    T.equal(view.screen,"auth"); T.equal(view.actions.shortcut,nil)
    T.equal(#app.auth:rememberedAccounts(),0)
    -- 排行榜紀錄與帳號本身都不受影響。
    T.equal(#localBoard.records,1)
end)

T.test("Deleting an account clears the cloud data in a safe order after confirmation",function()
    local app,view,_,localBoard,global=build(true)
    localBoard.records={{id="1",uid="u",account="Player",score=40,mode=1}}
    app:showLocalLeaderboard(1); view.actions.account()
    T.equal(view.screen,"account"); T.truthy(view.deleteAccount)
    view.deleteAccount()
    T.truthy(view.confirmed:find("無法復原"))
    -- 先刪兩個模式的全球紀錄，再刪玩家資料，最後才刪帳號本身。
    T.equal(table.concat(global.deletes,","),"1,2")
    T.equal(app.profile.deleted,true); T.equal(app.auth.deleted,true)
    T.equal(view.screen,"cover"); T.equal(app.auth:isSignedIn(),false)
    -- 這台裝置上的本機紀錄保留。
    T.equal(#localBoard.records,1)
end)

T.test("A failed cloud deletion never removes the account",function()
    local app,view,_,_,global=build(true)
    global.deleteCurrent=function(self,callback,mode) self.deletes[#self.deletes+1]=mode; callback(false) end
    app:showLocalLeaderboard(1); view.actions.account(); view.deleteAccount()
    T.equal(app.auth.deleted,nil); T.equal(app.profile.deleted,nil)
    T.equal(view.screen,"account"); T.equal(app.auth:isSignedIn(),true)

    local second,secondView=build(true)
    second.profile.deleteCurrent=function(_,callback) callback(false) end
    second:showLocalLeaderboard(1); secondView.actions.account(); secondView.deleteAccount()
    T.equal(second.auth.deleted,nil); T.equal(secondView.screen,"account")
end)

T.test("Account deletion is unavailable offline",function()
    local app,view=build(true)
    app.auth.offline=true
    app:showLocalLeaderboard(1); view.actions.account()
    view.deleteAccount()
    T.equal(view.notice,"離線中，恢復網路後才能刪除帳號")
    T.equal(app.auth.deleted,nil); T.equal(view.screen,"account")
end)
