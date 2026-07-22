local T=require("test_helper")
local AppController=require("app_controller")

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
    function view:showIntro(back) self.screen="intro";self.back=back end
    function view:showAuth(actions) self.screen="auth";self.actions=actions end
    function view:showNickname(save,back) self.screen="nickname";self.saveNickname=save;self.back=back end
    function view:showPasswordChange(save,back) self.screen="password";self.savePassword=save;self.back=back end
    function view:showLeaderboard(title,records,actions) self.screen=title;self.records=records;self.actions=actions end
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
    local global={adds=0}; function global:list(callback) callback(true,{}) end
    function global:add(_,callback) self.adds=self.adds+1;callback(true) end
    function global:updateNickname(callback) callback(true) end
    local profile={}
    function profile:get(callback) auth.user.nickname="測試玩家"; callback(true,"測試玩家") end
    function profile:save(nickname,callback) auth.user.nickname=nickname; callback(true,nickname) end
    local platform={exits=0}; function platform:exit() self.exits=self.exits+1 end
    return AppController.new({view=view,game=game,auth=auth,profile=profile,localBoard=localBoard,globalBoard=global,platform=platform,clock=function() return 1 end}),view,game,localBoard,global
end

T.test("Cover routes to game and intro without coupling game logic to screens",function()
    local app,view,game=build(false); app:start(); T.equal(view.screen,"cover")
    view.actions.intro(); T.equal(view.screen,"intro"); view.back(); T.equal(view.screen,"cover")
    view.actions.start(); T.equal(game.starts,1); T.equal(game.view.visible,true)
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
    T.equal(view.screen,"本機排行榜"); T.equal(#view.records,2)
    app:onGameOver(0)
    T.equal(#localBoard.records,2); T.equal(global.adds,1)
    view.actions.delete(view.records[2])
    T.equal(localBoard.removed.uid,"b"); T.equal(localBoard.removed.id,"b1")
end)
