local json = require("json")

local HttpClient = {}
HttpClient.__index = HttpClient

function HttpClient.new(networkAdapter)
    return setmetatable({network = networkAdapter or network}, HttpClient)
end

function HttpClient:request(method, url, body, headers, callback)
    local params = {headers = headers or {}}
    params.headers["Content-Type"] = params.headers["Content-Type"] or "application/json"
    if body ~= nil then params.body = json.encode(body) end
    self.network.request(url, method, function(event)
        local decoded
        if event.response and event.response ~= "" then
            pcall(function() decoded = json.decode(event.response) end)
        end
        callback(not event.isError and event.status >= 200 and event.status < 300,
            decoded or {}, event.status)
    end, params)
end

return HttpClient
