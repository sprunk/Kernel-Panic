--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    main.lua
--  brief:   the entry point from LuaUI
--  author:  jK and others
--
--  Copyright (C) 2011-2013.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

LUA_NAME    = Script.GetName()
LUA_DIRNAME = Script.GetName() .. "/"
LUA_VERSION = Script.GetName() .. " v1.0"

_G[("%s_DIRNAME"):format(LUA_NAME:upper())] = LUA_DIRNAME -- creates LUAUI_DIRNAME
_G[("%s_VERSION"):format(LUA_NAME:upper())] = LUA_VERSION -- creates LUAUI_VERSION

VFS.DEF_MODE = VFS.RAW_FIRST

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
-- Initialize the Lua LogSection (else messages with level "info" wouldn't been shown)
--

if Spring.SetLogSectionFilterLevel then
    Spring.SetLogSectionFilterLevel(LUA_NAME, "info")
    local origSpringLog = Spring.Log
    Spring.Log = function(...)
        -- Suppress this warning message
        if (({...})[3] or "")~="Headers files aren\'t supported anymore use \"require\" instead!" then
            return origSpringLog(...)
        end
    end
else
    -- backward compability
    local origSpringLog = Spring.Log
    Spring.Log = function(name, level, ...)
        if (type(level) == "string")and(level == "info") then
            Spring.Echo(("[%s]"):format(name), ...)
        else
            origSpringLog(name, level, ...)
        end
    end
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
-- Load
--

VFS.Include("LuaHandler/Utilities/utils.lua", nil, VFS.DEF_MODE)

--// the addon handler
include "LuaHandler/handler.lua"

-- KP used to include `LuaUI/main.lua` here as `VFS.RAW`.
-- This would let players override the default loose file that
-- comes with engine installations, without recursing back here.
-- As of engine 2025.06.03 that file is broken and crashes.
-- `loose_default_main.lua` is a fixed copy of that file.
-- Might want to revert when engine gets fixed.
VFS.Include("LuaUI/loose_default_main.lua", nil, VFS.RAW_FIRST)

--// print Lua & LuaUI version
Spring.Log(LUA_NAME, "info", LUA_VERSION .. " (" .. _VERSION .. ")")

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
