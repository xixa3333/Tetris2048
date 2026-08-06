local T=require("test_helper")
local AudioService=require("audio_service")

local function build(background,effect,track)
    local audio={plays={},stops=0,volumes={}}
    function audio.stop() audio.stops=audio.stops+1 end
    function audio.play(file,options) audio.plays[#audio.plays+1]={file=file,channel=options.channel} end
    function audio.setVolume(value,options) audio.volumes[options.channel]=value end
    local settings={value={backgroundVolume=background,effectVolume=effect,backgroundTrack=track},listeners={}}
    function settings:get() return self.value end
    function settings:subscribe(listener) self.listeners[#self.listeners+1]=listener end
    return AudioService.new(audio,{background="bg",backgroundTracks={a="bg-a",b="bg-b"},eliminate="clear",gameOver="over"},settings),audio,settings
end
T.test("Audio service applies percentage volumes to dedicated channels",function()
    local sound,audio=build(25,60); sound:playBackground(); sound:playEliminate(); sound:playGameOver()
    T.equal(audio.volumes[1],0.25); T.equal(audio.volumes[2],0.6)
    T.equal(audio.volumes[3],0.6)
    T.equal(audio.stops,0)
end)
T.test("Muted channels do not play and explicit pause stops background",function()
    local sound,audio=build(0,0); sound:playBackground(); sound:playEliminate(); sound:playGameOver()
    T.equal(#audio.plays,0); sound:stopBackground(); T.truthy(audio.stops>=1)
end)
T.test("Live background setting changes update the playing channel",function()
    local sound,audio,settings=build(10,40); sound:playBackground()
    settings.value.backgroundVolume=75; settings.listeners[1](settings.value)
    T.equal(audio.volumes[1],0.75)
end)
T.test("Live background setting starts and stops playback at zero boundary",function()
    local sound,audio,settings=build(0,40); sound:playBackground(); T.equal(#audio.plays,0)
    settings.value.backgroundVolume=30; settings.listeners[1](settings.value)
    T.equal(#audio.plays,1)
    settings.value.backgroundVolume=0; settings.listeners[1](settings.value)
    T.equal(audio.stops,2)
end)
T.test("Repeated background play updates volume without restarting the track",function()
    local sound,audio=build(10,40); sound:playBackground(); sound:playBackground()
    T.equal(#audio.plays,1); T.equal(audio.volumes[1],0.1)
end)
T.test("Background track setting switches to the selected loaded stream",function()
    local sound,audio,settings=build(10,40,"a"); sound:playBackground()
    T.equal(audio.plays[1].file,"bg-a")
    settings.value.backgroundTrack="b"; settings.listeners[1](settings.value); sound:playBackground()
    T.equal(audio.plays[2].file,"bg-b")
end)
