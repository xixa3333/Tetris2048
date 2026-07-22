-- Pure presentation model shared by local and global leaderboards.
-- Data services return complete record collections; this module owns no storage or UI globals.
local Pagination={}

function Pagination.page(records,requestedPage,pageSize)
    records=records or {}; pageSize=math.max(1,math.floor(tonumber(pageSize) or 10))
    local totalCount=#records
    local totalPages=math.max(1,math.ceil(totalCount/pageSize))
    local page=math.floor(tonumber(requestedPage) or 1)
    page=math.max(1,math.min(page,totalPages))
    local firstIndex=(page-1)*pageSize+1
    local lastIndex=math.min(firstIndex+pageSize-1,totalCount)
    local items={}
    for index=firstIndex,lastIndex do items[#items+1]=records[index] end
    return {items=items,page=page,pageSize=pageSize,totalPages=totalPages,totalCount=totalCount,
        firstRank=firstIndex,hasPrevious=page>1,hasNext=page<totalPages}
end

return Pagination
