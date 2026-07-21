local Helper = {passed = 0, failed = 0}

local function describe(value)
    if type(value) ~= "table" then return tostring(value) end
    local values = {}
    for index, item in ipairs(value) do values[index] = describe(item) end
    return "{" .. table.concat(values, ", ") .. "}"
end

function Helper.test(name, callback)
    local ok, message = pcall(callback)
    if ok then
        Helper.passed = Helper.passed + 1
        print("PASS  " .. name)
    else
        Helper.failed = Helper.failed + 1
        print("FAIL  " .. name .. "\n      " .. tostring(message))
    end
end

function Helper.equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values are not equal") .. ": expected " .. describe(expected) .. ", got " .. describe(actual), 2)
    end
end

function Helper.truthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

function Helper.gridEqual(actual, expected)
    Helper.equal(#actual, #expected, "row count differs")
    for row = 1, #expected do
        Helper.equal(#actual[row], #expected[row], "column count differs at row " .. row)
        for column = 1, #expected[row] do
            Helper.equal(actual[row][column], expected[row][column], "grid differs at " .. row .. "," .. column)
        end
    end
end

function Helper.finish()
    print(("\nResult: %d passed, %d failed"):format(Helper.passed, Helper.failed))
    if Helper.failed > 0 then os.exit(1) end
end

return Helper
