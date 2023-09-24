
function widget:GetInfo()
  return {
    name      = "Action Finder",
    desc      = "Focuses the camera to the places of the map with a lot of action.",
    author    = "xyz & zwzsg",
    date      = "May 26, 2009",
    license   = "GNU GPL, v2 or later",
    version   = "1.3",
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local TRANSITION_DURATION   = 2
local CAMERA_IDLE_RESPONSE  = 10
local CAMERA_FIGHT_RESPONSE = 5
local USER_IDLE_RESUME      = 10

local limit = 0.1
local eventScale = 0.02
local fracScale = 50
local healthScale = 0 -- 0.001
local paraFracScale = fracScale * 0.25
local paraHealthScale = healthScale * 0

--------------------------------------------------------------------------------

local DEATH_EVENT            = 0
local TAKE_EVENT             = 1
local CREATE_EVENT           = 2
local CREATE_START_EVENT     = 3
local STOCKPILE_EVENTS       = 4
local DAMAGE_EVENTS          = 5
local PARALYZE_EVENT         = 6

--------------------------------------------------------------------------------

local lastUpdate = nil -- Timer
local lastMove = nil -- Timer
local lastUserMove = nil -- Timer
local samePos = 0
local ChangeModCounter = 1
local lastMouseX = nil
local lastMouseY = nil
local WantedX,WantedZ,WantedID
local inSpecMode = false

local SavedInitialCameraState = nil
local eventMap  = {}
local damageMap = {}

--------------------------------------------------------------------------------

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function PickCameraMode(x,z,id)
  lastMove = spGetTimer()
  samePos=samePos+1
  WantedX=x
  WantedZ=z
  WantedID=nil
  ChangeModCounter=math.random(0,4)
  Spring.SelectUnitArray({})
  local RandomMode=math.random(1,4)
  if RandomMode==1 then
    -- TA Overview
    Spring.SetCameraState({name=ta,mode=1,px=x,py=0,pz=z,flipped=-1,dy=-0.9,zscale=0.5,height=999,dx=0,dz=-0.45},TRANSITION_DURATION)
  elseif (RandomMode==2 or RandomMode==4) and id and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
    local vx,vy,vz=Spring.GetUnitVelocity(id)
    if vx and vy and vz and vx^2+vy^2+vz^2>0.1^2 then
      -- FPS, tracking
      Spring.SetCameraState({name=fps,mode=0,px=x,py=Spring.GetGroundHeight(x,z)+20,pz=z,rz=0,dx=0,dy=-1,ry=9,rx=-1,dz=-0.5,oldHeight=999},0)
      Spring.SelectUnitArray({id})
      Spring.SendCommands("track")
      Spring.SelectUnitArray({})
      WantedX=nil
      WantedZ=nil
      WantedID=id
    end
  else
    -- Total war, close to ground
    Spring.SetCameraState({name=tw,mode=2,rz=0,rx=math.random(-100,0)/100,ry=math.random(-50,50)/10,px=x,py=0,pz=z},TRANSITION_DURATION)
  end
end

--------------------------------------------------------------------------------

local function UpdateCamera(pozX, pozZ, Uid)
    lastMove = spGetTimer()
    if ChangeModCounter>0 then
      ChangeModCounter=ChangeModCounter-1
      if WantedID and Spring.ValidUnitID(WantedID) then
        local x,_,z=Spring.GetUnitPosition(WantedID)
        if WantedX and WantedZ and x==WantedX and z==WantedZ then
          -- The unit we're tracking is stopped, changing camera
          samePos = 0
          Spring.SendCommands("trackoff")
          PickCameraMode(pozX,pozZ, Uid)
        end
      else
        WantedX=pozX
        WantedZ=pozZ
        WantedID=nil
        samePos = 0
        Spring.SendCommands("trackoff")
        Spring.SetCameraTarget(pozX, 0, pozZ, TRANSITION_DURATION)
      end
    else
      samePos = 0
      Spring.SendCommands("trackoff")
      PickCameraMode(pozX,pozZ,Uid)
    end
end

--------------------------------------------------------------------------------

local function UserAction()
  if inSpecMode and not lastUserMove then
    Spring.SendCommands("hideinterface 0")
  end
  lastUserMove = spGetTimer()
  WantedX=nil
  WantedZ=nil
  WantedID=nil
end

--------------------------------------------------------------------------------

local function EnterSpecMode()
  Spring.Echo("Start spec mode / action finder")
  SavedInitialCameraState = Spring.GetCameraState()
  inSpecMode = true
  ChangeModCounter=3
  if (not lastUserMove) or spDiffTimers(spGetTimer(),lastUserMove) > USER_IDLE_RESUME then
   Spring.SendCommands("hideinterface 1")
    if Spring.GetGameFrame()<9 then
      local x, z = Game.mapSizeX/2, Game.mapSizeZ/2
      local y = 512+Spring.GetGroundHeight(x,z)
      Spring.SetCameraTarget(x, y, z, 0)
      SavedInitialCameraState = Spring.GetCameraState()
    end
  end
end

--------------------------------------------------------------------------------

local function LeaveSpecMode()
  Spring.Echo("End spec mode / action finder")
  if SavedInitialCameraState then
    Spring.SetCameraState(SavedInitialCameraState,TRANSITION_DURATION)
    SavedInitialCameraState=nil
  end
  Spring.SendCommands("hideinterface 0")
  inSpecMode = false
end

--------------------------------------------------------------------------------

function widget:TextCommand(command)
  if (command == 'specmode' or command == 'specmode 1' or command == 'autocamera'  or command == 'autocamera 1' or command == 'actionfinder' or command == 'actionfinder 1')
        and not inSpecMode then
    lastUserMove = nil
    EnterSpecMode()
    return false
  elseif (command == 'specmode' or command == 'specmode 0' or command == 'autocamera'  or command == 'autocamera 0' or command == 'actionfinder' or command == 'actionfinder 0')
        and inSpecMode then
    LeaveSpecMode()
  end
  local cmd = string.sub(command, 10)
  return true
end

--------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
  local ESCAPE = 27
  if key == ESCAPE and inSpecMode and
       not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
    LeaveSpecMode()
    return true
  end
  UserAction()
  return false
end

--------------------------------------------------------------------------------

function widget:Initialize()
  lastUpdate = spGetTimer()
  lastMove = spGetTimer()
  lastUserMove = nil
  if Spring.GetSpectatingState() then
    EnterSpecMode()
  else
    LeaveSpecMode()
  end
end

--------------------------------------------------------------------------------

function widget:PlayerChanged(playerID)
  if Spring.GetSpectatingState() and not inSpecMode then
    EnterSpecMode()
  else
    LeaveSpecMode()
  end
end

--------------------------------------------------------------------------------

function widget:Shutdown()
  LeaveSpecMode()
end

--------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
  lastUserMove = spGetTimer()
end

--------------------------------------------------------------------------------

function widget:MouseMove(x, y, dx, dy, button)
  UserAction()
end

--------------------------------------------------------------------------------

function widget:MouseRelease(x, y, button)
  UserAction()
end

--------------------------------------------------------------------------------

function widget:MouseWheel(up, value)
  UserAction()
end

--------------------------------------------------------------------------------

local function DrawEvent(event)
  if spDiffTimers(spGetTimer(),lastMove) > CAMERA_IDLE_RESPONSE then
    UpdateCamera(event.x, event.z)
  end
end

--------------------------------------------------------------------------------

local function DrawDamage(damage)

  local u=nil
  if damage.u and Spring.ValidUnitID(damage.u) then
    u=damage.u
  elseif damage.a and Spring.ValidUnitID(damage.a) then
    u=damage.a
  end
  if damage.u and Spring.ValidUnitID(damage.u) and not Spring.GetUnitIsDead(damage.u) then
    local vx,vy,vz=Spring.GetUnitVelocity(damage.u)
    if vx and vy and vz and vx^2+vy^2+vz^2>0.1^2 then
      u=damage.u
    end
  end
  if damage.a and Spring.ValidUnitID(damage.a) and not Spring.GetUnitIsDead(damage.a) then
    local vx,vy,vz=Spring.GetUnitVelocity(damage.a)
    if vx and vy and vz and vx^2+vy^2+vz^2>0.1^2 then
      u=damage.a
    end
  end
  if u==nil then
    return
  end

  local x, y, z = Spring.GetUnitPosition(u)

  if spDiffTimers(spGetTimer(),lastMove) > CAMERA_FIGHT_RESPONSE then
    UpdateCamera(x, z, u)
  end
end

--------------------------------------------------------------------------------

local function IsFullViewSpec()
  local spectating, fullView, fullSelect = Spring.GetSpectatingState()
  if spectating and fullView then
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------

local function MouseMoved()
  local x, y, lmb, mmb, rmb = Spring.GetMouseState()
  if (not lastMouseX) or (not lastMouseY) then
    lastMouseX = x
    lastMouseY = y
  end
  if x ~= lastMouseX or y ~= lastMouseY then
    lastMouseX = x
    lastMouseY = y
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------

function widget:Update(dt)

  -- If specmode is not activated no need to update.
  if not inSpecMode then
    return
  end

  -- Don't update every second
  if spDiffTimers(spGetTimer(),lastUpdate) < 1 then
    return
  end
  lastUpdate = spGetTimer()

  -- If user has taken manual control pause the script for USER_IDLE_RESUME seconds
  if lastUserMove and spDiffTimers(spGetTimer(),lastUserMove) < USER_IDLE_RESUME then
    return
  end
  Spring.SendCommands("hideinterface 1")
  lastUserMove = nil

  local scale = (1 + (4 * dt))

  for unitID, d in pairs(eventMap) do
    local v = d.v
    v = v * scale
    if (v < limit) then
      eventMap[unitID] = nil
    else
      d.v = v
    end
  end

  for unitID, d in pairs(damageMap) do
      local v = d.v * scale
      local p = d.p * scale

      if (v > limit) then
        d.v = v
      else
        if (p > limit) then 
          d.v = 0
        else
          damageMap[unitID] = nil
        end
      end

      if (p > 1) then
        d.p = p
      else
        if (v > 1) then 
          d.p = 0
        else
          damageMap[unitID] = nil
        end
      end
  end
  
  if ((next(eventMap)  == nil) and
      (next(damageMap) == nil)) then
    return
  end

  for _,event in pairs(eventMap) do
    DrawEvent(event)
  end

  for _,damage in pairs(damageMap) do
    DrawDamage(damage)
  end

end

--------------------------------------------------------------------------------

local function AddEvent(unitID, unitDefID, color, cost)
  if (not IsFullViewSpec()) and (not Spring.IsUnitAllied(unitID)) then
    return
  end
  local ud = UnitDefs[unitDefID]
  if ((ud == nil) or ud.isFeature) then
    return
  end
  local px, py, pz = Spring.GetUnitPosition(unitID)
  if (px and pz) then
    eventMap[unitID] = {
      x = px,
      z = pz,
      v = (cost or (ud.cost * eventScale))*(color==DEATH_EVENT and 5 or 1),
      u = unitID,
      c = color,
--      t = spGetTimer()
    }
  end
end

--------------------------------------------------------------------------------

local function IsTerrainViewable(x1,z1)
  local y1=Spring.GetGroundHeight(x1,z1)
  local xs,ys=Spring.WorldToScreenCoords(x1,y1,z1)
  local _,pos=Spring.TraceScreenRay(xs,ys,true,false)
  if pos then
    local x2,y2,z2=unpack(pos)
    ---Spring.Echo("e="..math.sqrt((x2-x1)^2+(y2-y1)^2+(z2-z1)^2))
    if ((x2-x1)^2+(y2-y1)^2+(z2-z1)^2)<150^2 then
      return true
    else
      return false
    end
  else
    return nil
  end
end

--------------------------------------------------------------------------------

function widget:DrawWorldPreUnit()
  if MouseMoved() then
    UserAction()
    return
  end
  if WantedX and WantedZ and not WantedID then
    if spDiffTimers(spGetTimer(),lastMove) <= TRANSITION_DURATION+0.2 then
      return
    elseif not IsTerrainViewable(WantedX,WantedZ) and samePos<7 then
      Spring.Echo("View blocked, redoing it.")
      PickCameraMode(WantedX,WantedZ)
    end
  end
end

--------------------------------------------------------------------------------

function widget:DrawScreen()
  -- Spring.SetMouseCursor("none") -- Only works when interface is drawn o_O
end

--------------------------------------------------------------------------------

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  AddEvent(unitID, unitDefID, CREATE_START_EVENT)
end

--------------------------------------------------------------------------------

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  AddEvent(unitID, unitDefID, CREATE_EVENT)
end

--------------------------------------------------------------------------------

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  damageMap[unitID] = nil
  AddEvent(unitID, unitDefID, DEATH_EVENT)
  if WantedID and unitID==WantedID then
    WantedID=nil
    local x,_,z=Spring.GetUnitPosition(unitID)
    PickCameraMode(x,z)
  end
end

--------------------------------------------------------------------------------

function widget:UnitTaken(unitID, unitDefID)
  damageMap[unitID] = nil
  AddEvent(unitID, unitDefID, TAKE_EVENT)
end

--------------------------------------------------------------------------------

function widget:StockpileChanged(unitID, unitDefID, unitTeam,
                                 weaponNum, oldCount, newCount)
  if (newCount > oldCount) then
    AddEvent(unitID, unitDefID, STOCKPILE_EVENTS, 100)
  end
end

--------------------------------------------------------------------------------

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID)

  if (not IsFullViewSpec()) and (not Spring.IsUnitAllied(unitID)) then
    return
  end
  if (damage <= 0) then
    return
  end

  local ud = UnitDefs[unitDefID]
  if (ud == nil) then
    return
  end

  -- clamp the damage
  damage = math.min(ud.health, damage)

  -- scale the damage value
  if (paralyzer) then
    damage = (paraHealthScale * damage) +
             (paraFracScale   * (damage / ud.health)) 
  else
    damage = (healthScale * damage) +
             (fracScale   * (damage / ud.health)) 
  end

  local d = damageMap[unitID]
  if (d ~= nil) then
    d.a = attackerID
    if (paralyzer) then
      d.p = d.p + damage
    else
      d.v = d.v + damage
    end
  else
    d = {}
    d.u = unitID
    d.a = attackerID
--    d.t = spGetTimer()
    if (paralyzer) then
      d.v = 0
      d.p = math.max(1, damage)
    else
      d.v = math.max(1, damage)
      d.p = 0
    end
    damageMap[unitID] = d
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
