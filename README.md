# 1701 Random Mount

A World of Warcraft 1.12 addon that randomly selects and uses a mount from your collection. Built for Turtle WoW but compatible with vanilla WoW.

## Features

- Randomly select from all available mounts with a single command
- Filter mounts by keyword (e.g., `/mount tiger` for tiger mounts only)
- Automatic detection of mounts from the ZMounts spellbook tab (Turtle WoW)
- Fallback pattern matching for vanilla WoW mount detection
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
| `/mount debug` | Show detected mounts and spellbook info |

### Examples

```
/mount              -- Random mount from all available
/mount turtle       -- Random turtle mount
/mount tiger        -- Random tiger mount
/mount swift        -- Random swift (epic) mount
/mount grumbleshell -- Specifically Admiral Grumbleshell
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

- **1.2.0** - Use ZMounts spellbook tab for mount detection on Turtle WoW
- **1.1.0** - Add spellbook mount detection and `/mount debug` command
- **1.0.0** - Initial release

## License

MIT License - Feel free to modify and distribute.

## Author

Claude (with guidance from the 1701 Guild)
