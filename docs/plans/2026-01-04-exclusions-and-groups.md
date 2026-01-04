# Exclusions and Groups Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add mount exclusions (never summon these) and named groups (pick from specific collection) to the Random Mount addon.

**Architecture:** Extract reusable logic to `1701_Lib.lua` with version gating for sharing with pet addon. Mount-specific code stays in `1701_Random_Mount.lua`. Data persists via SavedVariables.

**Tech Stack:** WoW 1.12 Lua API, SavedVariables for persistence

**Testing:** Manual in-game testing (no automated test framework for WoW addons)

---

## Task 1: Create Shared Library Foundation

**Files:**
- Create: `1701_Lib.lua`
- Modify: `1701_Random_Mount.toc`

**Step 1: Create library with version gating**

Create `1701_Lib.lua`:

```lua
--[[
    1701 Shared Library - Common utilities for 1701 addons

    Uses version gating so multiple addons can embed this file.
    Only the first (or newer) version initializes.
]]

local LIB_VERSION = 1
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
```

**Step 2: Update .toc to load library first**

Modify `1701_Random_Mount.toc` to add the library before the main file:

```
## Interface: 11200
## Title: 1701 Addons - Random Mount
## Notes: Random mount selector with optional keyword filtering
## Author: Claude
## Version: 1.3.0
## SavedVariables: RandomMount1701_Data

1701_Lib.lua
1701_Random_Mount.lua
```

**Step 3: Commit**

```bash
git add 1701_Lib.lua 1701_Random_Mount.toc
git commit -m "feat: add shared library foundation with version gating"
```

---

## Task 2: Add String Utility Functions to Library

**Files:**
- Modify: `1701_Lib.lua`

**Step 1: Add ParseCSV function**

Add to `1701_Lib.lua` before the final closing:

```lua
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
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(name), string.lower(filter)) ~= nil
end

-- Check if name exactly matches filter (case-insensitive)
function Lib1701.IsExactMatch(name, filter)
    if not filter or filter == "" then
        return false
    end
    return string.lower(name) == string.lower(filter)
end
```

**Step 2: Commit**

```bash
git add 1701_Lib.lua
git commit -m "feat: add string utilities (ParseCSV, MatchesFilter, IsExactMatch)"
```

---

## Task 3: Add Exclusion Management to Library

**Files:**
- Modify: `1701_Lib.lua`

**Step 1: Add exclusion functions**

Add to `1701_Lib.lua`:

```lua
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
```

**Step 2: Commit**

```bash
git add 1701_Lib.lua
git commit -m "feat: add exclusion management (IsExcluded, AddExclusions, RemoveExclusions)"
```

---

## Task 4: Add Group Management to Library

**Files:**
- Modify: `1701_Lib.lua`

**Step 1: Add group functions**

Add to `1701_Lib.lua`:

```lua
-- Get a group by name (case-insensitive)
function Lib1701.GetGroup(groups, groupName)
    if not groups or not groupName then
        return nil
    end
    local lowerName = string.lower(groupName)
    for name, members in pairs(groups) do
        if string.lower(name) == lowerName then
            return members, name  -- return members and actual stored name
        end
    end
    return nil, nil
end

-- Add items matching filter to a group (creates group if needed)
-- Respects exclusions when adding via filter
-- Returns: added (table), skipped (table), isNewGroup (bool)
function Lib1701.AddToGroup(groups, groupName, filter, getAllItemsFn, exclusions)
    local added = {}
    local skipped = {}

    -- Get or create group
    local members, storedName = Lib1701.GetGroup(groups, groupName)
    local isNewGroup = (members == nil)
    if isNewGroup then
        storedName = groupName
        groups[storedName] = {}
        members = groups[storedName]
    end

    local allItems = getAllItemsFn()
    for _, item in ipairs(allItems) do
        if Lib1701.MatchesFilter(item.name, filter) then
            -- Check if exact match (bypasses exclusions)
            local isExact = Lib1701.IsExactMatch(item.name, filter)

            -- Check if excluded (unless exact match)
            if not isExact and Lib1701.IsExcluded(exclusions, item.name) then
                table.insert(skipped, item.name)
            else
                -- Check if already in group
                local alreadyInGroup = false
                for _, member in ipairs(members) do
                    if string.lower(member) == string.lower(item.name) then
                        alreadyInGroup = true
                        break
                    end
                end

                if not alreadyInGroup then
                    table.insert(members, item.name)
                    table.insert(added, item.name)
                end
            end
        end
    end

    -- If nothing was added to a new group, remove the empty group
    if isNewGroup and table.getn(members) == 0 then
        groups[storedName] = nil
        isNewGroup = false
    end

    return added, skipped, isNewGroup
end

-- Remove items matching filter from a group
-- Returns: removed (table), groupDeleted (bool)
function Lib1701.RemoveFromGroup(groups, groupName, filter)
    local removed = {}

    local members, storedName = Lib1701.GetGroup(groups, groupName)
    if not members then
        return removed, false
    end

    local toRemove = {}
    for i, member in ipairs(members) do
        if Lib1701.MatchesFilter(member, filter) then
            table.insert(toRemove, i)
            table.insert(removed, member)
        end
    end

    -- Remove in reverse order
    for i = table.getn(toRemove), 1, -1 do
        table.remove(members, toRemove[i])
    end

    -- Delete group if empty
    local groupDeleted = false
    if table.getn(members) == 0 then
        groups[storedName] = nil
        groupDeleted = true
    end

    return removed, groupDeleted
end
```

