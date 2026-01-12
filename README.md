# 1701 Random Mount

A World of Warcraft 1.12 addon that randomly selects and uses a mount from your collection. Built for Turtle WoW but compatible with vanilla WoW.

## Features

- Randomly select from all available mounts with a single command
- Filter mounts by keyword (e.g., `/mount tiger` for tiger mounts only)
- **Zone-aware filtering** - Automatically filters to usable mounts (Qiraji Battle Tanks only in AQ, excluded outside AQ)
- **Mount exclusions** - Permanently exclude mounts from random selection
- **Custom groups** - Create named groups for quick access to mount subsets
- Automatic detection of mounts from the ZMounts spellbook tab (Turtle WoW)
- Fallback pattern matching for vanilla WoW mount detection
- Saved variables persist exclusions and groups between sessions
- Debug command to troubleshoot mount detection

## Installation

1. Download or clone this repository
2. Copy the `1701_Random_Mount` folder to your `Interface/AddOns` directory
3. Restart WoW or type `/reload` if already in-game

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `/mount` | Use a random mount from your collection |
| `/mount <filter>` | Use a random mount matching the filter |
| `/mount <groupname>` | Use a random mount from a saved group |
| `/mount debug` | Show detected mounts and spellbook info |

### Exclusion Commands

| Command | Description |
|---------|-------------|
| `/mount exclude <filter>` | Exclude mounts matching the filter |
| `/mount unexclude <filter>` | Remove mounts from exclusion list |
| `/mount excludelist` | Show all excluded mounts |

**Note:** Using an exact mount name (e.g., `/mount Admiral Grumbleshell`) bypasses exclusions.

### Group Commands

| Command | Description |
|---------|-------------|
| `/mount group add <name> <filter>` | Add matching mounts to a group |
| `/mount group add <name> <mount1, mount2>` | Add specific mounts (CSV) to a group |
| `/mount group remove <name> <filter>` | Remove matching mounts from a group |
| `/mount group list <name>` | Show all mounts in a group |
| `/mount groups` | List all defined groups |

**Note:** Groups bypass exclusions - excluded mounts can still be used via groups.

### Examples

```
/mount                      -- Random mount from all available
/mount turtle               -- Random turtle mount
/mount tiger                -- Random tiger mount
/mount swift                -- Random swift (epic) mount
/mount Admiral Grumbleshell -- Specifically Admiral Grumbleshell (exact match)

-- Exclusions
/mount exclude turtle       -- Exclude all turtle mounts
/mount exclude Riding Turtle, Sea Turtle  -- Exclude specific mounts
/mount unexclude turtle     -- Re-include turtle mounts
/mount excludelist          -- Show what's excluded

-- Groups
/mount group add favorites tiger, raptor   -- Create "favorites" with tigers and raptors
/mount group add pvp Black War             -- Add all Black War mounts to "pvp"
/mount favorites            -- Random mount from favorites group
/mount group list favorites -- Show mounts in favorites
/mount groups               -- List all groups
/mount group remove pvp wolf -- Remove wolves from pvp group
```

## Macros

### Basic Mount Macro

```
/mount
```

### Shift-Modifier Macro

Use a specific mount when holding Shift, otherwise random:

```
/run SlashCmdList["RANDOMMOUNT1701"](IsShiftKeyDown() and "Grumbleshell" or "")
```

### Control-Modifier Macro

Same concept but with Ctrl:

```
/run SlashCmdList["RANDOMMOUNT1701"](IsControlKeyDown() and "Grumbleshell" or "")
```

### Multi-Modifier Macro

Different mounts for different modifiers:

```
/run local f=IsShiftKeyDown() and "Grumbleshell" or IsControlKeyDown() and "Tiger" or ""; SlashCmdList["RANDOMMOUNT1701"](f)
```

### Group-Based Macro

Use a group when holding Shift, otherwise random from all:

```
/run SlashCmdList["RANDOMMOUNT1701"](IsShiftKeyDown() and "favorites" or "")
```

## How It Works

### Turtle WoW

On Turtle WoW, mounts appear in a special "ZMounts" spellbook tab. The addon automatically detects this tab and treats all spells within it as mounts.

### Vanilla WoW

On vanilla WoW (or if ZMounts tab is not found), the addon falls back to pattern matching, detecting mounts by:

- Scanning bags for mount items (Reins, Horns, Whistles, etc.)
- Scanning spellbook for class mount spells (Paladin/Warlock summons)
- Matching against a comprehensive list of known mount names

## Troubleshooting

Run `/mount debug` to see:

1. **Spellbook Tabs** - Lists all tabs with their spell counts
2. **Detected Mounts** - All mounts the addon found
3. **Mount-like Spells** - Spells that look like mounts, marked as `[DETECTED]` or `[MISSED]`

If mounts are missing, check that they appear in the ZMounts tab or match one of the known patterns.

## API

The addon exports functions for use in macros or other addons:

```lua
-- Get all mounts (optionally filtered)
local mounts = RandomMount1701.GetAllMounts("tiger")

-- Use a random mount (optionally filtered)
RandomMount1701.DoRandomMount("swift")
```

## Version History

- **1.5.1** - Exclude AQ mounts outside of AQ (they only work inside)
- **1.5.0** - Zone-aware mount filtering (auto-filters to Qiraji Battle Tanks in AQ)
- **1.4.2** - Add lib version check to prevent crashes with older lib
- **1.4.1** - Fix /mount with no arguments returning no mounts
- **1.3.1** - Excluded mounts skipped when adding to groups, exact match bypasses exclusions
- **1.3.0** - Add mount exclusions and groups feature
- **1.2.0** - Use ZMounts spellbook tab for mount detection on Turtle WoW
- **1.1.0** - Add spellbook mount detection and `/mount debug` command
- **1.0.0** - Initial release

## License

MIT License - Feel free to modify and distribute.

## Author

Claude (with guidance from the 1701 Guild)
