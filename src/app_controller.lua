local Pagination=require("pagination")
local GUEST_UID="local-guest"
local GUEST_NAME="訪客"
local StateMachine=require("state_machine")
-- APP 控制器：畫面流程改由階層式狀態機描述。
-- 群組狀態（menu / identity / leaderboard / game）持有共用的返回與前景恢復行為，
-- 子狀態只描述自己要顯示什麼，因此新增畫面不必再修改 onResume 的長串判斷。
local AppController={}; AppController.__index=AppController

-- 自我轉移代表「用目前的分頁與資料重新顯示同一個畫面」。
local function restore(_,_,current) return current end

local SCREEN_STATES={
    app={initial="boot",on={back="cover",resume="cover"}},
    boot={parent="app"},
    cover={parent="app",enter=function(app) app:_renderCover() end},
    menu={parent="app",on={resume=restore}},
    intro={parent="menu",enter=function(app) app:_renderIntro() end},
    appInfo={parent="menu",enter=function(app) app:_renderAppInfo() end},
    -- 設定頁支援即時預覽；沒有按儲存就離開（取消、返回、回前景重繪）一律還原。
    settings={parent="menu",enter=function(app) app:_renderSettings() end,
        exit=function(app) app.settings:revert() end},
    -- 選模式停在半途沒有意義，回前景時直接退回封面。
    modeSelect={parent="menu",enter=function(app) app:_renderModeSelect() end,on={resume="cover"}},
    identity={parent="app"},
    auth={parent="identity",enter=function(app) app:_renderAuth() end,
        on={resume=function(app) app:openLeaderboard() end}},
    shortcut={parent="identity",enter=function(app) app:_renderShortcut() end,on={resume="auth"}},
    loading={parent="identity",enter=function(app) app.view:showLoading(app.loadingMessage) end},
    nickname={parent="identity",enter=function(app) app:_renderNickname() end},
    password={parent="identity",enter=function(app) app:_renderPasswordChange() end},
    account={parent="identity",enter=function(app) app:_renderAccountInfo() end},
    accountMigration={parent="identity",enter=function(app) app:_renderLegacyMigration() end},
    leaderboard={parent="app",on={resume=restore}},
    localLeaderboard={parent="leaderboard",enter=function(app) app:_renderLocalLeaderboard() end},
    globalLeaderboard={parent="leaderboard",enter=function(app) app:_renderGlobalLeaderboard() end},
    game={parent="app",enter=function(app) app:_enterGame() end,
        on={suspend=function(app) app.game:pause() end,resume=function(app) app.game:resume() end}}
}

function AppController.new(d)
    assert(d.view and d.game and d.auth and d.profile and d.localBoard and d.globalBoard and d.migration and d.settings and d.update and d.platform and d.info)
    local app=setmetatable({view=d.view,game=d.game,auth=d.auth,profile=d.profile,
        localBoard=d.localBoard,globalBoard=d.globalBoard,migration=d.migration,settings=d.settings,update=d.update,platform=d.platform,info=d.info,sound=d.sound,
        musicTracks=d.musicTracks or {},
        clock=d.clock or os.time,screen="boot",localPage=1,globalPage=1,infoPage=1},AppController)
    -- screen 仍然是目前葉狀態的名稱，讓既有呼叫端與測試不需要認識狀態機內部。
    app.machine=StateMachine.new({owner=app,states=SCREEN_STATES,initial="app",
        onChange=function(owner,state) owner.screen=state end})
    return app
end
function AppController:start()
    if self.sound and self.sound.playBackground then self.sound:playBackground() end
    self:showCover()
    self.update:check(function(ok,result)
        if ok and result.updateAvailable then
            self.view:showUpdatePrompt(result.version,function() self:openExternal(result.url) end)
        end
    end)
end
function AppController:restoreLogin()
    self.auth:restoreSession(function(ok)
        if not ok then return end
        self.profile:get(function()
            self:syncLocalScores()
            if self.machine:isIn("cover") then self:showCover() end
        end)
    end)
end
-- 離線期間打的分數不需要玩家特地進全球排行榜才會上傳：
-- 只要有網路且身分就緒（開啟遊戲、登入完成、回前景換發憑證成功）就自動補傳。
-- 每個模式只送目前的本機最高分，且分數沒變就不重送。
function AppController:syncLocalScores(onComplete)
    onComplete=onComplete or function() end
    local user=self.auth:currentUser()
    local offline=self.auth.isOffline~=nil and self.auth:isOffline()
    if not user or not user.nickname or offline or not self.localBoard.list then onComplete(); return end
    if self.syncedUid~=user.uid then self.syncedUid,self.syncedBest=user.uid,{} end
    local modes,index={1,2},1
    local function nextMode()
        local mode=modes[index]; index=index+1
        if not mode then onComplete(); return end
        local records=self.localBoard:list(user.uid,mode)
        local best=records[1] and tonumber(records[1].score) or 0
        if best>0 and self.syncedBest[mode]~=best then
            self.syncedBest[mode]=best
            self.globalBoard:add(best,function() nextMode() end,mode)
        else
            nextMode()
        end
    end
    nextMode()
