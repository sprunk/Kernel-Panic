
-- Does not return anything, create a global function WriteScript
-- WriteScript input arguments:
--   - a game, as a table describing the game start condition
--   - startscript filename as a string
-- The function translates the fields of the game table into startscript syntax
-- and write the startscript file to the disk

local scriptfile=nil
local tab_count=0

local function WriteString(str)
	scriptfile:write(str)
end

local function WriteEndLine()
	return WriteString("\r\n")
end

local function WriteTabbedLine(str)
	for tabs=1,tab_count do
		WriteString("\t")
	end
	WriteString(str)
	WriteEndLine()
end

local function WriteFieldName(str)
	for tabs=1,tab_count do
		WriteString("\t")
	end
	WriteString(str)
	WriteString("=")
end

local function WriteFieldValue(str)
	WriteString(str)
	WriteString(";")
	WriteEndLine()
end

local function WriteNumFieldValue(fieldvalue)
	WriteFieldValue(tostring(fieldvalue))
end

local function WriteField(fieldname,fieldvalue)
	WriteFieldName(fieldname)
	WriteFieldValue(fieldvalue)
end

local function WriteNumField(fieldname,fieldvalue)
	WriteFieldName(fieldname)
	WriteNumFieldValue(fieldvalue)
end

local function WriteFieldAndComment(fieldname,fieldvalue,comment)
	WriteFieldName(fieldname)
	WriteString(fieldvalue)
	WriteString(";// ")
	WriteString(comment)
	WriteEndLine()
end

local function WriteNumFieldAndComment(fieldname,fieldvalue,comment)
	WriteFieldAndComment(fieldname,fieldvalue,comment)
end

local function StartSubSection(str)
	for tabs=1,tab_count do
		WriteString("\t")
	end
	WriteString("[")
	WriteString(str)
	WriteString("]")
	WriteEndLine()
	WriteTabbedLine("{")
	tab_count=tab_count+1
end

local function EndSubSection()
	tab_count=tab_count-1
	WriteTabbedLine("}")
end


