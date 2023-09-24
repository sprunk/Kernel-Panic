--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Coord in % (resize) geometry will not be done
-- remember open/close status

function widget:GetInfo()
return {
		name	= "AdvPlayersList",
		desc	= "List of players that allows unit sharing and taking.",
		author	= "Marmoth",
		date	= "Juli 14, 2008",
		license	= "GNU GPL, v2 or later",
		layer	= -4,
		enabled	= true,
		handler	= true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
--------------------------------------------------------------------------------

local SetPingCpuColors
local GetDark
local SetSidePics
local SetMaxPlayerNameWidth
local UpdatePlayersList
local GetAllyTeams
local GetTeams
local GetPlayers
local GetSpectators
local IsOnButton
local Take
local UpdateSpecTarget
local GetCpuLvl
local GetPingLvl
local GetSizeY
local GetTipIdle


--------------------------------------------------------------------------------
-- GEOMETRY VARIABLES
--------------------------------------------------------------------------------

local vsx,vsy								= gl.GetViewSizes()
local leftEdge								= vsx - 200
local basicPosX								= 54 -- (closed)
local button1PosX,button2PosX,button3PosX	= vsx - 17, vsx - 35, vsx - 53
local cpuPosX,pingPosX						= button3PosX - 14, button3PosX - 25
local sidePicPosX,namePosX					= button3PosX - 200, button3PosX - 180
local barPosX								= sidePicPosX + 54

local openClose		= 0
local topEdge
local bottomEdge	= 0
local sizeY			= 0


--------------------------------------------------------------------------------
-- IMAGES
--------------------------------------------------------------------------------

-- local openClosePic	= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/openclose.png"
local openClosePic		= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/button.png"
local unitsPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/units.png"
local energyPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/energy.png"
local metalPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/metal.png"
local notFirstPic		= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/notfirst.png"
local notFirstPicWO		= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/notfirstWO.png"
local pingPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/ping.png"
local cpuPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/cpu.png"
local specPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/spec.png"
local spec2Pic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/spec2.png"
local barPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/bar.png"
local amountPic			= ":n:"..LUAUI_DIRNAME.."Images/advplayerslist/amount.png"
local sidePics			= {} -- loaded in SetSidePics function
local sidePicsWO		= {} -- loaded in SetSidePics function


--------------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------------

local fontHandler = VFS.Include("LuaUI/modfonts.lua", nil, VFS.BASE)

local font					= "LuaUI/Fonts/FreeSansBold_14"
local fontWOutline		= "LuaUI/Fonts/FreeSansBoldWOutline_14" -- White outline for font


--------------------------------------------------------------------------------
-- Colors
--------------------------------------------------------------------------------


local cpuColors       = {}
local pingColors      = {}

--------------------------------------------------------------------------------
-- Time Variables
--------------------------------------------------------------------------------

local lastUpdate	= 0
local updatePeriod	= 1
local blink			= true


--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

local tipIdleTime	=1000	-- last time mouse moved (for tip)
local tipText				-- text of the tip
local oldMouseX,oldMouseY


--------------------------------------------------------------------------------
-- Players counts and info
--------------------------------------------------------------------------------

-- local player info
local myAllyTeamID
local myTeamID			
local myPlayerID		= Spring.GetLocalPlayerID()
local mySpecStatus		= false

--General players/spectator count and tables
local allyTeamsCount		= 0		-- used as iterator and to determine space needed for separation bars
local gamePlayersCount		= 0		-- the number of players in the game including ghost teams and AI-teams
local gamePlayersInfo		= {}	-- table containing players info tables
local spectatorsCount		= 0		-- the number of spectators
local spectatorsInfo		= {}	-- table containing spectators info tables
local totalPlayersCount		= 0		-- players + spectators

-- Additional players sorting
local playersGiveCount		= 0		-- number of players who can receive units/ressources from the local player (allyteam leaders/ghost teams/ai teams)
local playersGive			= {}	-- table containing the above players info
local playersToTakeCount	= 0		-- number of players (teams) with no player and no ally (usually players who left)
local playersToTake			= {}	-- table containing the above players info
local playersToSpecCount	= 0		-- number of players that the local specator can spec (leaders/ghost teams/ai teams)
local playersToSpec			= {}	-- table containing the above players info
local specTarget 					-- current spectated player


--------------------------------------------------------------------------------
-- Button check variable
--------------------------------------------------------------------------------

local pressedToOpen				= nil		-- click detection for opening the give buttons
local pressedToMove				= nil		-- click detection for moving the widget
local moveStart					= nil		-- position of the cursor before dragging the widget
local pressedPlayerGiveEnergy	= nil		-- contains the player info of the player whose "give energy" button has been clicked (also used as click detection)
local pressedPlayerGiveMetal	= nil		-- same for metal

local amount					= 0			-- amount in pixel for metal and energy gift
local amountStart				= nil		-- position of the cursor before dragging the widget
local amountEM					= 0			-- amount in metal/energy
local amountEMMax				= nil		-- max amount of metal/energy that can be given (= current stock)

local pressedPlayerGiveUnit		= nil		-- same for units (but needs doubleclick)
local firstClickTime			= 0			--\
local secondClickTime			= 0			-- deals with double click
local doubleClick				= false		--/

local pressedToSpec				= nil		-- contains the player info of the player whose "give energy" button has been clicked (also used as click detection)
local pressedToTake				= nil		-- click detection for taking ghost teams units



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------- LOCAL FUNCTIONS


function SetPingCpuColors() -- Sets the colors for ping and CPU icons
	pingCpuColors = {
			[1] = {r = 0, g = 1, b = 0},
			[2] = {r = 0.7, g = 1, b = 0},
			[3] = {r = 1, g = 1, b = 0},
			[4] = {r = 1, g = 0.6, b = 0},
			[5] = {r = 1, g = 0, b = 0}
		}
end

--------------------------------------------------------------------------------

function GetDark(red,green,blue) -- Determines if the player color
	if red + green + blue < 0.9 then
		return true -- is dark. (goal: white outline)
	end
	return false
end

--------------------------------------------------------------------------------

function SetSidePics() -- Loads the side pics and outlines for each side
	teamList = Spring.GetTeamList()
	for _, team in ipairs(teamList) do
		_,_,_,_,teamside = Spring.GetTeamInfo(team)
		if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside..".png") then -- tries to find the specific side pic (should be in mod files)
			sidePics[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside..".png"
			if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside.."WO.png") then -- same for outline
				sidePicsWO[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside.."WO.png"
			end
		else
--		if VFS.FileExists("sidepics/"..teamside.."_16.png") then	-- looks for sidepics in the mod sidepics directory (!!color problem)
--			sidePics[team] = ":n:sidepics/"..teamside.."_16.png"
--		else
--			Spring.Echo("No SidePic in the mod for side "..teamside..".")
			if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside.."_default.png") then -- tries to find the side pic in spring/luaui files (default for each side)
				sidePics[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside.."_default.png"
				if VFS.FileExists(LUAUI_DIRNAME.."Images/Advplayerslist/"..teamside.."WO_default.png") then -- same for outline
					sidePicsWO[team] = ":n:LuaUI/Images/Advplayerslist/"..teamside.."WO_default.png"
				end
			else
				if teamside~="" then
					Spring.Echo("SidePic missing for side "..teamside..", using default.") -- set default image if none were found
				end
				sidePics[team] = ":n:"..LUAUI_DIRNAME.."Images/Advplayerslist/default.png"
				sidePicsWO[team] = ":n:"..LUAUI_DIRNAME.."Images/Advplayerslist/defaultWO.png" -- outline
			end
		end-- I do not understand why it works with this end, and doesn't work without
	end
end

--------------------------------------------------------------------------------

function SetMaxPlayerNameWidth() -- determines the maximal player name width (in order to set the width of the widget)
	local t = Spring.GetPlayerList()
	local max = fontHandler.GetTextWidth("9999 unit(s) to TAKE")+28 -- minimal width = minimal standard text width
	local n = ""
	local nw = 0
	fontHandler.UseFont(font)
	for _,p in ipairs(t) do
		n = Spring.GetPlayerInfo(p)
		nw = fontHandler.GetTextWidth(n)+28
		if nw > max then
			max = nw
		end
	end -- sets the other positions (dependent)
	namePosX = button3PosX - max
	sidePicPosX = namePosX - 20
	barPosX = sidePicPosX + 54
end

--------------------------------------------------------------------------------

function UpdatePlayersList()
	-- Main updating function
	_,_,mySpecStatus,_,_,_,_,_,_	= Spring.GetPlayerInfo(myPlayerID) -- reset variables
	myAllyTeamID					= Spring.GetLocalAllyTeamID()
	myTeamID						= Spring.GetLocalTeamID()
	allyTeamsCount					= 0
	gamePlayersCount				= 0
	gamePlayersInfo					= {}
	spectatorsCount					= 0
	spectatorsInfo					= {}
	playersGiveCount				= 0
	playersGive						= {}
	playersToTakeCount				= 0
	playersToTake					= {}
	GetAllyTeams()		-- Calls game players update function
	GetSpectators()		-- Calls spectators update function
	totalPlayersCount				= gamePlayersCount + spectatorsCount
end

--------------------------------------------------------------------------------

function GetAllyTeams()

	-- First level: getting
	-- the allyteams in the right order,
	-- i.e. the local player's one first,
	-- calling for each of these the
	-- getTeams() function.
	-- (-1 to remove gaia team)

	local allyTeamID
	local allyTeamList = Spring.GetAllyTeamList()
	allyTeamsCount = table.maxn(allyTeamList)-1

	for allyTeamID = 0, allyTeamsCount-1 do -- look for local player allyteam
		if allyTeamID == myAllyTeamID  then
			GetTeams(allyTeamID)
			break
		end
	end

	for allyTeamID = 0, allyTeamsCount-1 do -- other allyteams
		if allyTeamID ~= myAllyTeamID then
		GetTeams(allyTeamID)
		end
	end

end


--------------------------------------------------------------------------------

function GetTeams(allyTeamID)

	-- Second level: getting the teams
	-- in the right order (local player
	-- first) for each allyteam, calling for each of these
	-- the getPlayers() function.

	local teamID
	local teamsList = Spring.GetTeamList(allyTeamID)

	for _,teamID in ipairs(teamsList) do -- look for local player team
		if teamID == myTeamID then
			GetPlayers(teamID)
			break
		end
	end

	for _,teamID in ipairs(teamsList) do -- other teams
		if teamID ~= myTeamID then
			GetPlayers(teamID,allyTeamID)
		end  
	end

end

--------------------------------------------------------------------------------


function GetPlayers(teamID,allyTeamID)

	-- Third level: getting the players
	-- in the right order (local player
	-- first) for each team. Puts all the information
	-- in the gamePlayersInfo table.
	-- Spectators are excluded.

	local playersList = Spring.GetPlayerList(teamID,true)
	local playersCount = table.maxn(playersList)
	local playerID
	local isSpectator = false
	local noFirst = true
	local tred,tgreen,tblue = Spring.GetTeamColor(teamID)
	local _,_,isDead, isAi, teamside,tallyteam = Spring.GetTeamInfo(teamID)
	local pname,pping,pcpu,pcountry,prank
	local unitsCount = Spring.GetTeamUnitCount(teamID)

	if playersCount == 0 then -- ghostteams

		--Look for teams before players have come
		--at game start. (Including AIs)

		if Spring.GetGameSeconds() == 0 then
			gamePlayersCount=gamePlayersCount+1
			gamePlayersInfo[gamePlayersCount]={
					red			= tred,
					green		= tgreen,
					blue		= tblue,
					dark		= GetDark(tred,tgreen,tblue),
					name		= "...waiting for player",
					allyteam	= tallyteam,
					team		= teamID,
					first		= true,
					side		= teamside
				}

		if noFirst == true then
			gamePlayersInfo[gamePlayersCount].first = true
			noFirst = false
		end

		return -- No other player in this team --> go to next team

	elseif isAi == false then -- Look for teams where player left but some units are left

		if isDead == false then

			gamePlayersCount=gamePlayersCount+1
			gamePlayersInfo[gamePlayersCount]={
					red			= tred,
					green		= tgreen,
					blue		= tblue,
					dark		= GetDark(tred,tgreen,tblue),
					name		= "- GHOST TEAM -",
					allyteam	= tallyteam,
					team		= teamID,
					first		= true,
					side		= teamside,
					totake		= false
				}

				if allyTeamID == myAllyTeamID and mySpecStatus == false then -- if allied to local player, add take and give buttons

					gamePlayersInfo[gamePlayersCount].name = unitsCount .. " unit(s) to TAKE"
					gamePlayersInfo[gamePlayersCount].totake = true

					playersToTakeCount=playersToTakeCount+1
					playersToTake[playersToTakeCount]=gamePlayersInfo[gamePlayersCount]

					playersGiveCount=playersGiveCount+1
					playersGive[playersGiveCount]=gamePlayersInfo[gamePlayersCount]

				end
			end

			return -- No other player in this team --> go to next team

			end
		end

		-- Getting local human player if any
		for _,playerID in ipairs(playersList) do

			_,_,isSpectator = Spring.GetPlayerInfo(playerID)
			if isSpectator == false then -- exclude spectator

				if playerID == myPlayerID then

					gamePlayersCount=gamePlayersCount+1

					pname,_,_,pteam, _, pping, pcpu, pcountry, prank = Spring.GetPlayerInfo(playerID)
					noFirst = false
					gamePlayersInfo[gamePlayersCount]={
							red			= tred,
							green		= tgreen,
							blue		= tblue,
							dark		= GetDark(tred,tgreen,tblue),
							name		= pname,
							team		= pteam,
							allyteam	= tallyteam,
							ping		= pping,
							pingl		= GetPingLvl(pping),
							cpu			= pcpu,
							cpul		= GetCpuLvl(pcpu),
							country		= pcountry,
							rank		= prank,
							first		= true,
							side		= teamside
						}

					break -- no need to finish the loops if the human player has been found

				end
			end
		end

		-- Getting other human players
		for _,playerID in ipairs(playersList) do

			_,_,isSpectator = Spring.GetPlayerInfo(playerID) -- exclude spectator
			if isSpectator == false then

			if playerID ~= myPlayerID then

				gamePlayersCount=gamePlayersCount+1

				pname,_,_,pteam, _, pping, pcpu, pcountry, prank = Spring.GetPlayerInfo(playerID)
				gamePlayersInfo[gamePlayersCount]={
						red			= tred,
						green		= tgreen,
						blue		= tblue,
						dark		= GetDark(tred,tgreen,tblue),
						name		= pname,
						team		= pteam,
						allyteam	= tallyteam,
						ping		= pping,
						pingl		= GetPingLvl(pping),
						cpu			= pcpu,
						cpul		= GetCpuLvl(pcpu),
						country		= pcountry,
						rank		= prank,
						first		= false,
						side		= teamside
					}

					if noFirst == true then -- set as first player (leader) if not yet any

					gamePlayersInfo[gamePlayersCount].first = true

					if allyTeamID == myAllyTeamID and mySpecStatus == false then
						playersGiveCount=playersGiveCount+1
						playersGive[playersGiveCount]=gamePlayersInfo[gamePlayersCount] -- as a leader, add give button
					end

					noFirst = false -- now there is one first player for this team

				end
			end
		end
	end

	-- Getting AI players
	if isAi == true then

		gamePlayersCount=gamePlayersCount+1
		gamePlayersInfo[gamePlayersCount]={
				red			= tred,
				green		= tgreen,
				blue		= tblue,
				dark		= GetDark(tred,tgreen,tblue),
				name		= "AI-Bot",
				allyteam	= tallyteam,
				team		= teamID,
				first		= false,
				side		= teamside
			}

		--local _,name,hostingPlayerID,_,shortName = Spring.GetAIInfo(teamID) -- That was for 0.80.5.2
		-- Restore 0.81.2.1 behavior of GetAIInfo
		local function GetOldAIInfo(team)
			local AIInfo={Spring.GetAIInfo(team)}
			if #AIInfo==6 then
				table.insert(AIInfo,1,team)
			end
			return unpack(AIInfo)
		end
		teamID,skirmishAIID,name,hostingPlayerID,shortName,version,options = GetOldAIInfo(teamID) -- As in 0.81.1.3

		if name~="UNKNOWN" and string.lower(string.sub(name,1,3))~="bot" and string.len(name)>1 then
			gamePlayersInfo[gamePlayersCount].name=name
		elseif shortName~="UNKNOWN" then
			gamePlayersInfo[gamePlayersCount].name=shortName
		elseif hostingPlayerID~=Spring.GetMyPlayerID() then
			local ownerName=Spring.GetPlayerInfo(hostingPlayerID)
			if ownerName then
				gamePlayersInfo[gamePlayersCount].name=ownerName.."'s bot"
			end
		end

		if noFirst == true then -- set as first player (leader) if not yet any
			gamePlayersInfo[gamePlayersCount].first = true
			if allyTeamID == myAllyTeamID and mySpecStatus == false then
				playersGiveCount=playersGiveCount+1
				playersGive[playersGiveCount]=gamePlayersInfo[gamePlayersCount]
			end
			noFirst = false
		end
	end
end

--------------------------------------------------------------------------------

function GetSpectators() -- Getting spectators

	local playersList = Spring.GetPlayerList()
	local player
	local active
	local spectator

	for _, player in ipairs(playersList) do

		pname, active, spectator,_,_,pping,pcpu,pcountry,prank = Spring.GetPlayerInfo(player)

		if active == true and spectator == true then

			spectatorsCount	= spectatorsCount + 1
			spectatorsInfo[spectatorsCount] = {
					name	= pname,
					ping	= pping,
					pingl	= GetPingLvl(pping),
					cpu		= pcpu,
					cpul	= GetCpuLvl(pcpu),
					country	= pcountry,
					rank	= prank
				}      

		end
	end
end

--------------------------------------------------------------------------------
-- Give and take units buttons
--------------------------------------------------------------------------------

function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	-- check if if the mouse is in a square
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

--------------------------------------------------------------------------------

function Take()
	-- sends the /take command to spring
	Spring.SendCommands{"take"}
	return
end

--------------------------------------------------------------------------------

function UpdateSpecTarget()

	-- checks if the current speced team is still alive
	-- if not, sets the next alive team as spec target

	teamList = Spring.GetTeamList()

	for _,team in ipairs(teamList) do
		_,_,isDead = Spring.GetTeamInfo(team)
		if isDead == false then
			if team == specTarget then
				return
			end
		end
	end

	for _,team in ipairs(teamList) do
		_,_,isDead = Spring.GetTeamInfo(team)
		if isDead == false then
			specTarget = team
			Spring.SendCommands{"specteam "..team}
			return
		end
	end

end

--------------------------------------------------------------------------------
-- Ping and cpu
--------------------------------------------------------------------------------

function GetCpuLvl(cpuUsage)
	-- set the 5 cpu usage levels (green to red)
	if cpuUsage < 0.15 then
		return 1
	elseif cpuUsage < 0.3 then
		return 2
	elseif cpuUsage < 0.45 then
		return 3
	elseif cpuUsage < 0.65 then
		return 4
	else
		return 5
	end
end

--------------------------------------------------------------------------------

function GetPingLvl(ping)
	-- set the 5 ping levels (green to red)
	if ping < 0.15 then
		return 1
	elseif ping < 0.3 then
		return 2
	elseif ping < 0.7 then
		return 3
	elseif ping < 1.5 then
		return 4
	else
		return 5
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
------------------------------------ CALL-INS

function widget:Initialize()
	SetPingCpuColors()
	SetSidePics()
	SetMaxPlayerNameWidth()
end

--------------------------------------------------------------------------------

function widget:Shutdown()
--	Spring.SendCommands{"info 1"} -- Restores standard players list when removed
end

--------------------------------------------------------------------------------

function widget:Update()
	if pressedPlayerGiveEnergy ~= nil then
		amountEMMax = Spring.GetTeamResources(myTeamID,"energy")
		amountEM = amountEMMax*amount/39
		amountEM = amountEM-(amountEM%1)
	end
	if pressedPlayerGiveMetal ~= nil then
		amountEMMax = Spring.GetTeamResources(myTeamID,"metal")
		amountEM = amountEMMax*amount/39
		amountEM = amountEM-(amountEM%1)
	end
	if Spring.GetConfigInt("ShowPlayerInfo") == 1 then -- remove standard players list
		Spring.SendCommands{"info 0"}
	end
	local now = Spring.GetGameSeconds()  
	if now == 0 then -- First update before game start
		UpdatePlayersList()
	end
	if now < (lastUpdate + updatePeriod) then -- Update after game start
		return
	end
	lastUpdate = now
	if blink == true then
		blink = false
	else
		blink = true
	end
	UpdatePlayersList()
	if mySpecStatus == true then
		UpdateSpecTarget()
	end
end


--------------------------------------------------------------------------------

-- those two functions send and load the widget y position
-- to the widget config data file

function widget:GetConfigData(data) -- send
	return {bottomEdge = bottomEdge}
end

function widget:SetConfigData(data) -- load
	bottomEdge = data.bottomEdge
end


--------------------------------------------------------------------------------

-- draws the widget (among other things)

function GetSizeY()
	local sizeY = 18 * totalPlayersCount + 2 * allyTeamsCount + 24 -- compute the size (Y) of the widget
	if spectatorsCount > 0 then
		sizeY = sizeY + 20
	end
	if gamePlayersInfo[1] ~= nil then
		if gamePlayersInfo[1].allyteam ~= myAllyTeamID then
			sizeY = sizeY - 20
		end
	end
	return sizeY
end

function GetTipIdle()
	local mouseX,mouseY = Spring.GetMouseState()
	if mouseX ~= oldMouseX or mouseY ~= oldMouseY then
		tipIdleTime = widgetHandler:GetHourTimer()
	end
	oldMouseX,oldMouseY = mouseX,mouseY
	if tipIdleTime + 0.5 > widgetHandler:GetHourTimer() then
		return false
	else
		return true
	end
end

function widget:DrawScreen()

	if Spring.IsGUIHidden() then
		return
	end

	local decal = 0 -- position of the next object to draw
	local vspace = 18 -- standard distance between lines
	local sizeY = GetSizeY()
	local firstDrawnPlayer = true
	local firstEnnemy = true
	local currentAllyTeam = nil
	local drawnPlayersCount = 0 -- number of players to draw
	local drawnPlayer -- current drawn player
	local i -- iterator
	local tip = GetTipIdle()
	local mouseX,mouseY = Spring.GetMouseState()

	playersToSpecCount = 0 -- reset players that can be spectated (computed in this function)
	playersToSpec = {}

	fontHandler.UseFont(font)

	bottomEdge = bottomEdge or 0

	if bottomEdge + (sizeY+19) > vsy then -- change the position of the widget if too high (after resolution change or new category (like spectator))
		bottomEdge = vsy - (sizeY+19)
	end

	topEdge = sizeY + bottomEdge -- determine the absolute top position of the widget


	if mySpecStatus == true then -- sets the horizontal position if local player is spectator (so that one (spec) button is visible)
		basicPosX = 36
	elseif openClose == 0 and basicPosX == 36 then -- back to normal if not spectator anymore
		basicPosX = 0
	end

	gl.Color(0,0,0,0.3) -- draws background rectangle
	gl.Rect(sidePicPosX+basicPosX-3,bottomEdge, vsx, topEdge + 19)
	gl.Color(1,1,1,1)  


	if openClose == 1 then -- opens/closes the widget if requested by openclose button
		basicPosX = basicPosX + 6
		if basicPosX == 54 then
			openClose = 0
		end
	elseif openClose == 2 then
		basicPosX = basicPosX - 6
		if basicPosX == 0 then
			openClose = 0
		end
	end



-- PLAYERS LIST DRAWING

	if tip == false then -- WITHOUT TOOLTIP (lot more lines but removes a lot of "if")

		gl.Texture(openClosePic) -- draws the open/close button
		if basicPosX == 0 then
			gl.TexRect(vsx-17,topEdge,vsx-1,topEdge+16) -- arrow to the left if open
		elseif basicPosX == 54 then
			gl.TexRect(vsx-1,topEdge,vsx-17,topEdge+16) -- arrow to the right if closed
		elseif basicPosX == 36 then
			gl.TexRect(vsx-1,topEdge,vsx-17,topEdge+16) -- arrow to the right if specmode
		end
		gl.Texture(false)

		for i,drawnPlayer in ipairs(gamePlayersInfo) do

			if firstDrawnPlayer == true then -- deals with the first player
				firstDrawnPlayer = false

				currentAllyTeam = drawnPlayer.allyteam -- used to detect allyteam changes

				if currentAllyTeam == myAllyTeamID then -- Draws ALLIES label ont top if any ally ingame
					fontHandler.Draw("ALLIES", barPosX, topEdge)
					gl.Rect(barPosX, topEdge-2, vsx, topEdge-3)
				else
					fontHandler.Draw("ENEMIES", barPosX, topEdge-decal) -- Draws ENEMIES label on top if no ally ingame
					gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)
					firstEnnemy = false
				end

			elseif currentAllyTeam ~= drawnPlayer.allyteam then
				currentAllyTeam = drawnPlayer.allyteam
				if firstEnnemy == false then
					decal = decal + 2 -- Draws a line to separate ennemy teams
					gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)
				else
					decal = decal + 20
					fontHandler.Draw("ENEMIES", barPosX, topEdge-decal) -- Draws ENEMIES label between allies and ennemies if any ally ingame
					gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)
					firstEnnemy = false
				end
			end

			decal = decal + vspace

			drawnPlayer.buttony = topEdge - decal - 2 -- stores the y coord of the button for further click detection

			-- DRAWS PLAYER'S INFO
			gl.Color(drawnPlayer.red,drawnPlayer.green,drawnPlayer.blue) -- sets player color
			if drawnPlayer.first == true then
				gl.Texture(sidePics[drawnPlayer.team]) -- sets side image (for leaders)
			else
				gl.Texture(notFirstPic) -- sets image for not leader of team players
			end

			gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX + 16+basicPosX, topEdge - decal + 14) -- draws side image
			gl.Texture(false)

			fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal) -- draws name

			if drawnPlayer.dark == true then -- draws outline if player color is dark
				gl.Color(1,1,1)

				fontHandler.UseFont(fontWOutline) -- name
				fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal)
				fontHandler.UseFont(font)

				if drawnPlayer.first ~= true then -- side pic
					gl.Texture(notFirstPicWO)
					gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX+16+basicPosX, topEdge - decal + 14)
					gl.Texture(false)
				end
				if sidePicsWO[drawnPlayer.team] ~= nil then
					gl.Texture(sidePicsWO[drawnPlayer.team])
					gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX+16+basicPosX, topEdge - decal + 14)
					gl.Texture(false)
				end
			end

			gl.Color(1,1,1,1)

			if drawnPlayer.first == true then -- FOR LEADERS

				if mySpecStatus == false then -- Non spec mode

					if drawnPlayer.allyteam == myAllyTeamID and drawnPlayer.team ~= myTeamID then
						if drawnPlayer.totake == true and blink == true then
							-- Draws a blinking rectangle
							gl.Color(1,0.9,0) -- if the player of the same team
							gl.Rect(namePosX-22+basicPosX, topEdge - decal-4, vsx-55+basicPosX, topEdge - decal + 14) -- left (.take option)

							gl.Color(drawnPlayer.red,drawnPlayer.green,drawnPlayer.blue) -- draw player's name and side image again, over the blink
							fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal)
							gl.Texture(notFirstPic)
							gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX + 16+basicPosX, topEdge - decal + 14)
							gl.Color(1,1,1)
						end
						gl.Texture(unitsPic) -- Draws the GIVE UNIT BUTTON if the
						gl.TexRect(button1PosX+basicPosX,topEdge - decal-2,button1PosX+16+basicPosX, topEdge - decal + 14)
						gl.Texture(energyPic) -- Energy
						gl.TexRect(button2PosX+basicPosX,topEdge - decal-2,button2PosX+16+basicPosX, topEdge - decal + 14)
						gl.Texture(metalPic) -- Metal
						gl.TexRect(button3PosX+basicPosX,topEdge - decal-2,button3PosX+16+basicPosX, topEdge - decal + 14)
						gl.Texture(false)
					end
				else -- SPEC MODE
					if specTarget == drawnPlayer.team then -- Adds SPECTATE BUTTON to leaders if the local player is a
						gl.Texture(specPic) -- spectator
					else
						gl.Texture(spec2Pic)
					end
					gl.TexRect(button3PosX+basicPosX,topEdge - decal-2,button3PosX+16+basicPosX, topEdge - decal + 14)
					gl.Texture(false)
					playersToSpecCount=playersToSpecCount + 1 -- update the count of players to spectate
					playersToSpec[playersToSpecCount]=drawnPlayer

				end
			end

			if drawnPlayer.cpul ~= nil then -- draws CPU usage and ping icons (except AI and ghost teams)
				gl.Color(pingCpuColors[drawnPlayer.cpul].r,pingCpuColors[drawnPlayer.cpul].g,pingCpuColors[drawnPlayer.cpul].b)
				gl.Texture(cpuPic)
				gl.TexRect(cpuPosX+basicPosX, topEdge - decal+13, cpuPosX+10+basicPosX,topEdge - decal-3)
				gl.Color(pingCpuColors[drawnPlayer.pingl].r,pingCpuColors[drawnPlayer.pingl].g,pingCpuColors[drawnPlayer.pingl].b)
				gl.Texture(pingPic)
				gl.TexRect(pingPosX+basicPosX, topEdge - decal +15, pingPosX+10+basicPosX, topEdge - decal-1)
			end
			gl.Texture(false)
			gl.Color(1,1,1,1)
		end

		if spectatorsCount > 0 then
			decal = decal + 20 -- draws spectators if any
			fontHandler.Draw("SPECTATORS", barPosX, topEdge-decal) -- with SPECTATORS label on top
			gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)

			for i,drawnPlayer in ipairs(spectatorsInfo) do
				decal = decal + vspace
				fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal)
				if drawnPlayer.cpul ~= nil then -- draws CPU usage and ping icons
					gl.Color(pingCpuColors[drawnPlayer.cpul].r,pingCpuColors[drawnPlayer.cpul].g,pingCpuColors[drawnPlayer.cpul].b)
					gl.Texture(cpuPic)
					gl.TexRect(cpuPosX+basicPosX, topEdge - decal+13, cpuPosX+10+basicPosX,topEdge - decal-3)
					gl.Color(pingCpuColors[drawnPlayer.pingl].r,pingCpuColors[drawnPlayer.pingl].g,pingCpuColors[drawnPlayer.pingl].b)
					gl.Texture(pingPic)
					gl.TexRect(pingPosX+basicPosX, topEdge - decal +15, pingPosX+10+basicPosX, topEdge - decal-1)
				end
				gl.Color(1,1,1,1)
				gl.Texture(false)
				end
			end

		else -- WITH TOOLTIP
			tipText = nil

			gl.Texture(openClosePic) -- draws the open/close button
			if basicPosX == 0 then
				gl.TexRect(vsx-17,topEdge,vsx-1,topEdge+16) -- arrow to the left if open
				tipText = "Right click: slide widget."
			elseif basicPosX == 54 then
				gl.TexRect(vsx-1,topEdge,vsx-17,topEdge+16) -- arrow to the right if closed
				tipText = "Right click: slide widget."
			elseif basicPosX == 36 then
				gl.TexRect(vsx-1,topEdge,vsx-17,topEdge+16) -- arrow to the right if specmode
				tipText = "Right click: slide widget."
			end
			gl.Texture(false)

			if IsOnButton(mouseX,mouseY,vsx-17,topEdge,vsx-1,topEdge+16) == false then
				tipText = nil
			end

			for i,drawnPlayer in ipairs(gamePlayersInfo) do

				if firstDrawnPlayer == true then -- deals with the first player
					firstDrawnPlayer = false

					currentAllyTeam = drawnPlayer.allyteam -- used to detect allyteam changes

					if currentAllyTeam == myAllyTeamID then -- Draws ALLIES label ont top if any ally ingame
						fontHandler.Draw("ALLIES", barPosX, topEdge)
						gl.Rect(barPosX, topEdge-2, vsx, topEdge-3)
					else
						fontHandler.Draw("ENEMIES", barPosX, topEdge-decal) -- Draws ENEMIES label on top if no ally ingame
						gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)
						firstEnnemy = false
					end

				elseif currentAllyTeam ~= drawnPlayer.allyteam then
					currentAllyTeam = drawnPlayer.allyteam
					if firstEnnemy == false then
						decal = decal + 2 -- Draws a line to separate ennemy teams
						gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)
					else
						decal = decal + 20
						fontHandler.Draw("ENEMIES", barPosX, topEdge-decal) -- Draws ENEMIES label between allies and ennemies if any ally ingame
						gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)
						firstEnnemy = false
					end
				end

				decal = decal + vspace

				drawnPlayer.buttony = topEdge - decal - 2 -- stores the y coord of the button for further click detection

				-- DRAWS PLAYER'S INFO
				gl.Color(drawnPlayer.red,drawnPlayer.green,drawnPlayer.blue) -- sets player color
				if drawnPlayer.first == true then
					gl.Texture(sidePics[drawnPlayer.team]) -- sets side image (for leaders)
				else
					gl.Texture(notFirstPic) -- sets image for not leader of team players
				end

				gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX + 16+basicPosX, topEdge - decal + 14) -- draws side image
				gl.Texture(false)

				fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal) -- draws name

				if drawnPlayer.dark == true then -- draws outline if player color is dark
					gl.Color(1,1,1)

					fontHandler.UseFont(fontWOutline) -- name
					fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal)
					fontHandler.UseFont(font)

					if drawnPlayer.first ~= true then -- side pic
						gl.Texture(notFirstPicWO)
						gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX+16+basicPosX, topEdge - decal + 14)
					end
					if sidePicsWO[drawnPlayer.team] ~= nil then
						gl.Texture(sidePicsWO[drawnPlayer.team])
						gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX+16+basicPosX, topEdge - decal + 14)
					end
					gl.Texture(false)
				end

				gl.Color(1,1,1,1)

				if drawnPlayer.first == true then -- FOR LEADERS

					if mySpecStatus == false then -- Non spec mode

						if drawnPlayer.allyteam == myAllyTeamID and drawnPlayer.team ~= myTeamID then
							if drawnPlayer.totake == true and blink == true then -- Draws a blinking rectangle
								gl.Color(1,0.9,0) -- if the player of the same team
								gl.Rect(namePosX-22+basicPosX, topEdge - decal-4, vsx-55+basicPosX, topEdge - decal + 14) -- left (.take option)

								gl.Color(drawnPlayer.red,drawnPlayer.green,drawnPlayer.blue) -- draw player's name and side image again, over the blink
								fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal)
								gl.Texture(notFirstPic)
								gl.TexRect(sidePicPosX+basicPosX,topEdge - decal-2,sidePicPosX + 16+basicPosX, topEdge - decal + 14)
								gl.Color(1,1,1)
							end
						gl.Texture(unitsPic) -- Draws the GIVE UNIT BUTTON if the
						gl.TexRect(button1PosX+basicPosX,topEdge - decal-2,button1PosX+16+basicPosX, topEdge - decal + 14)
						if IsOnButton(mouseX,mouseY,button1PosX+basicPosX,topEdge - decal-2,button1PosX+16+basicPosX, topEdge - decal + 14) then
							tipText = "Double click to Give Units"
						end
						gl.Texture(energyPic) -- Energy
						gl.TexRect(button2PosX+basicPosX,topEdge - decal-2,button2PosX+16+basicPosX, topEdge - decal + 14)
						if IsOnButton(mouseX,mouseY,button2PosX+basicPosX,topEdge - decal-2,button2PosX+16+basicPosX, topEdge - decal + 14) then
							tipText = "Click and drag to Give Energy"
						end
						gl.Texture(metalPic) -- Metal
						gl.TexRect(button3PosX+basicPosX,topEdge - decal-2,button3PosX+16+basicPosX, topEdge - decal + 14)
						if IsOnButton(mouseX,mouseY,button3PosX+basicPosX,topEdge - decal-2,button3PosX+16+basicPosX, topEdge - decal + 14) then
							tipText = "Click and drag to Give Metal"
						end
						gl.Texture(false)
					end
				else -- SPEC MODE
					if specTarget == drawnPlayer.team then -- Adds SPECTATE BUTTON to leaders if the local player is a
						gl.Texture(specPic) -- spectator
					else
						gl.Texture(spec2Pic)
					end
					gl.TexRect(button3PosX+basicPosX,topEdge - decal-2,button3PosX+16+basicPosX, topEdge - decal + 14)
					gl.Texture(false)
					if IsOnButton(mouseX,mouseY,button3PosX+basicPosX,topEdge - decal-2,button3PosX+16+basicPosX, topEdge - decal + 14) then
						tipText = "Look at Player"
					end
					playersToSpecCount=playersToSpecCount + 1 -- update the count of players to spectate
					playersToSpec[playersToSpecCount]=drawnPlayer

				end
			end

			if drawnPlayer.cpul ~= nil then -- draws CPU usage and ping icons (except AI and ghost teams)
				gl.Color(pingCpuColors[drawnPlayer.cpul].r,pingCpuColors[drawnPlayer.cpul].g,pingCpuColors[drawnPlayer.cpul].b)
				gl.Texture(cpuPic)
				gl.TexRect(cpuPosX+basicPosX, topEdge - decal+13, cpuPosX+10+basicPosX,topEdge - decal-3)
				if IsOnButton(mouseX,mouseY,cpuPosX+basicPosX, topEdge - decal-3, cpuPosX+10+basicPosX,topEdge - decal+13) then
					tipText = "Cpu Usage: "..(drawnPlayer.cpu*100-((drawnPlayer.cpu*100)%1)).."%"
				end
				gl.Color(pingCpuColors[drawnPlayer.pingl].r,pingCpuColors[drawnPlayer.pingl].g,pingCpuColors[drawnPlayer.pingl].b)
				gl.Texture(pingPic)
				gl.TexRect(pingPosX+basicPosX, topEdge - decal +15, pingPosX+10+basicPosX, topEdge - decal-1)
				if IsOnButton(mouseX,mouseY,pingPosX+basicPosX, topEdge - decal-1, pingPosX+10+basicPosX, topEdge - decal +15) then
					tipText = "Ping: "..(drawnPlayer.ping*1000-((drawnPlayer.ping*1000)%1)).." ms"
				end
			end
			gl.Texture(false)
			gl.Color(1,1,1,1)
		end

		if spectatorsCount > 0 then
			decal = decal + 20 -- draws spectators if any
			fontHandler.Draw("SPECTATORS", barPosX, topEdge-decal) -- with SPECTATORS label on top
			gl.Rect(barPosX, topEdge-decal-2, vsx, topEdge-decal-3)

			for i,drawnPlayer in ipairs(spectatorsInfo) do
				decal = decal + vspace
				fontHandler.Draw(drawnPlayer.name, namePosX+basicPosX, topEdge - decal)
				if drawnPlayer.cpul ~= nil then -- draws CPU usage and ping icons
					gl.Color(pingCpuColors[drawnPlayer.cpul].r,pingCpuColors[drawnPlayer.cpul].g,pingCpuColors[drawnPlayer.cpul].b)
					gl.Texture(cpuPic)
					gl.TexRect(cpuPosX+basicPosX, topEdge - decal+13, cpuPosX+10+basicPosX,topEdge - decal-3)
					if IsOnButton(mouseX,mouseY,cpuPosX+basicPosX,topEdge - decal-3, cpuPosX+10+basicPosX, topEdge - decal+13) then
						tipText = "Cpu Usage: "..(drawnPlayer.cpu*100-((drawnPlayer.cpu*100)%1)).."%"
					end
					gl.Color(pingCpuColors[drawnPlayer.pingl].r,pingCpuColors[drawnPlayer.pingl].g,pingCpuColors[drawnPlayer.pingl].b)
					gl.Texture(pingPic)
					gl.TexRect(pingPosX+basicPosX, topEdge - decal +15, pingPosX+10+basicPosX, topEdge - decal-1)
					if IsOnButton(mouseX,mouseY,pingPosX+basicPosX, topEdge - decal-1, pingPosX+10+basicPosX, topEdge - decal +15) then
						tipText = "Ping: "..(drawnPlayer.ping*1000-((drawnPlayer.ping*1000)%1)).." ms"
					end
				end
				gl.Texture(false)
				gl.Color(1,1,1,1)
			end
		end

		if tipText ~= nil then
			local tw = fontHandler.GetTextWidth(tipText)
			gl.Color(0.7,0.7,0.7,0.5)
			gl.Rect(mouseX-tw-14,mouseY,mouseX,mouseY+30)
			gl.Color(1,1,1,1)
			fontHandler.DrawRight(tipText,mouseX-7,mouseY+10)
		end
	end

	-- draw give energy/metal sliders

	if firstClickTime+0.2 < Spring.GetGameSeconds() then
		if pressedPlayerGiveEnergy ~= nil then
			gl.Texture(barPic)
			gl.TexRect(button2PosX-1,pressedPlayerGiveEnergy.buttony-3,button2PosX+17,pressedPlayerGiveEnergy.buttony+58)
			gl.Texture(amountPic)
			gl.TexRect(button2PosX-45,pressedPlayerGiveEnergy.buttony-1+amount,button2PosX-1,pressedPlayerGiveEnergy.buttony+17+amount)
			gl.Texture(energyPic)
			gl.TexRect(button2PosX,pressedPlayerGiveEnergy.buttony+amount,button2PosX+16,pressedPlayerGiveEnergy.buttony+16+amount)
			gl.Texture(false)
			fontHandler.DrawCentered(amountEM,button2PosX-22,pressedPlayerGiveEnergy.buttony+3+amount)
		end
		if pressedPlayerGiveMetal ~= nil then
			gl.Texture(barPic)
			gl.TexRect(button3PosX-1,pressedPlayerGiveMetal.buttony-3,button3PosX+17,pressedPlayerGiveMetal.buttony+58)
			gl.Texture(amountPic)
			gl.TexRect(button3PosX-45,pressedPlayerGiveMetal.buttony-1+amount,button3PosX-1,pressedPlayerGiveMetal.buttony+17+amount)
			gl.Texture(metalPic)
			gl.TexRect(button3PosX,pressedPlayerGiveMetal.buttony+amount,button3PosX+16,pressedPlayerGiveMetal.buttony+16+amount)
			gl.Texture(false)
			fontHandler.DrawCentered(amountEM,button3PosX-22,pressedPlayerGiveMetal.buttony+3+amount)
		end
	end

