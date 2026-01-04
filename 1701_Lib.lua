--[[
    1701 Shared Library - Common utilities for 1701 addons

    Uses version gating so multiple addons can embed this file.
    Only the first (or newer) version initializes.
]]

local LIB_VERSION = 2
if Lib1701 and Lib1701.version >= LIB_VERSION then
    return
end

Lib1701 = {
    version = LIB_VERSION,
}

-- Message formatting with consistent addon prefix
function Lib1701.Message(prefix, text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF" .. prefix .. ":|r " .. text)
end

-- Parse comma-separated values, trim whitespace from each
function Lib1701.ParseCSV(input)
    local results = {}
    if not input or input == "" then
        return results
    end

    -- Split by comma
    local pattern = "([^,]+)"
    for item in string.gfind(input, pattern) do
        -- Trim whitespace
        local trimmed = string.gsub(item, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(results, trimmed)
        end
    end

    return results
end

-- Check if name matches filter (substring, case-insensitive)
function Lib1701.MatchesFilter(name, filter)
    if not name then
        return false
    end
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(name), string.lower(filter)) ~= nil
end

-- Check if name exactly matches filter (case-insensitive)
function Lib1701.IsExactMatch(name, filter)
    if not name then
        return false
    end
    if not filter or filter == "" then
        return false
    end
    return string.lower(name) == string.lower(filter)
end