function WriteScript(GtW,ScriptFileName)

	scriptfile = io.open(ScriptFileName or ModSpecific.ScriptFileName,"wb")-- So the second argument of WriteScript(.,.) is optional

	tab_count=0

	WriteEndLine()
	WriteTabbedLine("// To run this script, drag and drop over "..ModSpecific.ExecutableFileName)
	WriteTabbedLine("//")
	WriteTabbedLine("// "..GtW.description)
	WriteTabbedLine("// Generated by zwzsg's Lua code from "..((Game or{}).modName
		or (wx and wxlua and wxlua.wxLUA_VERSION_STRING and ModSpecific.LauncherTitle) or "???"))
	if wx and wxlua and wxlua.wxLUA_VERSION_STRING then
		WriteTabbedLine("// Using "..(wxlua.wxLUA_VERSION_STRING or "wxLua")..", a "..(_VERSION or "Lua").." port of "..(wx.wxVERSION_STRING or "wxWidgets"))
	end
	if Game and (widget or gadget) then
		WriteTabbedLine("// "..Game.modShortName.." script written by \""..(widget or gadget):GetInfo().name.."\" "..((widget and "widget") or (gadget and "gadget") or "lua").." version "..((widget or gadget):GetInfo().version or "?"))
	end
	WriteEndLine()

	StartSubSection("GAME")

	WriteField("GameType",ModSpecific.ModFileName)
	WriteField("Mapname",GtW.map.InternalFileName)
	WriteEndLine()

	-- List of modoptions
	StartSubSection("MODOPTIONS")
	WriteTabbedLine("// KP specific:")
	for key,comment in pairs({
		nowalls="Because neither AI can't handle them",
		nospecials="Set to make it simpler",
		ons="Shielded gamemode, 0 for disabled, 2 for weak, 4 for ultra",
		sos="Amount per building, 0 for disabled",
		colorwars="Time in minutes before doom, 0 for disabled",
		preplaced="Give a pre-built base",
		}) do
		if GtW.ModOptions[key] then
			WriteNumFieldAndComment(key,GtW.ModOptions[key],comment)
		end
	end
	if type(GtW.ModOptions.homf)=="table" then
		WriteEndLine()
		WriteTabbedLine("// Heroes of Mainframe options:")
		for homf_key,homf_value in pairs(GtW.ModOptions.homf) do
			WriteNumField(homf_key,homf_value)
		end
	else
		WriteNumFieldAndComment("homf",GtW.ModOptions.homf or 0,"0 to play a general, 1 to play a hero")
	end
	if GtW.ModOptions.missionscript then
		WriteField("MissionScript",GtW.ModOptions.missionscript)
	end
	WriteEndLine()
	WriteTabbedLine("// Generic, but still applying to KP:")
	WriteNumField("GameMode",GtW.EndCondition)
	WriteTabbedLine("\t// 0 for \"Kill everything!\"")
	WriteTabbedLine("\t// 1 for \"Kill all factories!\"")
	WriteTabbedLine("\t// 2 for \"Kill the Kernel!\"")
	WriteTabbedLine("\t// 3 for \"Never ends!\"")
	WriteField("ghostedbuildings","1")
	WriteField("fixedallies","0")
	WriteField("MaxUnits","512")
	WriteField("MinSpeed","0.1")
	WriteField("MaxSpeed","10")
	WriteEndLine()
	WriteTabbedLine("// Irrelevant for KP:")
	WriteField("StartMetal","1024")
	WriteField("StartEnergy","1024")
	--WriteField("LimitDGun","0")
	--WriteField("DiminishingMMs","0")
	WriteField("LauncherName",(widget or gadget) and ((widget or gadget):GetInfo().name.." "..((widget and "widget") or (gadget and "gadget") or "lua")) or (wx and wxlua and ModSpecific.LauncherTitle) or "Something Lua")
	WriteField("LauncherVersion",(widget or gadget) and ((widget or gadget):GetInfo().version or "?") or (wx and wxlua and ModSpecific.LauncherVersion) or "?")
	WriteField("DateTime",os.date("%A %d %B %Y at %X"))
	
	EndSubSection()
	WriteEndLine()

	if GtW.MapOptions then
		StartSubSection("MAPOPTIONS")
		for key,value in pairs(GtW.MapOptions) do
			WriteField(key,value)
		end
		EndSubSection()
		WriteEndLine()
	end

	WriteField("OnlyLocal","1")
	WriteField("//HostIP","")-- Since 0.82.7 HostIP=localhost; makes Spring crash
	WriteField("HostPort","0")-- In 0.82.7 default port is 8452, which can only be used once!
	WriteField("IsHost","1")
	WriteEndLine()
	WriteFieldAndComment("StartPosType",(GtW.StartPosType or 0)>1 and "3" or "0","0 for fixed, 1 for random, 2 for chosen ingame, 3 for chosen out of game")
	WriteField("MyPlayerNum","0")
	WriteField("MyPlayerName",GtW.PlayerName)
	WriteNumField("NumPlayers",1)
	WriteNumField("NumUsers",#GtW.players)
	WriteNumField("NumTeams",#GtW.players)
	WriteField("NumAllyTeams","2")-- <- Uhoh, NOT!
	WriteEndLine()

	WriteTabbedLine("// List of human controlled players:")
	StartSubSection("PLAYER0")
	WriteField("name",GtW.PlayerName)
	WriteNumField("Team",(GtW.isSpeccing~=0 and 0 or GtW.PlayerTeamNum))
	WriteNumField("Spectator",GtW.isSpeccing)
	EndSubSection()
	WriteEndLine()

	WriteTabbedLine("// List of AI controlled players:")
	local friendcount,enemycout=0,0
	for p,_ in ipairs(GtW.players) do
		if p~=1+GtW.PlayerTeamNum or GtW.isSpeccing~=0 then
			StartSubSection("AI"..(p-1))
			local nick=GtW.players[p].aioverride or GtW.players[p].bot.ShortName
			if GtW.isSpeccing~=0 then
				friendcount=friendcount+1
				enemycout=enemycout+1
				WriteField("Name",nick.." #"..friendcount)
			elseif GtW.players[p].allyteam==GtW.players[1+GtW.PlayerTeamNum].allyteam then
				friendcount=friendcount+1
				WriteField("Name",nick.." (Friend #"..friendcount..")")
			else
				enemycout=enemycout+1
				WriteField("Name",nick.." (Enemy #"..enemycout..")")
			end
			if GtW.players[p].aioverride then
				WriteNumFieldAndComment("ShortName",GtW.players[p].bot.ShortName,"But will be overriden to \""..GtW.players[p].aioverride.."\"")
			else
				WriteNumField("ShortName",GtW.players[p].bot.ShortName)
			end
			WriteField("//Version","?")
			WriteNumField("Team",p-1)
			WriteNumFieldAndComment("Host",0,"Number of the PLAYER hosting the AI")
			EndSubSection()
		end
	end
	WriteEndLine()

	WriteTabbedLine("// List of \"teams\" (or \"players\" depending on terminology):")
	for p,teaminfo in ipairs(GtW.players) do
		StartSubSection("TEAM"..(p-1))
		WriteField("TeamLeader","0")
		WriteNumField("AllyTeam",teaminfo.allyteam)
		WriteNumField("Handicap",teaminfo.handicap or 0)
		if teaminfo.noons then
			WriteNumFieldAndComment("noons",1,"No ONS for this player")
		end
		if teaminfo.sos then
			WriteNumFieldAndComment("sos",teaminfo.sos,"Save our Soul specific to this player")
		end
		WriteField("Side",teaminfo.faction.InternalName)
		WriteFieldName("RGBColor")
		-- sprintf(colorthing,"%.4f %.4f %.4f",(float)teaminfo->color[0]/255,(float)teaminfo->color[1]/255,(float)teaminfo->color[2]/255)
		WriteFieldValue(teaminfo.color[1].." "..teaminfo.color[2].." "..teaminfo.color[3])
		if p~=1+GtW.PlayerTeamNum or GtW.isSpeccing~=0 then
			WriteField("AIDLL",teaminfo.bot.ShortName)
		end
		if teaminfo.aioverride then
			WriteField("aioverride",teaminfo.aioverride)
		end
		if teaminfo.StartPosX and teaminfo.StartPosZ then
			WriteNumField("StartPosX",teaminfo.StartPosX)
			WriteNumField("StartPosZ",teaminfo.StartPosZ)
		end
		if GtW.players[p].ExtraDoubleCustomKeys then
			for _,key in ipairs(GtW.players[p].ExtraDoubleCustomKeys) do
				WriteField(key.name,key.value)
			end
		end
		EndSubSection()
	end
	WriteEndLine()

	WriteTabbedLine("// List of ally teams: This is for assymetrical alliances")
	maxallyteam=GetMaxAllyTeam(GtW.players)
	for at=0,maxallyteam do
		local nbrallies=0
		StartSubSection("ALLYTEAM"..at)
		for p,_ in ipairs(GtW.players) do
			if GtW.players[p].allyteam==at then
				nbrallies=nbrallies+1
			end
		end
		WriteNumField("NumAllies",0*nbrallies)
		EndSubSection()
	end
	WriteEndLine()

	WriteTabbedLine("// List of restrictions")
	WriteNumField("NumRestrictions",0)
	StartSubSection("RESTRICT")
	EndSubSection()

	if GtW.HeightMapV1 then
		WriteEndLine()
		WriteTabbedLine("// Heightmap:")
		WriteField("HeightMapV1",GtW.HeightMapV1)
	end

	EndSubSection()

	scriptfile:flush()
	scriptfile:close()

end
