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

-- Check if a name is in the exclusion list
function Lib1701.IsExcluded(exclusions, name)
    if not exclusions or not name then
        return false
    end
    local lowerName = string.lower(name)
    for _, excluded in ipairs(exclusions) do
        if string.lower(excluded) == lowerName then
            return true
        end
    end
    return false
end

-- Add items matching filter to exclusion list
-- Returns: added (table), alreadyExcluded (table)
function Lib1701.AddExclusions(exclusions, filter, getAllItemsFn)
    local added = {}
    local alreadyExcluded = {}

    local allItems = getAllItemsFn()
    for _, item in ipairs(allItems) do
        if Lib1701.MatchesFilter(item.name, filter) then
            if Lib1701.IsExcluded(exclusions, item.name) then
                table.insert(alreadyExcluded, item.name)
            else
                table.insert(exclusions, item.name)
                table.insert(added, item.name)
            end
        end
    end

    return added, alreadyExcluded
end

-- Remove items matching filter from exclusion list
-- Returns: removed (table), notFound (table)
function Lib1701.RemoveExclusions(exclusions, filter)
    local removed = {}
    local toRemove = {}

    -- Find matching exclusions
    for i, excluded in ipairs(exclusions) do
        if Lib1701.MatchesFilter(excluded, filter) then
            table.insert(toRemove, i)
            table.insert(removed, excluded)
        end
    end

    -- Remove in reverse order to preserve indices
    for i = table.getn(toRemove), 1, -1 do
        table.remove(exclusions, toRemove[i])
    end

    -- If nothing matched, report as not found
    local notFound = {}
    if table.getn(removed) == 0 then
        table.insert(notFound, filter)
    end

    return removed, notFound
end
