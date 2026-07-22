local T=require("test_helper")
local Pagination=require("pagination")

local function records(count)
    local values={}
    for index=1,count do values[index]={id=tostring(index),score=1000-index} end
    return values
end

T.test("Pagination returns ten ranked records per page",function()
    local first=Pagination.page(records(25),1,10)
    T.equal(#first.items,10); T.equal(first.firstRank,1); T.equal(first.totalPages,3)
    T.equal(first.hasPrevious,false); T.equal(first.hasNext,true)
    local second=Pagination.page(records(25),2,10)
    T.equal(#second.items,10); T.equal(second.items[1].id,"11"); T.equal(second.firstRank,11)
end)

T.test("Boundary: final leaderboard page contains the remaining records",function()
    local last=Pagination.page(records(25),3,10)
    T.equal(#last.items,5); T.equal(last.items[1].id,"21"); T.equal(last.firstRank,21)
    T.equal(last.hasPrevious,true); T.equal(last.hasNext,false)
end)

T.test("White-box: pagination clamps invalid and out-of-range pages",function()
    T.equal(Pagination.page(records(11),-9,10).page,1)
    T.equal(Pagination.page(records(11),99,10).page,2)
    T.equal(Pagination.page(records(11),"bad",10).page,1)
end)

T.test("Boundary: empty leaderboard remains on page one",function()
    local empty=Pagination.page({},1,10)
    T.equal(empty.page,1); T.equal(empty.totalPages,1); T.equal(empty.totalCount,0); T.equal(#empty.items,0)
end)
