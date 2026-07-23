local T=require("test_helper")
local info=require("app_info")

T.test("APP information contains safe links and every released version summary",function()
    T.equal(info.repositoryUrl,"https://github.com/xixa3333/Tetris2048")
    T.equal(info.issuesUrl,"https://github.com/xixa3333/Tetris2048/issues")
    T.equal(info.authorUrl,"https://github.com/xixa3333")
    T.equal(info.currentVersion,"2.3.8")
    T.equal(info.latestReleaseUrl,"https://github.com/xixa3333/Tetris2048/releases/latest")
    T.equal(#info.versions,16)
    T.equal(info.versions[1].version,"2.3.8")
    T.equal(info.versions[#info.versions].version,"1.0.0")
    for _,release in ipairs(info.versions) do
        T.equal(#release.bullets>0,true,"version has no summary: "..release.version)
    end
end)
