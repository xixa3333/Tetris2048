local LocalLeaderboard = {}
LocalLeaderboard.__index = LocalLeaderboard

function LocalLeaderboard.new(storage)
    assert(storage, "storage is required")
    return setmetatable({storage = storage}, LocalLeaderboard)
end

function LocalLeaderboard:_all()
    return self.storage:load() or {}
end

local function recordMode(record)
    return tonumber(record.mode) or 1
end

function LocalLeaderboard:list(uid, mode)
    mode = tonumber(mode) or 1
    local records = self:_all()[uid] or {}
    local filtered = {}
    for _, record in ipairs(records) do
        if recordMode(record) == mode then filtered[#filtered + 1] = record end
    end
    table.sort(filtered, function(a, b)
        if a.score == b.score then return a.playedAt > b.playedAt end
        return a.score > b.score
    end)
    return filtered
end

function LocalLeaderboard:listAll(mode)
    mode = tonumber(mode) or 1
    local records = {}
    for uid, accountRecords in pairs(self:_all()) do
        for _, record in ipairs(accountRecords) do
            -- Older saved records did not contain uid; recover it from their storage bucket.
            record.uid = record.uid or uid
            if recordMode(record) == mode then records[#records + 1] = record end
        end
    end
    table.sort(records, function(a, b)
        if a.score == b.score then return a.playedAt > b.playedAt end
        return a.score > b.score
    end)
    return records
end

function LocalLeaderboard:add(uid, account, score, playedAt, mode)
    local normalizedScore = math.max(0, math.floor(tonumber(score) or 0))
    if normalizedScore == 0 then return nil end
    local all = self:_all()
    all[uid] = all[uid] or {}
    local record = {
        id = tostring(playedAt) .. "-" .. tostring(#all[uid] + 1),
        uid = uid, account = account, score = normalizedScore, playedAt = playedAt,
        mode = tonumber(mode) == 2 and 2 or 1
    }
    all[uid][#all[uid] + 1] = record
    self.storage:save(all)
    return record
end

function LocalLeaderboard:remove(uid, id)
    local all = self:_all()
    local records = all[uid] or {}
    for index, record in ipairs(records) do
        if record.id == id then
            table.remove(records, index)
            self.storage:save(all)
            return true
        end
    end
    return false
end

return LocalLeaderboard
