-- Owns channels and applies persisted volumes; controllers only express intent.
local AudioService={}; AudioService.__index=AudioService
function AudioService.new(adapter,files,settings)
    local self=setmetatable({audio=adapter,files=files,settings=settings,backgroundPlaying=false,currentBackground=nil},AudioService)
    settings:subscribe(function(value)
        if value.backgroundVolume<=0 then self:stopBackground()
        elseif self.backgroundPlaying and self:currentBackgroundFile(value)==self.currentBackground then self.audio.setVolume(value.backgroundVolume/100,{channel=1})
        else self:playBackground() end
    end)
    return self
end
function AudioService:currentBackgroundFile(setting)
    setting=setting or self.settings:get()
    return (self.files.backgroundTracks and self.files.backgroundTracks[setting.backgroundTrack]) or self.files.background
end
function AudioService:playBackground()
    local setting=self.settings:get()
    local volume=setting.backgroundVolume
    if volume<=0 then self:stopBackground(); return end
    local file=self:currentBackgroundFile(setting)
    if not file then return end
    if self.backgroundPlaying and self.currentBackground~=file then self:stopBackground() end
    if self.backgroundPlaying then
        self.audio.setVolume(volume/100,{channel=1})
        return
    end
    self.audio.play(file,{channel=1,loops=-1})
    self.audio.setVolume(volume/100,{channel=1}); self.backgroundPlaying=true; self.currentBackground=file
end
function AudioService:stopBackground()
    self.audio.stop(1); self.backgroundPlaying=false; self.currentBackground=nil
end
function AudioService:playEliminate()
    local volume=self.settings:get().effectVolume
    if volume<=0 then return end
    self.audio.play(self.files.eliminate,{channel=2}); self.audio.setVolume(volume/100,{channel=2})
end
function AudioService:playGameOver()
    local volume=self.settings:get().effectVolume
    if volume<=0 then return end
    self.audio.play(self.files.gameOver,{channel=3}); self.audio.setVolume(volume/100,{channel=3})
end
return AudioService
