local T=require("test_helper")
local MusicLibrary=require("music_library")

T.test("Music library discovers numbered background tracks in order",function()
    local tracks=MusicLibrary.fromFilenames({
        "BackGround_10_Late.mp3","GameOver.mp3","BackGround_02_Spooky_Dungeon.mp3",
        "BackGround_01_Cozy Puzzle In-Game 1.mp3","BackGround_03_New_Chill.mp3"})
    T.equal(#tracks,4)
    T.equal(tracks[1].id,"BackGround_01_Cozy Puzzle In-Game 1.mp3")
    T.equal(tracks[2].name,"Spooky Dungeon")
    T.equal(tracks[3].file,"music/BackGround_03_New_Chill.mp3")
end)

T.test("Music library falls back to the first track when selection is missing",function()
    local tracks=MusicLibrary.fromFilenames({"BackGround_01_A.mp3","BackGround_02_B.mp3"})
    T.equal(MusicLibrary.find(tracks,"BackGround_02_B.mp3").name,"B")
    T.equal(MusicLibrary.find(tracks,"missing").name,"A")
end)
