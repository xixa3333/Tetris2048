local GlobalLeaderboard = {}
GlobalLeaderboard.__index = GlobalLeaderboard

local function field(value)
    if type(value) == "number" then return {integerValue = tostring(value)} end
    return {stringValue = tostring(value)}
end

local function decodeDocument(document)
    local fields = document.fields or {}
    return {
        id = (document.name or ""):match("([^/]+)$"),
        uid = fields.uid and fields.uid.stringValue,
        account = fields.account and fields.account.stringValue,
        score = tonumber(fields.score and fields.score.integerValue) or 0,
        playedAt = fields.createdAt and fields.createdAt.timestampValue
    }
end

function GlobalLeaderboard.new(http, config, auth)
    local base = "https://firestore.googleapis.com/v1/projects/" .. config.projectId ..
        "/databases/(default)/documents"
    return setmetatable({http = http, auth = auth, base = base}, GlobalLeaderboard)
end

function GlobalLeaderboard:_headers()
    local user = self.auth:currentUser()
    return user and {Authorization = "Bearer " .. user.idToken} or nil
end

function GlobalLeaderboard:add(score, callback)
    local user = self.auth:currentUser()
    if not user then callback(false, "請先登入"); return end
    self.http:request("POST", self.base .. "/scores", {fields = {
        uid = field(user.uid), account = field(user.account), score = field(math.floor(score)),
        createdAt = {timestampValue = os.date("!%Y-%m-%dT%H:%M:%SZ")}, version = field("2.0.0")
    }}, self:_headers(), callback)
end

function GlobalLeaderboard:list(callback)
    if not self.auth:isSignedIn() then callback(false, "請先登入"); return end
    local query = {structuredQuery = {
        from = {{collectionId = "scores"}},
        orderBy = {{field = {fieldPath = "score"}, direction = "DESCENDING"}}, limit = 100
    }}
    self.http:request("POST", self.base .. ":runQuery", query, self:_headers(), function(ok, data)
        if not ok then callback(false, data); return end
        local records = {}
        for _, row in ipairs(data) do
            if row.document then records[#records + 1] = decodeDocument(row.document) end
        end
        callback(true, records)
    end)
end

return GlobalLeaderboard
