# Zone-Aware Mount Filtering Design

## Overview

Automatically filter mounts based on the player's current zone. Qiraji Battle Tanks only work inside AQ, and regular mounts only work outside AQ.

## Problem

Currently, `/mount` treats all mounts as universally available. In AQ raids, only Qiraji Battle Tanks work - all other mounts fail with a game error. Conversely, Qiraji Battle Tanks cannot be used outside AQ. Users must manually filter or use groups to avoid selecting unusable mounts.

## Solution

Add automatic zone detection that filters mounts when the player is in a restricted zone.

### Zone Detection

```lua
local RESTRICTED_ZONES = {
    ["Ahn'Qiraj"] = true,           -- AQ40 (Temple)
    ["Ruins of Ahn'Qiraj"] = true,  -- AQ20 (Ruins)
}

local function IsInRestrictedZone()
    local zone = GetRealZoneText()
    return RESTRICTED_ZONES[zone] ~= nil
end
```

Zone names come from the WoW 1.12 `GetRealZoneText()` API. The outdoor Silithus/Gates area is not restricted.

### AQ-Eligible Mount Detection

```lua
local AQ_MOUNT_PATTERNS = {
    "Qiraji Battle Tank",  -- Matches: Black, Blue, Green, Yellow, Red
}

local function IsAQMount(mountName)
    for _, pattern in ipairs(AQ_MOUNT_PATTERNS) do
        if string.find(mountName, pattern) then
            return true
        end
    end
    return false
end
```

Uses substring matching to catch all Qiraji Battle Tank colors.

### Integration with GetAllMounts()

Filter mounts at the source so all commands respect zone restrictions:

```lua
local function GetAllMounts(filter)
    local mounts = {}  -- existing mount collection logic

    -- ... existing spellbook scanning code ...

    -- Zone filtering
    if IsInRestrictedZone() then
        local aqMounts = {}
        for _, mount in ipairs(mounts) do
            if IsAQMount(mount.name) then
                table.insert(aqMounts, mount)
            end
        end
        if table.getn(aqMounts) > 0 then
            return aqMounts
        end
        -- Fall back to all mounts if no AQ mounts available
    end

    return mounts
end
```

## Behavior

| Scenario | Result |
|----------|--------|
| `/mount` in AQ | Random from Qiraji Battle Tanks only |
| `/mount black` in AQ | Black Qiraji Battle Tank (if owned) |
| `/mount` in AQ, no AQ mounts | Falls back to all mounts |
| `/mount` outside AQ | Random from non-AQ mounts (excludes Qiraji tanks) |
| `/mount` outside AQ, only AQ mounts | Falls back to all mounts |
| Groups in AQ | Filtered to AQ-eligible mounts in that group |
| Groups outside AQ | Filtered to exclude AQ mounts |

## Edge Cases

1. **No AQ mounts owned (in AQ)**: Falls back to all mounts. User gets game error but isn't blocked.
2. **Only AQ mounts owned (outside AQ)**: Falls back to all mounts. User gets game error but isn't blocked.
3. **Filters in AQ**: Filter applied to AQ-eligible mounts only.
4. **Groups**: Zone filtering applies to group members.
5. **Exact mount name**: Works as expected.

## What We're NOT Adding

- No new commands or settings (automatic behavior)
- No chat messages when filtering (silent, seamless)
- No persistence needed (zone checked each call)

## Files to Modify

- `1701_Random_Mount.lua` - Add zone detection and filtering (~20-30 lines)

## Extensibility

The `RESTRICTED_ZONES` table can easily be extended if Turtle WoW adds other zone-restricted mount areas in the future.