end
function AppController:showCover() self.machine:enter("cover") end
function AppController:_renderCover()
    self.game.view:setVisible(false)
    self.view:showCover({start=function() self:showModeSelect() end,intro=function() self:showIntro() end,
        leaderboard=function() self:openLeaderboard() end,info=function() self:showAppInfo() end,
        settings=function() self:showSettings() end,
        exit=function() self.platform:exit() end,
        version=self.info.currentVersion,displayName=self.info.displayName},self.auth:currentUser())
end
function AppController:showModeSelect() self.machine:enter("modeSelect") end
function AppController:_renderModeSelect()
    self.view:showModeSelect(function(mode) self:startGame(mode) end,function() self:showCover() end)
end
function AppController:showSettings() self.machine:enter("settings") end
function AppController:_renderSettings()
    local model=self.settings:get(); model.musicTracks=self.musicTracks
    self.view:showSettings(model,function(value)
        self.settings:update(value); self:showCover()
    end,function() self:showCover() end,function(value,channel)
        self.settings:preview(value)
        -- 音效音量沒有持續播放的聲音可以參考，放一次消除音當作試聽。
        if channel=="effect" and self.sound and self.sound.playEliminate then self.sound:playEliminate() end
    end)
end
function AppController:startGame(mode)
    self.currentMode=tonumber(mode)==2 and 2 or 1
    if self.game.setMode then self.game:setMode(self.currentMode) end
    self.machine:enter("game")
end
function AppController:_enterGame()
    self.view:hide(); self.game.view:setVisible(true); self.game:start()
end
function AppController:showIntro() self.machine:enter("intro") end
function AppController:_renderIntro()
    self.view:showIntro(function() self:showCover() end)
end
function AppController:openExternal(url)
    local allowed=url==self.info.repositoryUrl or url==self.info.issuesUrl or url==self.info.authorUrl
        or url==self.info.latestReleaseUrl
    if not allowed or type(url)~="string" then return false end
    if not url:match("^https://github%.com/") then return false end
    return self.platform:openURL(url)~=false
end
function AppController:showAppInfo(page)
    self.infoPage=page or self.infoPage; self.machine:enter("appInfo")
end
function AppController:_renderAppInfo()
    local model=Pagination.page(self.info.versions,self.infoPage,1); self.infoPage=model.page
    self.view:showAppInfo(self.info,model,{
        repository=function() self:openExternal(self.info.repositoryUrl) end,
        issues=function() self:openExternal(self.info.issuesUrl) end,
        author=function() self:openExternal(self.info.authorUrl) end,
        previous=function() self:showAppInfo(self.infoPage-1) end,
        next=function() self:showAppInfo(self.infoPage+1) end,
        back=function() self:showCover() end})
end
function AppController:openLeaderboard()
    -- 紀錄要能上傳全球排行榜就必須有身分與暱稱，所以排行榜一律先登入。
    -- 離線時靠 restoreSession 的快捷登入沿用上次的身分，不會被擋在外面。
    if not self.auth:isSignedIn() then self.machine:enter("auth"); return end
    self:ensureNickname()
end
function AppController:_renderAuth()
    local actions={
        login=function(email,password) self:authenticate(false,email,password) end,
        register=function(email,password) self:authenticate(true,email,password) end,
        forgot=function(email) self:forgotPassword(email) end,
        back=function() self:showCover() end}
    -- 這台裝置登入過才顯示快捷登入入口。
    if #self:_rememberedAccounts()>0 then
        actions.shortcut=function() self.machine:enter("shortcut") end
    end
    self.view:showAuth(actions)
end
function AppController:_rememberedAccounts()
    if not self.auth.rememberedAccounts then return {} end
    return self.auth:rememberedAccounts() or {}
end
function AppController:_renderShortcut()
    self.view:showShortcutAccounts(self:_rememberedAccounts(),{
        select=function(entry)
            self.view:setStatus("登入中…")
            self.auth:signInWithAccount(entry.uid,function(ok,result)
                if ok then self:ensureNickname() else self.view:setStatus(result) end
            end)
        end,
        -- 移除只是拿掉快捷登入選項，帳號與雲端紀錄都不受影響。
        forget=function(entry)
            self.view:confirm("要從快捷登入移除「"..entry.name.."」嗎？\n只會移除這台裝置的快捷登入，不會刪除帳號或排行榜紀錄。",
                function()
                    self.auth:forgetAccount(entry.uid)
                    if #self:_rememberedAccounts()==0 then self.machine:enter("auth")
                    else self.machine:enter("shortcut") end
                end)
        end,
        back=function() self.machine:enter("auth") end})