**Step 2: Commit**

```bash
git add 1701_Lib.lua
git commit -m "feat: add group management (GetGroup, AddToGroup, RemoveFromGroup)"
```

---

## Task 5: Initialize SavedVariables in Main Addon

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Add SavedVariables initialization**

Find the event handler section (around line 419-424) and modify:

```lua
-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    -- Initialize SavedVariables
    if not RandomMount1701_Data then
        RandomMount1701_Data = {}
    end
    if not RandomMount1701_Data.exclusions then
        RandomMount1701_Data.exclusions = {}
    end
    if not RandomMount1701_Data.groups then
        RandomMount1701_Data.groups = {}
    end

    -- Register slash command
    SLASH_RANDOMMOUNT17011 = "/mount"
    SlashCmdList["RANDOMMOUNT1701"] = SlashCmdHandler
end)
```

**Step 2: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "feat: initialize SavedVariables structure on load"
```

---

## Task 6: Integrate Exclusions into Mount Selection

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Add helper to check exclusions with exact match bypass**

Add after the `MatchesFilter` function (around line 214):

```lua
-- Check if mount should be included (handles exclusions and exact match bypass)
local function ShouldIncludeMount(mountName, filter)
    -- Exact match bypasses exclusions
    if Lib1701.IsExactMatch(mountName, filter) then
        return true
    end

    -- Check exclusions
    if Lib1701.IsExcluded(RandomMount1701_Data.exclusions, mountName) then
        return false
    end

    -- Apply normal filter
    return MatchesFilter(mountName, filter)
end
```

**Step 2: Update GetBagMounts to use ShouldIncludeMount**

Modify the `GetBagMounts` function. Change line ~227:

```lua
if itemName and IsMountItem(itemName) and ShouldIncludeMount(itemName, filter) then
```

**Step 3: Update GetSpellMounts to use ShouldIncludeMount**

Modify the `GetSpellMounts` function. Change line ~265:

```lua
if spellName and ShouldIncludeMount(spellName, filter) then
```

And change line ~282:

```lua
if IsMountSpell(spellName) and ShouldIncludeMount(spellName, filter) then
```

**Step 4: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "feat: integrate exclusion checking into mount selection"
```

---

## Task 7: Add Group Selection to Mount Logic

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Add function to get mounts from a group**

Add after the `GetAllMounts` function (around line 313):

```lua
-- Get mounts from a specific group
local function GetGroupMounts(groupName)
    local members = Lib1701.GetGroup(RandomMount1701_Data.groups, groupName)
    if not members then
        return nil
    end

    local mounts = {}
    local allMounts = GetAllMounts(nil)  -- Get all mounts without filter

    for _, member in ipairs(members) do
        for _, mount in ipairs(allMounts) do
            if string.lower(mount.name) == string.lower(member) then
                table.insert(mounts, mount)
                break
            end
        end
    end

    return mounts
end
```

