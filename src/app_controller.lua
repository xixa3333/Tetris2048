local Pagination=require("pagination")
local AppController={}; AppController.__index=AppController
function AppController.new(d)
    assert(d.view and d.game and d.auth and d.profile and d.localBoard and d.globalBoard and d.migration and d.settings and d.update and d.platform and d.info)
    return setmetatable({view=d.view,game=d.game,auth=d.auth,profile=d.profile,
        localBoard=d.localBoard,globalBoard=d.globalBoard,migration=d.migration,settings=d.settings,update=d.update,platform=d.platform,info=d.info,
        clock=d.clock or os.time,screen="boot",localPage=1,globalPage=1,infoPage=1},AppController)
end
function AppController:start()
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
        self.profile:get(function() if self.screen=="cover" then self:showCover() end end)
    end)
end
function AppController:showCover()
    self.screen="cover"; self.game.view:setVisible(false)
    self.view:showCover({start=function() self:showModeSelect() end,intro=function() self:showIntro() end,
        leaderboard=function() self:openLeaderboard() end,info=function() self:showAppInfo() end,
        settings=function() self:showSettings() end,
        exit=function() self.platform:exit() end,
        version=self.info.currentVersion},self.auth:currentUser())
end
function AppController:showModeSelect()
    self.screen="modeSelect"
    self.view:showModeSelect(function(mode) self:startGame(mode) end,function() self:showCover() end)
end
function AppController:showSettings()
    self.screen="settings"
    self.view:showSettings(self.settings:get(),function(value)
        self.settings:update(value); self:showCover()
    end,function() self:showCover() end)
end
function AppController:startGame(mode)
    self.currentMode=tonumber(mode)==2 and 2 or 1
    if self.game.setMode then self.game:setMode(self.currentMode) end
    self.screen="game"; self.view:hide(); self.game.view:setVisible(true); self.game:start()
end
function AppController:showIntro()
    self.screen="intro"; self.view:showIntro(function() self:showCover() end)
end
function AppController:openExternal(url)
    local allowed=url==self.info.repositoryUrl or url==self.info.issuesUrl or url==self.info.authorUrl or url==self.info.latestReleaseUrl
    if not allowed or type(url)~="string" or not url:match("^https://github%.com/") then return false end
    return self.platform:openURL(url)~=false
end
function AppController:showAppInfo(page)
    self.screen="appInfo"
    local model=Pagination.page(self.info.versions,page or self.infoPage,1); self.infoPage=model.page
    self.view:showAppInfo(self.info,model,{
        repository=function() self:openExternal(self.info.repositoryUrl) end,
        issues=function() self:openExternal(self.info.issuesUrl) end,
        author=function() self:openExternal(self.info.authorUrl) end,
        previous=function() self:showAppInfo(self.infoPage-1) end,
        next=function() self:showAppInfo(self.infoPage+1) end,
        back=function() self:showCover() end})
end
function AppController:openLeaderboard()
    if not self.auth:isSignedIn() then
        self.screen="auth"; self.view:showAuth({
            login=function(email,password) self:authenticate(false,email,password) end,
            register=function(email,password) self:authenticate(true,email,password) end,
            forgot=function(email) self:forgotPassword(email) end,
            back=function() self:showCover() end})
        return
    end
    self:ensureNickname()
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
    self.screen="loading"; self.view:showLoading("讀取玩家資料…")
    self.profile:get(function(ok,nickname)
        if ok and nickname then self:afterIdentityReady()
        elseif ok then self:showNicknameSetup()
        else self.view:showError("玩家資料讀取失敗",function() self:showCover() end) end
    end)
end
function AppController:afterIdentityReady()
    local user=self.auth:currentUser()
    if user and user.isLegacy then self:showLegacyMigration() else self:showLocalLeaderboard() end
end
function AppController:showNicknameSetup()
    self.screen="nickname"
    self.view:showNickname(function(nickname)
        self.view:setStatus("儲存中…")
        self.profile:save(nickname,function(ok,message)
            if ok then self.globalBoard:updateNickname(function() self:afterIdentityReady() end)
            else self.view:setStatus(message) end
        end)
    end,function() if self.auth:isSignedIn() then self:showLocalLeaderboard() else self:showCover() end end)
end
function AppController:showPasswordChange()
    self.screen="password"
    self.view:showPasswordChange(function(password)
        self.view:setStatus("修改中…")
        self.auth:changePassword(password,function(ok,message)
            if ok then self.view:setStatus(message); self:showLocalLeaderboard()
            else self.view:setStatus(message) end
        end)
    end,function() self:showLocalLeaderboard() end)
