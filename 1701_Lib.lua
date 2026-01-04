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