**Step 2: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "feat: add group mount selection function"
```

---

## Task 8: Add Exclusion Command Handlers

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Add exclusion command handlers**

Add before the `SlashCmdHandler` function:

```lua
-- Message helper
local function Msg(text)
    Lib1701.Message("1701_Random_Mount", text)
end

-- Handle /mount exclude <filter>
local function HandleExclude(args)
    if not args or args == "" then
        Msg("Usage: /mount exclude <name or filter>")
        return
    end

    local added, alreadyExcluded = Lib1701.AddExclusions(
        RandomMount1701_Data.exclusions,
        args,
        function() return GetAllMounts(nil) end
    )

    if table.getn(added) > 0 then
        Msg("Excluded: " .. table.concat(added, ", ") .. " (" .. table.getn(added) .. " mounts)")
    end
    if table.getn(alreadyExcluded) > 0 then
        Msg("Already excluded: " .. table.concat(alreadyExcluded, ", "))
    end
    if table.getn(added) == 0 and table.getn(alreadyExcluded) == 0 then
        Msg("No mounts found matching '" .. args .. "'")
    end
end

-- Handle /mount unexclude <filter>
local function HandleUnexclude(args)
    if not args or args == "" then
        Msg("Usage: /mount unexclude <name or filter>")
        return
    end

    local removed, notFound = Lib1701.RemoveExclusions(RandomMount1701_Data.exclusions, args)

    if table.getn(removed) > 0 then
        Msg("Unexcluded: " .. table.concat(removed, ", ") .. " (" .. table.getn(removed) .. " mounts)")
    end
    if table.getn(notFound) > 0 then
        Msg("'" .. args .. "' was not in exclusion list")
    end
end

-- Handle /mount excludelist
local function HandleExcludeList()
    local exclusions = RandomMount1701_Data.exclusions
    if table.getn(exclusions) == 0 then
        Msg("No mounts excluded")
    else
        Msg("Excluded mounts (" .. table.getn(exclusions) .. "): " .. table.concat(exclusions, ", "))
    end
end
```

**Step 2: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "feat: add exclusion command handlers"
```

---

## Task 9: Add Group Command Handlers

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Add group command handlers**

Add after the exclusion handlers:

