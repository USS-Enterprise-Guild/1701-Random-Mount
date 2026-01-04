--[[
    1701 Random Mount - Random Mount Selector for WoW 1.12 / Turtle WoW

    Usage: /mount [filter]

    Examples:
        /mount          - Random mount from all available
        /mount turtle   - Random turtle mount
        /mount tiger    - Random tiger mount
        /mount epic     - Random epic mount
        /mount debug    - Show detected mounts and spellbook contents
]]

RandomMount1701 = {}

-- Known mount item names (partial matches supported)
-- This list covers vanilla WoW mounts
local MOUNT_PATTERNS = {
    -- Alliance Horses
    "Chestnut Mare",
    "Brown Horse",
    "Black Stallion",
    "Pinto",
    "Palomino",
    "White Stallion",
    "Swift Brown Steed",
    "Swift White Steed",
    "Swift Palomino",

    -- Dwarven Rams
    "Gray Ram",
    "Brown Ram",
    "White Ram",
    "Black Ram",
    "Frost Ram",
    "Swift Brown Ram",
    "Swift White Ram",
    "Swift Gray Ram",

    -- Gnome Mechanostriders
    "Blue Mechanostrider",
    "Green Mechanostrider",
    "Red Mechanostrider",
    "Unpainted Mechanostrider",
    "Swift Green Mechanostrider",
    "Swift White Mechanostrider",
    "Swift Yellow Mechanostrider",

    -- Night Elf Sabers
    "Spotted Frostsaber",
    "Striped Frostsaber",
    "Striped Nightsaber",
    "Frostsaber",
    "Nightsaber",
    "Swift Frostsaber",
    "Swift Mistsaber",
    "Swift Stormsaber",

    -- Horde Wolves
    "Timber Wolf",
    "Dire Wolf",
    "Brown Wolf",
    "Red Wolf",
    "Arctic Wolf",
    "Swift Timber Wolf",
    "Swift Brown Wolf",
    "Swift Gray Wolf",

    -- Orc Wolves
    "Horn of the Swift Brown Wolf",
    "Horn of the Swift Gray Wolf",
    "Horn of the Swift Timber Wolf",
    "Horn of the Brown Wolf",
    "Horn of the Dire Wolf",
    "Horn of the Timber Wolf",
    "Horn of the Red Wolf",
    "Horn of the Arctic Wolf",

    -- Tauren Kodos
    "Gray Kodo",
    "Brown Kodo",
    "Green Kodo",
    "Teal Kodo",
    "Great White Kodo",
    "Great Brown Kodo",
    "Great Gray Kodo",

    -- Troll Raptors
    "Emerald Raptor",
    "Turquoise Raptor",
    "Violet Raptor",
    "Swift Blue Raptor",
    "Swift Olive Raptor",
    "Swift Orange Raptor",

    -- Undead Horses
    "Black Skeletal Horse",
    "Blue Skeletal Horse",
    "Brown Skeletal Horse",
    "Red Skeletal Horse",
    "Green Skeletal Warhorse",
    "Deathcharger",
    "Rivendare's Deathcharger",

    -- PvP Mounts
    "Black War Steed",
    "Black War Ram",
    "Black War Tiger",
    "Black Battlestrider",
    "Black War Wolf",
    "Black War Kodo",
    "Black War Raptor",
    "Red Skeletal Warhorse",

    -- Special/Rare Mounts
    "Winterspring Frostsaber",
    "Reins of the Winterspring Frostsaber",

    -- AQ Mounts
    "Black Qiraji Battle Tank",
    "Blue Qiraji Battle Tank",
    "Green Qiraji Battle Tank",
    "Yellow Qiraji Battle Tank",
    "Red Qiraji Battle Tank",

    -- ZG Mounts
    "Swift Zulian Tiger",
    "Swift Razzashi Raptor",

    -- World Boss Mounts
    "Reins of the Black Qiraji Battle Tank",

    -- Turtle Mounts (private server / later expansions)
    "Riding Turtle",
    "Sea Turtle",
    "Admiral Grumbleshell",
    "Turtle Mount",

    -- Generic patterns to catch variations
    "Reins of",
    "Horn of",
    "Whistle of",
}

-- Class mount spells (always detected regardless of pattern)
local CLASS_MOUNT_SPELLS = {
    -- Paladin
    ["Summon Warhorse"] = true,
    ["Summon Charger"] = true,
    -- Warlock
    ["Summon Felsteed"] = true,
    ["Summon Dreadsteed"] = true,
}

-- Check if a spell name matches mount patterns
local function IsMountSpell(spellName)
    if not spellName then return false end

    -- Always include class mount spells
    if CLASS_MOUNT_SPELLS[spellName] then
        return true
    end

    local lowerName = string.lower(spellName)

    -- Check for common mount keywords
    if string.find(lowerName, "mount") or
       string.find(lowerName, "summon") or
       string.find(lowerName, "reins") or
       string.find(lowerName, "riding") then
        return true
    end

    -- Check against known mount patterns
    for _, pattern in ipairs(MOUNT_PATTERNS) do
        if string.find(lowerName, string.lower(pattern)) then
            return true
        end
    end

    return false
end

-- Check if an item name matches mount patterns
local function IsMountItem(itemName)
    if not itemName then return false end

    local lowerName = string.lower(itemName)

    -- Check for common mount keywords
    if string.find(lowerName, "mount") or
       string.find(lowerName, "reins") or
       string.find(lowerName, "horn of the") or
       string.find(lowerName, "whistle") then
        return true
    end

    -- Check against known mount patterns
    for _, pattern in ipairs(MOUNT_PATTERNS) do
        if string.find(lowerName, string.lower(pattern)) then
            return true
        end
    end

    return false
