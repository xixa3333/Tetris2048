-- Discovers packaged background music without coupling UI or audio services to filesystems.
local MusicLibrary={}

local BACKGROUND_PATTERN="^BackGround_(%d%d)_(.+)%.mp3$"

local function displayName(raw)
    return (raw or ""):gsub("_"," "):gsub("%s+"," "):match("^%s*(.-)%s*$")
end

function MusicLibrary.parse(filename)
    local number,name=tostring(filename or ""):match(BACKGROUND_PATTERN)
    if not number then return nil end
    return {id=filename,file="music/"..filename,number=tonumber(number),name=displayName(name)}
end

function MusicLibrary.fromFilenames(filenames)
    local tracks={}
    for _,filename in ipairs(filenames or {}) do
        local track=MusicLibrary.parse(filename)
        if track then tracks[#tracks+1]=track end
    end
    table.sort(tracks,function(a,b)
        if a.number==b.number then return a.id<b.id end
        return a.number<b.number
    end)
    return tracks
end

function MusicLibrary.find(tracks,id)
    for _,track in ipairs(tracks or {}) do if track.id==id then return track end end
    return (tracks or {})[1]
end

function MusicLibrary.fromSolar2D(lfs,systemApi,directory)
    local path=systemApi and systemApi.pathForFile and systemApi.pathForFile(directory,systemApi.ResourceDirectory)
    if not path or not lfs or not lfs.dir then return {} end
    local filenames={}
    for filename in lfs.dir(path) do filenames[#filenames+1]=filename end
    return MusicLibrary.fromFilenames(filenames)
end

return MusicLibrary