```lua
-- Handle /mount group add <groupname> <filter or CSV>
local function HandleGroupAdd(args)
    if not args or args == "" then
        Msg("Usage: /mount group add <groupname> <filter or mounts>")
        return
    end

    -- Parse: first word is group name, rest is filter/CSV
    local _, _, groupName, filter = string.find(args, "^(%S+)%s+(.+)$")
    if not groupName or not filter then
        Msg("Usage: /mount group add <groupname> <filter or mounts>")
        return
    end

    -- Check for reserved names
    local reserved = {debug=1, exclude=1, unexclude=1, excludelist=1, group=1, groups=1}
    if reserved[string.lower(groupName)] then
        Msg("Cannot use reserved name '" .. groupName .. "' as group name")
        return
    end

    local allAdded = {}
    local allSkipped = {}
    local isNewGroup = false

    -- Parse CSV and process each filter
    local filters = Lib1701.ParseCSV(filter)
    for _, f in ipairs(filters) do
        local added, skipped, isNew = Lib1701.AddToGroup(
            RandomMount1701_Data.groups,
            groupName,
            f,
            function() return GetAllMounts(nil) end,
            RandomMount1701_Data.exclusions
        )
        for _, name in ipairs(added) do table.insert(allAdded, name) end
        for _, name in ipairs(skipped) do table.insert(allSkipped, name) end
        if isNew then isNewGroup = true end
    end

    if table.getn(allAdded) > 0 then
        local prefix = isNewGroup and "Created group '" or "Added to '"
        local msg = prefix .. groupName .. "': " .. table.concat(allAdded, ", ") .. " (" .. table.getn(allAdded) .. " mounts)"
        if table.getn(allSkipped) > 0 then
            msg = msg .. ", skipped " .. table.getn(allSkipped) .. " excluded"
        end
        Msg(msg)
    elseif table.getn(allSkipped) > 0 then
        Msg("All matching mounts were excluded (" .. table.getn(allSkipped) .. " skipped)")
    else
        Msg("No mounts found matching '" .. filter .. "'")
    end
end

-- Handle /mount group remove <groupname> <filter or CSV>
local function HandleGroupRemove(args)
    if not args or args == "" then
        Msg("Usage: /mount group remove <groupname> <filter or mounts>")
        return
    end

    local _, _, groupName, filter = string.find(args, "^(%S+)%s+(.+)$")
    if not groupName or not filter then
        Msg("Usage: /mount group remove <groupname> <filter or mounts>")
        return
    end

    -- Check if group exists
    if not Lib1701.GetGroup(RandomMount1701_Data.groups, groupName) then
        Msg("Group '" .. groupName .. "' does not exist")
        return
    end

    local allRemoved = {}
    local groupDeleted = false

    -- Parse CSV and process each filter
    local filters = Lib1701.ParseCSV(filter)
    for _, f in ipairs(filters) do
        local removed, deleted = Lib1701.RemoveFromGroup(RandomMount1701_Data.groups, groupName, f)
        for _, name in ipairs(removed) do table.insert(allRemoved, name) end
        if deleted then groupDeleted = true end
    end

    if table.getn(allRemoved) > 0 then
        local msg = "Removed from '" .. groupName .. "': " .. table.concat(allRemoved, ", ") .. " (" .. table.getn(allRemoved) .. " mounts)"
        if groupDeleted then
            msg = msg .. " - group deleted (empty)"
        end
        Msg(msg)
    else
        Msg("No mounts found matching '" .. filter .. "' in group '" .. groupName .. "'")
    end
end

-- Handle /mount group list <groupname>
local function HandleGroupList(groupName)
    if not groupName or groupName == "" then
        Msg("Usage: /mount group list <groupname>")
        return
    end

    local members = Lib1701.GetGroup(RandomMount1701_Data.groups, groupName)
    if not members then
        Msg("Group '" .. groupName .. "' does not exist")
    else
        Msg("Group '" .. groupName .. "' (" .. table.getn(members) .. "): " .. table.concat(members, ", "))
    end
end

-- Handle /mount groups
local function HandleGroupsList()
    local groups = RandomMount1701_Data.groups
    local names = {}
    for name, members in pairs(groups) do
        table.insert(names, name .. " (" .. table.getn(members) .. ")")
    end

    if table.getn(names) == 0 then
        Msg("No mount groups defined")
    else
        Msg("Mount groups: " .. table.concat(names, ", "))
    end
end

-- Handle /mount group <subcommand>
local function HandleGroup(args)
    if not args or args == "" then
        Msg("Usage: /mount group <add|remove|list> ...")
        return
    end

    local _, _, subCmd, rest = string.find(args, "^(%S+)%s*(.*)$")
    subCmd = string.lower(subCmd or "")

    if subCmd == "add" then
        HandleGroupAdd(rest)
    elseif subCmd == "remove" then
        HandleGroupRemove(rest)
    elseif subCmd == "list" then
        HandleGroupList(rest)
    else
        Msg("Usage: /mount group <add|remove|list> ...")
    end
end
```

**Step 2: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "feat: add group command handlers"
```

---

## Task 10: Update Slash Command Router

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Replace SlashCmdHandler with new router**

Replace the existing `SlashCmdHandler` function:

```lua
-- Reserved command names
local RESERVED_COMMANDS = {
    debug = true,
    exclude = true,
    unexclude = true,
    excludelist = true,
    group = true,
    groups = true,
}

-- Slash command handler
local function SlashCmdHandler(msg)
    -- Trim whitespace
    if msg then
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    end

    -- Parse first word and rest
    local _, _, cmd, rest = string.find(msg or "", "^(%S+)%s*(.*)$")
    local lowerCmd = string.lower(cmd or "")

    -- Handle empty command
    if not cmd or cmd == "" then
        DoRandomMount(nil)
        return
    end

    -- Handle reserved commands
    if lowerCmd == "debug" then
        DoDebug()
    elseif lowerCmd == "exclude" then
        HandleExclude(rest)
    elseif lowerCmd == "unexclude" then
        HandleUnexclude(rest)
    elseif lowerCmd == "excludelist" then
        HandleExcludeList()
    elseif lowerCmd == "group" then
        HandleGroup(rest)
    elseif lowerCmd == "groups" then
        HandleGroupsList()
    else
        -- Check if it's a group name
        local groupMounts = GetGroupMounts(cmd)
        if groupMounts then
            if table.getn(groupMounts) == 0 then
                Msg("No available mounts in group '" .. cmd .. "'")
            else
                local mount = groupMounts[math.random(1, table.getn(groupMounts))]
                UseMount(mount)
            end
        else
            -- Treat as filter
            DoRandomMount(msg)
        end
    end
