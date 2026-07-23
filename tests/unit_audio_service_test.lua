local T=require("test_helper")
local AudioService=require("audio_service")

local function build(background,effect)
    local audio={plays={},stops=0,volumes={}}
    function audio.stop() audio.stops=audio.stops+1 end
    function audio.play(file,options) audio.plays[#audio.plays+1]={file=file,channel=options.channel} end
    function audio.setVolume(value,options) audio.volumes[options.channel]=value end
    local settings={value={backgroundVolume=background,effectVolume=effect},listeners={}}
    function settings:get() return self.value end
    function settings:subscribe(listener) self.listeners[#self.listeners+1]=listener end
    return AudioService.new(audio,{background="bg",eliminate="clear",gameOver="over"},settings),audio,settings
end
T.test("Audio service applies percentage volumes to dedicated channels",function()
    local sound,audio=build(25,60); sound:playBackground(); sound:playEliminate()
    T.equal(audio.volumes[1],0.25); T.equal(audio.volumes[2],0.6)
end)
T.test("Muted channels do not play and home stops background",function()
    local sound,audio=build(0,0); sound:playBackground(); sound:playEliminate(); sound:playGameOver()
    T.equal(#audio.plays,0); sound:stopBackground(); T.truthy(audio.stops>=2)
end)
T.test("Live background setting changes update the playing channel",function()
    local sound,audio,settings=build(10,40); sound:playBackground()
    settings.value.backgroundVolume=75; settings.listeners[1](settings.value)
    T.equal(audio.volumes[1],0.75)
end)
