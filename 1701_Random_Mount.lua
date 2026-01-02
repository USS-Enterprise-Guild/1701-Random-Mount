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
                if itemName and IsMountItem(itemName) and MatchesFilter(itemName, filter) then
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

-- Scan spellbook for mount spells
local function GetSpellMounts(filter)
    local mounts = {}
    local i = 1

    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end

        if IsMountSpell(spellName) and MatchesFilter(spellName, filter) then
            table.insert(mounts, {
                type = "spell",
                name = spellName,
                spellIndex = i
            })
        end
        i = i + 1
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

    -- Show detected mounts
    local mounts = GetAllMounts(nil)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Detected Mounts (" .. table.getn(mounts) .. "):|r")
    for _, mount in ipairs(mounts) do
        DEFAULT_CHAT_FRAME:AddMessage("  [" .. mount.type .. "] " .. mount.name)
    end

    -- Show first 50 spells from spellbook for debugging
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Spellbook Sample (first 50):|r")
    local i = 1
    while i <= 50 do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        local detected = IsMountSpell(spellName) and " |cFF00FF00[MOUNT]|r" or ""
        DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ": " .. spellName .. detected)
        i = i + 1
    end

    if i > 50 then
        DEFAULT_CHAT_FRAME:AddMessage("  ... (more spells not shown)")
    end
end

-- Slash command handler
local function SlashCmdHandler(msg)
    -- Trim whitespace
    if msg then
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    end

    if msg == "debug" then
        DoDebug()
    else
        DoRandomMount(msg)
    end
end

-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    SLASH_RANDOMMOUNT17011 = "/mount"
    SlashCmdList["RANDOMMOUNT1701"] = SlashCmdHandler
end)

-- Export for external use
RandomMount1701.GetAllMounts = GetAllMounts
RandomMount1701.DoRandomMount = DoRandomMount
