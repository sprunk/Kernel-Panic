
function widget:GetInfo()
  return {
    name      = "Start Point Remover",
    desc      = "Deletes your start point once the game begins",
    author    = "TheFatController and jK and zwzsg",
    date      = "Jul 11, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

function widget:GameFrame(f)
  if f > 5 then
    for _,t in ipairs(Spring.GetTeamList()) do
      local x,y,z = Spring.GetTeamStartPosition(t)
      Spring.MarkerErasePosition(x or 0, y or 0, z or 0)
    end
    widgetHandler:RemoveWidget()
  end
end