end

-- Check if item name matches the filter
local function MatchesFilter(itemName, filter)
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(itemName), string.lower(filter))
end

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

-- Scan bags for mount items
local function GetBagMounts(filter)
    local mounts = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                -- Extract item name from link
                local _, _, itemName = string.find(itemLink, "%[(.+)%]")
                if itemName and IsMountItem(itemName) and ShouldIncludeMount(itemName, filter) then
                    table.insert(mounts, {
                        type = "item",
                        name = itemName,
                        bag = bag,
                        slot = slot
                    })
                end
            end
        end
    end

    return mounts
end

-- Scan spellbook for mount spells (uses ZMounts tab on Turtle WoW)
local function GetSpellMounts(filter)
    local mounts = {}

    -- Find the ZMounts tab
    local numTabs = GetNumSpellTabs()
    local mountTabOffset = nil
    local mountTabCount = nil

    for tab = 1, numTabs do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        if name == "ZMounts" then
            mountTabOffset = offset
            mountTabCount = numSpells
            break
        end
    end

    -- If ZMounts tab found, get all spells from it
    if mountTabOffset and mountTabCount then
        for i = 1, mountTabCount do
            local spellIndex = mountTabOffset + i
            local spellName = GetSpellName(spellIndex, BOOKTYPE_SPELL)
            if spellName and ShouldIncludeMount(spellName, filter) then
                table.insert(mounts, {
                    type = "spell",
                    name = spellName,
                    spellIndex = spellIndex
                })
            end
        end
    else
        -- Fallback: scan all spells using pattern matching (for non-Turtle WoW)
        local i = 1
        while true do
            local spellName = GetSpellName(i, BOOKTYPE_SPELL)
            if not spellName then
                break
            end

            if IsMountSpell(spellName) and ShouldIncludeMount(spellName, filter) then
                table.insert(mounts, {
                    type = "spell",
                    name = spellName,
                    spellIndex = i
                })
            end
            i = i + 1
        end
    end

    return mounts
end

-- Get all available mounts
local function GetAllMounts(filter)
    local allMounts = {}

    -- Get bag mounts
    local bagMounts = GetBagMounts(filter)
    for _, mount in ipairs(bagMounts) do
        table.insert(allMounts, mount)
    end

    -- Get spell mounts
    local spellMounts = GetSpellMounts(filter)
    for _, mount in ipairs(spellMounts) do
        table.insert(allMounts, mount)
    end

    return allMounts
end

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

-- Use a mount
local function UseMount(mount)
    if mount.type == "item" then
        UseContainerItem(mount.bag, mount.slot)
    elseif mount.type == "spell" then
        CastSpell(mount.spellIndex, BOOKTYPE_SPELL)
    end
end

-- Main mount function
local function DoRandomMount(filter)
    -- Trim whitespace from filter
    if filter then
        filter = string.gsub(filter, "^%s*(.-)%s*$", "%1")
        if filter == "" then
            filter = nil
        end
    end

    local mounts = GetAllMounts(filter)

    if table.getn(mounts) == 0 then
        if filter then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_Random_Mount:|r No mounts found matching '" .. filter .. "'")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_Random_Mount:|r No mounts found in your bags or spellbook.")
        end
        return
    end

    -- Pick a random mount
    local mount = mounts[math.random(1, table.getn(mounts))]
    UseMount(mount)
end

-- Debug function to show detected mounts and spellbook contents
local function DoDebug()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_Random_Mount Debug:|r Scanning...")

    -- Show spell tab info
    local numTabs = GetNumSpellTabs()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FFSpellbook Tabs (" .. numTabs .. "):|r")
    for tab = 1, numTabs do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        DEFAULT_CHAT_FRAME:AddMessage("  Tab " .. tab .. ": " .. (name or "?") .. " (offset=" .. offset .. ", count=" .. numSpells .. ")")
    end

    -- Show detected mounts
    local mounts = GetAllMounts(nil)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Detected Mounts (" .. table.getn(mounts) .. "):|r")
    for _, mount in ipairs(mounts) do
        DEFAULT_CHAT_FRAME:AddMessage("  [" .. mount.type .. "] " .. mount.name)
    end

    -- Count total spells and show all with mount-like names
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Scanning all spells for mount-like names:|r")
    local i = 1
    local totalSpells = 0
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        totalSpells = i

        -- Show spells that look like they might be mounts
        local lowerName = string.lower(spellName)
        local looksLikeMount = IsMountSpell(spellName) or
            string.find(lowerName, "horse") or
            string.find(lowerName, "ram") or
            string.find(lowerName, "wolf") or
            string.find(lowerName, "raptor") or
            string.find(lowerName, "kodo") or
            string.find(lowerName, "tiger") or
            string.find(lowerName, "saber") or
            string.find(lowerName, "strider") or
            string.find(lowerName, "skeletal") or
            string.find(lowerName, "turtle") or
            string.find(lowerName, "qiraji")

        if looksLikeMount then
            local detected = IsMountSpell(spellName) and " |cFF00FF00[DETECTED]|r" or " |cFFFF0000[MISSED]|r"
            DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ": " .. spellName .. detected)
        end
        i = i + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("Total spells scanned: " .. totalSpells)
end

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

-- Export for external use
RandomMount1701.GetAllMounts = GetAllMounts
RandomMount1701.DoRandomMount = DoRandomMount
