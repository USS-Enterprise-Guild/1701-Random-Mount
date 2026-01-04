# Mount Exclusions and Groups Design

## Overview

Add two features to the Random Mount addon:
1. **Exclusions** - Configurable list of mounts to never summon
2. **Groups** - Named collections of mounts for targeted random selection

Both features persist via SavedVariables and are managed through slash commands.

## Command Structure

### Existing commands (unchanged)
- `/mount` - random mount from all available
- `/mount <filter>` - random mount matching filter
- `/mount debug` - show detected mounts

### New exclusion commands
- `/mount exclude <name or filter>` - add matching mounts to exclusion list
- `/mount unexclude <name or filter>` - remove from exclusion list
- `/mount excludelist` - show all excluded mounts

### New group commands
- `/mount group add <groupname> <filter or CSV>` - add mounts to group (creates if needed)
- `/mount group remove <groupname> <filter or CSV>` - remove mounts from group (deletes if empty)
- `/mount group list <groupname>` - show mounts in a group
- `/mount groups` - list all groups with mount counts

### Command priority when running `/mount <arg>`
1. Reserved commands: `debug`, `exclude`, `unexclude`, `excludelist`, `group`, `groups`
2. Group name match - pick from that group
3. Filter match - pick from mounts matching substring

## Filtering & Exclusion Logic

### Exclusions apply to
- Unfiltered `/mount`
- Partial filter matches like `/mount tiger`
- Filter operations when building groups (`/mount group add horses horse` respects exclusions)

### Exclusions do NOT apply to
- Exact name matches (case-insensitive) - `/mount Brown Horse` works even if excluded
- Group selections - `/mount favorites` ignores exclusions entirely (mounts already in group are fair game)

### Filter matching (unchanged behavior)
- Substring match, case-insensitive
- `/mount swift` matches "Swift Zulian Tiger", "Swift Brown Steed", etc.

### Group selection
- Must match group name exactly (case-insensitive)
- Picks randomly from mounts in that group
- If a grouped mount no longer exists (deleted/unlearned), skip it silently

### When adding to exclusions or groups
- Filter matching applies - `/mount exclude horse` excludes all horses
- CSV support - `/mount group add favorites Tiger, Raptor` adds all tigers and raptors
- Warning if no mounts match: "No mounts found matching 'potato'"

## SavedVariables Structure

### TOC file addition
```
## SavedVariables: RandomMount1701_Data
```

### Data structure
```lua
RandomMount1701_Data = {
    exclusions = {
        "Brown Horse",
        "Gray Kodo",
        -- stored as exact names, not patterns
    },
    groups = {
        favorites = {
            "Swift Zulian Tiger",
            "Deathcharger",
        },
        raptors = {
            "Swift Blue Raptor",
            "Swift Razzashi Raptor",
        },
    },
}
```

### Why store exact names (not patterns)
- Clear what's excluded/grouped
- Survives if mount detection logic changes
- Easy to display in list commands

### Initialization
- On `VARIABLES_LOADED`, create empty structure if nil
- Migrate gracefully if structure changes in future versions

## User Feedback & Messages

### When adding exclusions
- Success: `Excluded: Brown Horse, Gray Kodo (2 mounts)`
- No matches: `No mounts found matching 'potato'`
- Already excluded: `Already excluded: Brown Horse` (still show success for new ones)

### When removing exclusions
- Success: `Unexcluded: Brown Horse (1 mount)`
- Not found: `'Brown Horse' was not in exclusion list`

### When listing exclusions
- Has items: `Excluded mounts (3): Brown Horse, Gray Kodo, Timber Wolf`
- Empty: `No mounts excluded`

### When adding to groups
- Success: `Added to 'favorites': Swift Zulian Tiger, Deathcharger (2 mounts)`
- Created new: `Created group 'favorites': Swift Zulian Tiger (1 mount)`
- Skipped excluded: `Added to 'favorites': Swift Blue Raptor (1 mount, skipped 2 excluded)`
- No matches: `No mounts found matching 'potato'`

### When removing from groups
- Success: `Removed from 'favorites': Deathcharger (1 mount)`
- Group deleted: `Removed from 'favorites': Swift Zulian Tiger (1 mount) - group deleted (empty)`
- Not in group: `'Deathcharger' not found in group 'favorites'`

### When listing groups
- `/mount groups`: `Mount groups: favorites (3), raptors (2)`
- `/mount group list favorites`: `Group 'favorites' (3): Swift Zulian Tiger, Deathcharger, ...`
- Empty: `No mount groups defined`

## File Structure & Shared Library

### Rationale
The exclusion and group logic is generic and can be reused by the companion Random Pet addon. To avoid code duplication, we extract shared functionality into a library using WoW's standard embedded library pattern with version gating.

### File structure
```
1701-Random-Mount/
├── 1701_Random_Mount.toc
├── 1701_Lib.lua          # shared library (embedded)
└── 1701_Random_Mount.lua # mount-specific logic
```

### 1701_Lib.lua structure
```lua
-- Version gating - only initialize if newer than already loaded
local LIB_VERSION = 1
if Lib1701 and Lib1701.version >= LIB_VERSION then return end
Lib1701 = { version = LIB_VERSION }

-- String utilities
Lib1701.ParseCSV = function(input) ... end
Lib1701.MatchesFilter = function(name, filter) ... end
Lib1701.IsExactMatch = function(name, filter) ... end

-- Exclusion management
Lib1701.IsExcluded = function(exclusions, name) ... end
Lib1701.AddExclusions = function(exclusions, filter, getAllItemsFn) ... end
Lib1701.RemoveExclusions = function(exclusions, filter) ... end

-- Group management
Lib1701.AddToGroup = function(groups, groupName, filter, getAllItemsFn, exclusions) ... end
Lib1701.RemoveFromGroup = function(groups, groupName, filter) ... end
Lib1701.GetGroup = function(groups, groupName) ... end

-- Message formatting
Lib1701.Message = function(prefix, text) ... end
```

### Load order in .toc
```
1701_Lib.lua
1701_Random_Mount.lua
```

### SavedVariables isolation
Each addon has its own SavedVariables - no conflicts:
- Mount addon: `RandomMount1701_Data`
- Pet addon: `RandomPet1701_Data`

The shared library is stateless - it provides functions that operate on data passed in by each addon.

## Implementation Notes

### CSV parsing
- Split on comma
- Trim whitespace from each item
- Process each item as a separate filter

### Group names
- Store lowercase
- Compare lowercase (case-insensitive matching)

### Exclusion names
- Store as returned from mount detection (preserve display case)

### Reserved words
- Before group name lookup, check against command list: `debug`, `exclude`, `unexclude`, `excludelist`, `group`, `groups`
- Prevent users from creating groups with these names

### Estimated size
- `1701_Lib.lua`: ~150-200 lines
- Additional mount-specific code: ~100-150 lines
- Current file: ~430 lines