end
function AppController:authenticate(register,email,password)
    self.view:setStatus("連線中…")
    local operation=register and self.auth.register or self.auth.signIn
    operation(self.auth,email,password,function(ok,result)
        if ok then self:ensureNickname() else self.view:setStatus(result) end
    end)
end
function AppController:forgotPassword(email)
    self.view:setStatus("寄送中…")
    self.auth:sendPasswordReset(email,function(ok,message) self.view:setStatus(message) end)
end
function AppController:ensureNickname()
    local user=self.auth:currentUser()
    if user.nickname then self:afterIdentityReady(); return end
    -- 本機身分讀不到雲端玩家資料，直接進本機排行榜。
    if self.auth.isOffline~=nil and self.auth:isOffline() then self:showLocalLeaderboard(1); return end
    self.loadingMessage="讀取玩家資料…"; self.machine:enter("loading")
    self.profile:get(function(ok,nickname)
        if ok and nickname then self:afterIdentityReady()
        elseif ok then self:showNicknameSetup()
        else self:showLocalLeaderboard(1) end
    end)
end
function AppController:afterIdentityReady()
    self:syncLocalScores()
    local user=self.auth:currentUser()
    if user and user.isLegacy then self:showLegacyMigration() else self:showLocalLeaderboard() end
end
function AppController:showNicknameSetup() self.machine:enter("nickname") end
function AppController:_renderNickname()
    self.view:showNickname(function(nickname)
        self.view:setStatus("儲存中…")
        self.profile:save(nickname,function(ok,message)
            if ok then self.globalBoard:updateNickname(function() self:afterIdentityReady() end)
            else self.view:setStatus(message) end
        end)
    end,function() if self.auth:isSignedIn() then self:showLocalLeaderboard() else self:showCover() end end)
end
function AppController:showPasswordChange() self.machine:enter("password") end
function AppController:_renderPasswordChange()
    self.view:showPasswordChange(function(password)
        self.view:setStatus("修改中…")
        self.auth:changePassword(password,function(ok,message)
            if ok then self.view:setStatus(message); self:showLocalLeaderboard()
            else self.view:setStatus(message) end
        end)
    end,function() self:showLocalLeaderboard() end)
end
function AppController:showAccountInfo() self.machine:enter("account") end
function AppController:_renderAccountInfo()
    local user=self.auth:currentUser()
    local offline=self.auth.isOffline~=nil and self.auth:isOffline()
    self.view:showAccountInfo(user and user.account or "",function() self:showLocalLeaderboard() end,
        offline and function() self.view:showNotice("離線中，恢復網路後才能刪除帳號") end
        or function()
            self.view:confirm("確定要刪除帳號嗎？\n全球排行榜紀錄與暱稱都會一併刪除，而且無法復原。\n這台裝置上的本機紀錄會保留。",
                function() self:deleteAccount() end)
        end)
end
-- 刪除順序不能反過來：雲端資料要用 idToken 才刪得掉，帳號一旦刪除就沒有憑證了。
function AppController:deleteAccount()
    self.view:setStatus("刪除中，請勿關閉遊戲…")
    local modes,index={1,2},1
    local function finish()
        self.profile:deleteCurrent(function(profileOk)
            if not profileOk then self.view:setStatus("玩家資料刪除失敗，請稍後再試"); return end
            self.auth:deleteAccount(function(ok,message)
                if not ok then self.view:setStatus(message); return end
                self.syncedUid,self.syncedBest=nil,nil
                self:showCover()
            end)
        end)
    end
    local function nextMode()
        local mode=modes[index]; index=index+1
        if not mode then finish(); return end
        self.globalBoard:deleteCurrent(function(ok)
            if not ok then self.view:setStatus("全球排行榜紀錄刪除失敗，請稍後再試"); return end
            nextMode()
        end,mode)
    end
    nextMode()
end
function AppController:showLegacyMigration() self.machine:enter("accountMigration") end
function AppController:_renderLegacyMigration()
    self.view:showLegacyMigration(function(account,password)
        self.view:setStatus("轉換中，請勿關閉遊戲…")
        self.migration:migrate(account,password,function(ok,message)
            if ok then self:showLocalLeaderboard() else self.view:setStatus(message) end
        end)
    end,function() self:showCover() end)
