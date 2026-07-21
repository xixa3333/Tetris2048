local AppController = {}
AppController.__index = AppController

function AppController.new(d)
    assert(d.view and d.game and d.auth and d.profile and d.localBoard and d.globalBoard and d.platform)
    return setmetatable({view=d.view, game=d.game, auth=d.auth, localBoard=d.localBoard,
        globalBoard=d.globalBoard, profile=d.profile, platform=d.platform, clock=d.clock or os.time}, AppController)
end

function AppController:start() self:showCover() end

function AppController:showCover()
    self.game.view:setVisible(false)
    self.view:showCover({
        start=function() self:startGame() end,
        intro=function() self:showIntro() end,
        leaderboard=function() self:openLeaderboard() end,
        exit=function() self.platform:exit() end
    }, self.auth:currentUser())
end

function AppController:startGame()
    self.view:hide()
    self.game.view:setVisible(true)
    self.game:start()
end

function AppController:showIntro()
    self.view:showIntro(function() self:showCover() end)
end

function AppController:openLeaderboard()
    if not self.auth:isSignedIn() then
        self.view:showAuth({
            login=function(email,password) self:authenticate(false,email,password) end,
            register=function(email,password) self:authenticate(true,email,password) end,
            back=function() self:showCover() end
        })
        return
    end
    self:ensureNickname()
end

function AppController:authenticate(register, email, password)
    self.view:setStatus("連線中…")
    local operation = register and self.auth.register or self.auth.signIn
    operation(self.auth, email, password, function(ok, result)
        if ok then self:ensureNickname() else self.view:setStatus(result) end
    end)
end

function AppController:ensureNickname()
    local user=self.auth:currentUser()
    if user.nickname then self:showLocalLeaderboard(); return end
    self.view:showLoading("讀取玩家資料…")
    self.profile:get(function(ok,nickname)
        if ok and nickname then self:showLocalLeaderboard()
        elseif ok then self:showNicknameSetup()
        else self.view:showError("玩家資料讀取失敗",function() self:showCover() end) end
    end)
end

function AppController:showNicknameSetup()
    self.view:showNickname(function(nickname)
        self.view:setStatus("儲存中…")
        self.profile:save(nickname,function(ok,message)
            if ok then
                self.globalBoard:updateNickname(function() self:showLocalLeaderboard() end)
            else self.view:setStatus(message) end
        end)
    end,function() self:showCover() end)
end

function AppController:_actions()
    return {
        localTab=function() self:showLocalLeaderboard() end,
        globalTab=function() self:showGlobalLeaderboard() end,
        nickname=function() self:showNicknameSetup() end,
        logout=function() self.auth:signOut(); self:showCover() end,
        back=function() self:showCover() end
    }
end

function AppController:showLocalLeaderboard()
    local user = self.auth:currentUser()
    local actions = self:_actions()
    actions.delete = function(id)
        self.localBoard:remove(user.uid, id)
        self:showLocalLeaderboard()
    end
    self.view:showLeaderboard("個人排行榜", self.localBoard:list(user.uid), actions, true)
end

function AppController:showGlobalLeaderboard()
    self.view:showLoading("讀取全球排行榜…")
    self.globalBoard:list(function(ok, records)
        if ok then self.view:showLeaderboard("全球排行榜", records, self:_actions(), false)
        else self.view:showError("全球排行榜讀取失敗", function() self:showCover() end) end
    end)
end

function AppController:onGameOver(score)
    local user = self.auth:currentUser()
    if not user then return end
    self.localBoard:add(user.uid, user.nickname, score, self.clock())
    self.globalBoard:add(score, function() end)
end

return AppController