end

--------------------------------------------------------------------------------

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY
	leftEdge								= vsx - 200
	basicPosX								= 54 -- (closed)
	button1PosX,button2PosX,button3PosX		= vsx - 17, vsx - 35, vsx - 53
	cpuPosX,pingPosX						= button3PosX - 14, button3PosX - 25
	sidePicPosX,namePosX					= button3PosX - 200, button3PosX - 180
	barPosX									= sidePicPosX + 54
end

--------------------------------------------------------------------------------

function widget:MousePress(x,y,button)
	if button == 1 then

		amount = 0
		amountEM = 0

		if mySpecStatus == true then -- spec button check
			for _,playerSpec in ipairs(playersToSpec) do
				if IsOnButton(x, y, button3PosX+basicPosX, playerSpec.buttony, button3PosX+16+basicPosX,playerSpec.buttony+16) then
					pressedToSpec = playerSpec
					return true
				end
			end

		else

			for _,playerTake in ipairs(playersToTake) do -- take check
				if IsOnButton(x,y, namePosX-22+basicPosX, playerTake.buttony-2, vsx-55+basicPosX, playerTake.buttony+16) then
					pressedToTake = playerTake
					return true
				end
				end
				if basicPosX == 0 then -- only if give buttons panel is open:

				if pressedPlayerGiveUnit ~= nil then -- give unit check (second click)

					secondClickTime = Spring.GetGameSeconds()

					if IsOnButton(x, y, button1PosX+basicPosX, pressedPlayerGiveUnit.buttony, button1PosX+16+basicPosX,pressedPlayerGiveUnit.buttony+16) then
						if secondClickTime - firstClickTime < 0.3 and secondClickTime - firstClickTime > 0 then
							doubleClick = true
							return true
						else
							firstClickTime = Spring.GetGameSeconds()
							return true
						end
					end
					pressedPlayerGiveUnit = nil
					return true
				end

				for _,playerGive in ipairs(playersGive) do
					if IsOnButton(x, y, button1PosX, playerGive.buttony, button1PosX+16,playerGive.buttony+16) then -- give unit check (first click)
						pressedPlayerGiveUnit = playerGive
						firstClickTime = Spring.GetGameSeconds()
						return true
					end

					if IsOnButton(x, y, button2PosX, playerGive.buttony, button2PosX+16,playerGive.buttony+16) then -- give energy check
						pressedPlayerGiveEnergy = playerGive
						firstClickTime = Spring.GetGameSeconds()
						return true
					end

					if IsOnButton(x, y, button3PosX, playerGive.buttony, button3PosX+16,playerGive.buttony+16) then -- give metal check
						pressedPlayerGiveMetal = playerGive
						firstClickTime = Spring.GetGameSeconds()
						return true
					end

				end
			end


			if IsOnButton(x, y, vsx-17,topEdge,vsx-1,topEdge+16) then -- open/close check
				pressedToOpen = 1
				return true
			end

		end

	elseif button == 3 then

		if IsOnButton(x, y, vsx-17,topEdge,vsx-1,topEdge+16) then -- right click on open close = slide widget
			pressedToMove = 1
			return true
		end    

	end