end
function AppController:_actions()
    -- 離線快捷登入只授權「讀本機排行榜」與「寫本機紀錄」。
    -- 其他登入後功能都需要有效憑證，直接擋在按鈕上，不送必定失敗的請求。
    local offline=self.auth.isOffline~=nil and self.auth:isOffline()
    local function needsNetwork(what)
        return function() self.view:showNotice("離線中，恢復網路後才能"..what) end
    end
    return {localTab=function() self:showLocalLeaderboard(1) end,
        globalTab=offline and needsNetwork("查看全球排行榜") or function() self:showGlobalLeaderboard(1) end,
        account=function() self:showAccountInfo() end,accountLabel="帳號 ID",
        nickname=offline and needsNetwork("修改暱稱") or function() self:showNicknameSetup() end,
        password=offline and needsNetwork("修改密碼") or function() self:showPasswordChange() end,
        mode1=function() self:switchLeaderboardMode(1) end,
        mode2=function() self:switchLeaderboardMode(2) end,
        -- 登出只丟掉雲端憑證，最近登入的帳號會留著，離線仍可用快捷登入進本機排行榜。
        logout=function() self.auth:signOut(); self.syncedUid,self.syncedBest=nil,nil; self:showCover() end,
        back=function() self.machine:dispatch("back") end}
end
function AppController:_describePlayer(model)
    local user=self.auth:currentUser()
    model.playerName=user and (user.nickname or user.account) or "訪客"
    model.signedIn=user~=nil
    model.offline=self.auth.isOffline~=nil and self.auth:isOffline()
    return model
end
function AppController:switchLeaderboardMode(mode)
    self.currentMode=tonumber(mode)==2 and 2 or 1
    if self.machine:isIn("globalLeaderboard") then self:showGlobalLeaderboard(1) else self:showLocalLeaderboard(1) end
end
function AppController:showLocalLeaderboard(page)
    self.localPage=page or self.localPage; self.machine:enter("localLeaderboard")
end
function AppController:_renderLocalLeaderboard()
    local actions=self:_actions()
    local mode=self.currentMode or 1
    local model=Pagination.page(self.localBoard:listAll(mode),self.localPage,10); self.localPage=model.page
    model.mode=mode; self:_describePlayer(model)
    actions.previous=function() self:showLocalLeaderboard(self.localPage-1) end
    actions.next=function() self:showLocalLeaderboard(self.localPage+1) end
    actions.delete=function(record) self.localBoard:remove(record.uid,record.id); self:showLocalLeaderboard(self.localPage) end
    self.view:showLeaderboard("本機排行榜 - 模式"..mode,model,actions,true)
end
function AppController:showGlobalLeaderboard(page)
    self.globalPage=page or self.globalPage; self.machine:enter("globalLeaderboard")
end
function AppController:_renderGlobalLeaderboard()
    self.view:showLoading("讀取全球排行榜…")
    local mode=self.currentMode or 1
    local function loadGlobal()
    self.globalBoard:list(function(ok,records,ownRank)
        if ok then
            local model=Pagination.page(records,self.globalPage,10); self.globalPage=model.page
            model.ownRank=ownRank; model.mode=mode; self:_describePlayer(model)
            local actions=self:_actions()
            actions.previous=function() self:showGlobalLeaderboard(self.globalPage-1) end
            actions.next=function() self:showGlobalLeaderboard(self.globalPage+1) end
            self.view:showLeaderboard("全球排行榜 - 模式"..mode,model,actions,false)
        else self.view:showError("全球排行榜讀取失敗",function() self:showCover() end) end
    end,mode)
    end
    self:syncLocalScores(function() loadGlobal() end)
end
function AppController:onGameOver(score)
    -- 0 分不進排行榜；本機與雲端採用同一條規則，避免雲端出現 0 分紀錄。
    if (tonumber(score) or 0)<=0 then return end
    local user=self.auth:currentUser()
    local mode=self.currentMode or 1
    -- 沒登入過的裝置也留得下紀錄，之後登入不會併入任何帳號。
    self.localBoard:add(user and user.uid or GUEST_UID,user and user.nickname or GUEST_NAME,
        score,self.clock(),mode)
    if self.syncedBest then self.syncedBest[mode]=nil end
    if not user or (self.auth.isOffline and self.auth:isOffline()) then return end
    self.globalBoard:add(score,function() end,mode)
end
function AppController:onSuspend()
    if self.sound and self.sound.stopBackground then self.sound:stopBackground() end
    self.machine:dispatch("suspend")
end
function AppController:onResume()
    if self.sound and self.sound.playBackground then self.sound:playBackground() end
    -- 離線期間回到前景時再試一次換發憑證，成功就恢復成完整登入。
    if self.auth.isOffline and self.auth:isOffline() then self:restoreLogin() end
    local ok=pcall(function() self.machine:dispatch("resume") end)
    if not ok then self:restartApplication() end
end
function AppController:restartApplication()
    pcall(function() self.game:pause(); self.view:hide(); self.game.view:setVisible(false) end)
    self:showCover()
end
return AppController
