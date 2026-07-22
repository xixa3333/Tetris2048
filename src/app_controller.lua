local AppController={}; AppController.__index=AppController
function AppController.new(d)
    assert(d.view and d.game and d.auth and d.profile and d.localBoard and d.globalBoard and d.platform)
    return setmetatable({view=d.view,game=d.game,auth=d.auth,profile=d.profile,
        localBoard=d.localBoard,globalBoard=d.globalBoard,platform=d.platform,
        clock=d.clock or os.time,screen="boot"},AppController)
end
function AppController:start() self:showCover() end
function AppController:restoreLogin()
    self.auth:restoreSession(function(ok)
        if not ok then return end
        self.profile:get(function() if self.screen=="cover" then self:showCover() end end)
    end)
end
function AppController:showCover()
    self.screen="cover"; self.game.view:setVisible(false)
    self.view:showCover({start=function() self:startGame() end,intro=function() self:showIntro() end,
        leaderboard=function() self:openLeaderboard() end,exit=function() self.platform:exit() end},self.auth:currentUser())
end
function AppController:startGame()
    self.screen="game"; self.view:hide(); self.game.view:setVisible(true); self.game:start()
end
function AppController:showIntro()
    self.screen="intro"; self.view:showIntro(function() self:showCover() end)
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
    if user.nickname then self:showLocalLeaderboard(); return end
    self.screen="loading"; self.view:showLoading("讀取玩家資料…")
    self.profile:get(function(ok,nickname)
        if ok and nickname then self:showLocalLeaderboard()
        elseif ok then self:showNicknameSetup()
        else self.view:showError("玩家資料讀取失敗",function() self:showCover() end) end
    end)
end
function AppController:showNicknameSetup()
    self.screen="nickname"
    self.view:showNickname(function(nickname)
        self.view:setStatus("儲存中…")
        self.profile:save(nickname,function(ok,message)
            if ok then self.globalBoard:updateNickname(function() self:showLocalLeaderboard() end)
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
function AppController:_actions()
    return {localTab=function() self:showLocalLeaderboard() end,globalTab=function() self:showGlobalLeaderboard() end,
        nickname=function() self:showNicknameSetup() end,password=function() self:showPasswordChange() end,
        logout=function() self.auth:signOut(); self:showCover() end,back=function() self:showCover() end}
end
function AppController:showLocalLeaderboard()
    self.screen="localLeaderboard"; local actions=self:_actions()
    actions.delete=function(record) self.localBoard:remove(record.uid,record.id); self:showLocalLeaderboard() end
    self.view:showLeaderboard("本機排行榜",self.localBoard:listAll(),actions,true)
end
function AppController:showGlobalLeaderboard()
    self.screen="globalLeaderboard"; self.view:showLoading("讀取全球排行榜…")
    self.globalBoard:list(function(ok,records)
        if ok then self.view:showLeaderboard("全球排行榜",records,self:_actions(),false)
        else self.view:showError("全球排行榜讀取失敗",function() self:showCover() end) end
    end)
end
function AppController:onGameOver(score)
    local user=self.auth:currentUser(); if not user then return end
    if (tonumber(score) or 0)>0 then self.localBoard:add(user.uid,user.nickname,score,self.clock()) end
    self.globalBoard:add(score,function() end)
end
function AppController:onSuspend()
    if self.screen=="game" then self.game:pause() end
end
function AppController:onResume()
    local ok=pcall(function()
        if self.screen=="game" then self.game:resume()
        elseif self.screen=="intro" then self:showIntro()
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
