-- Owns channels and applies persisted volumes; controllers only express intent.
local AudioService={}; AudioService.__index=AudioService
function AudioService.new(adapter,files,settings)
    local self=setmetatable({audio=adapter,files=files,settings=settings,backgroundPlaying=false},AudioService)
    settings:subscribe(function(value)
        if self.backgroundPlaying then self.audio.setVolume(value.backgroundVolume/100,{channel=1}) end
    end)
    return self
end
function AudioService:playBackground()
    self.audio.stop(1); self.backgroundPlaying=false
    local volume=self.settings:get().backgroundVolume
    if volume<=0 then return end
    self.audio.play(self.files.background,{channel=1,loops=-1})
    self.audio.setVolume(volume/100,{channel=1}); self.backgroundPlaying=true
end
function AudioService:stopBackground()
    self.audio.stop(1); self.backgroundPlaying=false
end
function AudioService:playEliminate()
    local volume=self.settings:get().effectVolume
    if volume<=0 then return end
    self.audio.play(self.files.eliminate,{channel=2}); self.audio.setVolume(volume/100,{channel=2})
end
function AudioService:playGameOver()
    self:stopBackground()
    local volume=self.settings:get().effectVolume
    if volume<=0 then return end
    self.audio.play(self.files.gameOver,{channel=3}); self.audio.setVolume(volume/100,{channel=3})
end
return AudioService