end


--------------------------------------------------------------------------------

function widget:MouseMove(x,y,dx,dy,button)
	if pressedPlayerGiveEnergy ~= nil or pressedPlayerGiveMetal ~= nil then -- move energy/metal give slider
		if amountStart == nil then
			amountStart = y
		end
		amount = y-amountStart
		if amount < 0 then
			amount = 0
		end
		if amount > 39 then
			amount = 39
		end
	end

	if pressedToMove ~= nil then
		if moveStart == nil then -- move widget on y axis
			moveStart = y - bottomEdge
		end
		bottomEdge = y - moveStart
		if bottomEdge < 0 then
			bottomEdge = 0
		end
		if bottomEdge > vsy - (sizeY+19) then
			bottomEdge = vsy - (sizeY+19)
		end
	end  

end

--------------------------------------------------------------------------------

function widget:MouseRelease(x,y,button)

	if button == 1 then

		if pressedToTake ~= nil then -- take mouse release
			for _,playerTake in ipairs(playersToTake) do
				if IsOnButton(x,y, namePosX-152+basicPosX, playerTake.buttony-2, vsx-55+basicPosX, playerTake.buttony+16) then
					Take()
					pressedToTake = nil
					return -1
				end
			end
		end

		if doubleClick == true then -- give unit mouse release after double click
			if pressedPlayerGiveUnit ~= nil then
				if IsOnButton(x, y, button1PosX, pressedPlayerGiveUnit.buttony, button1PosX+16,pressedPlayerGiveUnit.buttony+16) then
					Spring.ShareResources(pressedPlayerGiveUnit.team, "units")
				end
				pressedPlayerGiveUnit = nil
				doubleClick = false
			end
			return -1
		end

		if pressedPlayerGiveEnergy ~= nil then -- give energy/metal mouse release
			Spring.ShareResources(pressedPlayerGiveEnergy.team,"energy",amountEM)
			amountStart = nil
			amountEMMax = nil
			amount = nil
			amountEM = nil
			pressedPlayerGiveEnergy = nil
		end
		if pressedPlayerGiveMetal ~= nil then
			Spring.ShareResources(pressedPlayerGiveMetal.team,"metal",amountEM)
			amountStart = nil
			amountEMMax = nil
			amount = nil
			amountEM = nil
			pressedPlayerGiveMetal = nil
		end
		-- change spec mouse release
		if pressedToSpec ~= nil then

			if IsOnButton(x, y, button3PosX+basicPosX, pressedToSpec.buttony, button3PosX+16+basicPosX,pressedToSpec.buttony+16) then
				Spring.SendCommands{"specteam "..pressedToSpec.team}
				specTarget = pressedToSpec.team
				return -1
			end
			pressedToSpec = nil 

		end

		if false and pressedToOpen == 1 and IsOnButton(x, y, vsx-17,topEdge,vsx-1,topEdge+16) then -- open/close mouse release
			if basicPosX == 0 then
				openClose = 1
			else
				openClose = 2
			end
			return -1
		end

	end

	if button == 3 then -- reinitialize widget move variable if right mouse button is released
		moveStart = nil
		pressedToMove = nil
	end

end

--------------------------------------------------------------------------------

function widget:IsAbove(x, y) -- used to keep the mouseownage during doubleclick
	if pressedPlayerGiveUnit ~= nil then
		if IsOnButton(x, y, button1PosX, pressedPlayerGiveUnit.buttony, button1PosX+16,pressedPlayerGiveUnit.buttony+16) then
			if not Spring.IsGUIHidden() then
				return true
			end
		end
	end
end

--------------------------------------------------------------------------------

--  Spring.ShareResources(number team, string "units" | "metal" | "energy"[, number amount]) -> nil
-- Spring.MarkerAddPoint(x, y, z, "optional text")
-- function widget:MapDrawCmd(?,type (point),x,y,z,text)
--[03:14:10] <[LCC]jK> 1. you don't need to use the VFS object at all (gl.Texture uses VFS itself already) 2. you use VFS.DirList to search for files and get their path
--[03:15:05] <[MnVt]Marmoth[CA]> what line should i add if i want the program to look in the mod files before looking in the user files?
--[03:15:58] <[LCC]jK> then you need the VFS object, or you know the vfs path syntax
--[03:16:31] <[LCC]jK> just use VFS.DirList with VFS.ZIP_FIRST