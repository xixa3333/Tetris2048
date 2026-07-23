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
local ProfileService=require("profile_service")
local InputAdapter=require("input_adapter")
local SessionStore=require("session_store")
local LifecycleAdapter=require("lifecycle_adapter")
local firebaseConfig=require("firebase_config")
local appInfo=require("app_info")
local AccountMigration=require("account_migration")
local SettingsService=require("settings_service")
local SeededRandom=require("seeded_random")
local AudioService=require("audio_service")
local UpdateService=require("update_service")

math.randomseed(os.time())
local audioFiles={eliminate=audio.loadStream("music/eliminate.mp3"),background=audio.loadStream("music/BackGround.mp3"),gameOver=audio.loadStream("music/GameOver.mp3")}
local scheduler={}
function scheduler:after(delay,callback) return timer.performWithDelay(delay,callback,1) end
function scheduler:cancel(handle) if handle then pcall(timer.cancel,handle) end end
local settings=SettingsService.new(JsonStorage.new("settings.json"))
local sound=AudioService.new(audio,audioFiles,settings)
local input=InputAdapter.new(Runtime,40)
local platform={}; function platform:exit() native.requestExit() end
function platform:openURL(url) return system.openURL(url) end

local gameView=Renderer.new()
local app
local game=GameController.new({state=GameState.new(),logic=GameLogic,view=gameView,scheduler=scheduler,sound=sound,input=input,
    randomFactory=SeededRandom.factory(settings,math.random),
    onGameOver=function(score) if app then app:onGameOver(score) end end,
    onHome=function() if app then app:showCover() end end})
gameView:setCommandHandler(function(command) game:handle(command) end)
local http=HttpClient.new()
local update=UpdateService.new(http,appInfo)
local auth=AuthService.new(http,firebaseConfig,SessionStore.new(JsonStorage.new("session.json")))
local profile=ProfileService.new(http,firebaseConfig,auth)
local globalBoard=GlobalLeaderboard.new(http,firebaseConfig,auth)
app=AppController.new({view=AppView.new(),game=game,auth=auth,profile=profile,
    localBoard=LocalLeaderboard.new(JsonStorage.new("leaderboard.json")),
    globalBoard=globalBoard,migration=AccountMigration.new(auth,profile,globalBoard),settings=settings,update=update,platform=platform,info=appInfo})
app:start()
app:restoreLogin()
local lifecycle=LifecycleAdapter.new(Runtime,app)
lifecycle:start()
