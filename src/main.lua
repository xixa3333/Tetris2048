local GameState=require("game_state")
local GameLogic=require("game_logic")
local GameController=require("game_controller")
local Renderer=require("ui_renderer")
local AppController=require("app_controller")
local AppView=require("app_view")
local HttpClient=require("http_client")
local AuthService=require("auth_service")
local LocalLeaderboard=require("local_leaderboard")
local GlobalLeaderboard=require("global_leaderboard")
local JsonStorage=require("json_storage")
local firebaseConfig=require("firebase_config")

math.randomseed(os.time())
local audioFiles={eliminate=audio.loadStream("music/eliminate.mp3"),background=audio.loadStream("music/BackGround.mp3"),gameOver=audio.loadStream("music/GameOver.mp3")}
local scheduler={}
function scheduler:after(delay,callback) return timer.performWithDelay(delay,callback,1) end
function scheduler:cancel(handle) if handle then pcall(timer.cancel,handle) end end
local sound={}
function sound:playBackground() audio.stop(1); audio.play(audioFiles.background,{channel=1,loops=-1}); audio.setVolume(0.15,{channel=1}) end
function sound:playEliminate() audio.play(audioFiles.eliminate,{channel=2}); audio.setVolume(0.4,{channel=2}) end
function sound:playGameOver() audio.stop(1); audio.play(audioFiles.gameOver,{channel=3}); audio.setVolume(0.4,{channel=3}) end
local input={listener=nil}
local keyCommands={w="up",s="down",a="left",d="right",r="rotate",space="reserve"}
function input:start(handler)
    self:stop(); self.listener=function(event)
        local phase=event.phase=="began" and "down" or event.phase
        if phase=="down" and keyCommands[event.keyName] then handler(keyCommands[event.keyName]); return true end
        return false
    end; Runtime:addEventListener("key",self.listener)
end
function input:stop() if self.listener then Runtime:removeEventListener("key",self.listener); self.listener=nil end end
local platform={}; function platform:exit() native.requestExit() end

local gameView=Renderer.new()
local app
local game=GameController.new({state=GameState.new(),logic=GameLogic,view=gameView,scheduler=scheduler,sound=sound,input=input,random=math.random,
    onGameOver=function(score) if app then app:onGameOver(score) end end,
    onHome=function() if app then app:showCover() end end})
gameView:setCommandHandler(function(command) game:handle(command) end)
local http=HttpClient.new(); local auth=AuthService.new(http,firebaseConfig)
app=AppController.new({view=AppView.new(),game=game,auth=auth,
    localBoard=LocalLeaderboard.new(JsonStorage.new("leaderboard.json")),
    globalBoard=GlobalLeaderboard.new(http,firebaseConfig,auth),platform=platform})
app:start()