end
function AppController:showAccountInfo()
    self.screen="account"
    local user=self.auth:currentUser()
    self.view:showAccountInfo(user and user.account or "",function() self:showLocalLeaderboard() end)
end
function AppController:showLegacyMigration()
    self.screen="accountMigration"
    self.view:showLegacyMigration(function(account,password)
        self.view:setStatus("轉換中，請勿關閉遊戲…")
        self.migration:migrate(account,password,function(ok,message)
            if ok then self:showLocalLeaderboard() else self.view:setStatus(message) end
        end)
    end,function() self:showCover() end)
end
function AppController:_actions()
    return {localTab=function() self:showLocalLeaderboard(1) end,globalTab=function() self:showGlobalLeaderboard(1) end,
        account=function() self:showAccountInfo() end,accountLabel="帳號 ID",nickname=function() self:showNicknameSetup() end,
        password=function() self:showPasswordChange() end,
        mode1=function() self:switchLeaderboardMode(1) end,
        mode2=function() self:switchLeaderboardMode(2) end,
        logout=function() self.auth:signOut(); self:showCover() end,back=function() self:showCover() end}
end
function AppController:switchLeaderboardMode(mode)
    self.currentMode=tonumber(mode)==2 and 2 or 1
    if self.screen=="globalLeaderboard" then self:showGlobalLeaderboard(1) else self:showLocalLeaderboard(1) end
end
function AppController:showLocalLeaderboard(page)
    self.screen="localLeaderboard"; local actions=self:_actions()
    local mode=self.currentMode or 1
    local model=Pagination.page(self.localBoard:listAll(mode),page or self.localPage,10); self.localPage=model.page
    model.mode=mode
    actions.previous=function() self:showLocalLeaderboard(self.localPage-1) end
    actions.next=function() self:showLocalLeaderboard(self.localPage+1) end
    actions.delete=function(record) self.localBoard:remove(record.uid,record.id); self:showLocalLeaderboard(self.localPage) end
    self.view:showLeaderboard("本機排行榜 - 模式"..mode,model,actions,true)
end
function AppController:showGlobalLeaderboard(page)
    self.screen="globalLeaderboard"; self.view:showLoading("讀取全球排行榜…")
    local mode=self.currentMode or 1
    local function loadGlobal()
    self.globalBoard:list(function(ok,records,ownRank)
        if ok then
            local model=Pagination.page(records,page or self.globalPage,10); self.globalPage=model.page
            model.ownRank=ownRank; model.mode=mode
            local actions=self:_actions()
            actions.previous=function() self:showGlobalLeaderboard(self.globalPage-1) end
            actions.next=function() self:showGlobalLeaderboard(self.globalPage+1) end
            self.view:showLeaderboard("全球排行榜 - 模式"..mode,model,actions,false)
        else self.view:showError("全球排行榜讀取失敗",function() self:showCover() end) end
    end,mode)
    end
    local user=self.auth:currentUser()
    local localRecords=user and self.localBoard.list and self.localBoard:list(user.uid,mode) or {}
    if localRecords[1] and localRecords[1].score and localRecords[1].score>0 then
        self.globalBoard:add(localRecords[1].score,function() loadGlobal() end,mode)
    else
        loadGlobal()
    end
end
function AppController:onGameOver(score)
    local user=self.auth:currentUser(); if not user then return end
    local mode=self.currentMode or 1
    if (tonumber(score) or 0)>0 then self.localBoard:add(user.uid,user.nickname,score,self.clock(),mode) end
    self.globalBoard:add(score,function() end,mode)
end
function AppController:onSuspend()
    if self.screen=="game" then self.game:pause() end
end
function AppController:onResume()
    local ok=pcall(function()
        if self.screen=="game" then self.game:resume()
        elseif self.screen=="intro" then self:showIntro()
        elseif self.screen=="appInfo" then self:showAppInfo()
        elseif self.screen=="settings" then self:showSettings()
        elseif self.screen=="localLeaderboard" then self:showLocalLeaderboard()
        elseif self.screen=="globalLeaderboard" then self:showGlobalLeaderboard()
        elseif self.screen=="auth" then self:openLeaderboard()
        else self:showCover() end
    end)
    if not ok then self:restartApplication() end
end
function AppController:restartApplication()
    pcall(function() self.game:pause(); self.view:hide(); self.game.view:setVisible(false) end)
    self:showCover()
end
return AppController
