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
    local view={screen=nil}; function view:showCover(actions) self.screen="cover";self.actions=actions end
    function view:showIntro(back) self.screen="intro";self.back=back end
    function view:showAuth(actions) self.screen="auth";self.actions=actions end
    function view:showNickname(save,back) self.screen="nickname";self.saveNickname=save;self.back=back end
    function view:showLeaderboard(title,records,actions) self.screen=title;self.records=records;self.actions=actions end
    function view:showLoading() self.screen="loading" end
    function view:showError() self.screen="error" end
    function view:setStatus(value) self.status=value end
    function view:hide() self.screen=nil end
    local gameView={}; function gameView:setVisible(value) self.visible=value end
    local game={view=gameView,starts=0}; function game:start() self.starts=self.starts+1 end
    local localBoard={records={}}
    function localBoard:list() return self.records end
    function localBoard:add(_,account,score) self.records[#self.records+1]={id="1",account=account,score=score} end
    function localBoard:remove() return true end
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

T.test("Leaderboard requires login and records every signed-in game",function()
    local app,view,_,localBoard,global=build(false); app:openLeaderboard(); T.equal(view.screen,"auth")
    view.actions.login("u@example.com","123456"); T.equal(view.screen,"個人排行榜")
    app:onGameOver(80); app:onGameOver(20)
    T.equal(#localBoard.records,2); T.equal(global.adds,2)
end)