end
```

**Step 2: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "feat: update slash command router with new commands"
```

---

## Task 11: Update Header Documentation

**Files:**
- Modify: `1701_Random_Mount.lua`

**Step 1: Update file header with new commands**

Replace the header comment block (lines 1-12):

```lua
--[[
    1701 Random Mount - Random Mount Selector for WoW 1.12 / Turtle WoW

    Usage: /mount [filter|group]

    Examples:
        /mount              - Random mount from all available
        /mount turtle       - Random mount matching "turtle"
        /mount epic         - Random epic mount (if "epic" isn't a group)
        /mount favorites    - Random mount from "favorites" group
        /mount debug        - Show detected mounts and spellbook contents

    Exclusions:
        /mount exclude <filter>   - Exclude mounts matching filter
        /mount unexclude <filter> - Remove from exclusion list
        /mount excludelist        - Show all excluded mounts

    Groups:
        /mount group add <name> <filter or CSV>    - Add mounts to group
        /mount group remove <name> <filter or CSV> - Remove from group
        /mount group list <name>                   - Show mounts in group
        /mount groups                              - List all groups
]]
```

**Step 2: Commit**

```bash
git add 1701_Random_Mount.lua
git commit -m "docs: update header with new commands"
```

---

## Task 12: Manual Testing Checklist

**No files to modify - manual in-game testing**

Test the following scenarios in-game:

**Exclusions:**
1. `/mount excludelist` - should show "No mounts excluded"
2. `/mount exclude horse` - should exclude all horses
3. `/mount excludelist` - should show excluded horses
4. `/mount` - should never summon an excluded horse
5. `/mount Brown Horse` (exact) - should still work if you have it
6. `/mount unexclude horse` - should remove horses from exclusions
7. `/mount excludelist` - should show "No mounts excluded"

**Groups:**
1. `/mount groups` - should show "No mount groups defined"
2. `/mount group add favorites Swift` - should add swift mounts
3. `/mount groups` - should show "favorites (N)"
4. `/mount group list favorites` - should show members
5. `/mount favorites` - should pick from group only
6. `/mount group add favorites Tiger, Raptor` - CSV test
7. `/mount group remove favorites raptor` - partial remove
8. `/mount group remove favorites` until empty - should delete group

**Edge Cases:**
1. `/mount exclude horse` then `/mount group add horses horse` - horses should be skipped
2. `/mount group add horses Brown Horse` (exact) - should add despite exclusion
3. `/mount group add debug tiger` - should reject reserved name
4. Logout and login - settings should persist

**Step 1: Commit test results (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address issues found during testing"
```

---

## Task 13: Final Cleanup and Version Bump

**Files:**
- Modify: `1701_Random_Mount.toc`

**Step 1: Verify version is 1.3.0**

Ensure `1701_Random_Mount.toc` has:
```
## Version: 1.3.0
```

**Step 2: Final commit if needed**

```bash
git add -A
git commit -m "chore: finalize v1.3.0 release"
```

---

## Summary

| Task | Description | Est. Lines |
|------|-------------|------------|
| 1 | Create library foundation | ~15 |
| 2 | Add string utilities | ~35 |
| 3 | Add exclusion management | ~55 |
| 4 | Add group management | ~85 |
| 5 | Initialize SavedVariables | ~15 |
| 6 | Integrate exclusions into selection | ~20 |
| 7 | Add group selection function | ~20 |
| 8 | Add exclusion command handlers | ~55 |
| 9 | Add group command handlers | ~115 |
| 10 | Update slash command router | ~45 |
| 11 | Update header docs | ~20 |
| 12 | Manual testing | - |
| 13 | Final cleanup | - |

**Total new code:** ~480 lines across 2 files
