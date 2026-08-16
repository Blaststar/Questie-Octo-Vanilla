QuestieOcto.Clustering = QuestieOcto.Clustering or {}
local C = QuestieOcto.Clustering

C.objectiveRadius=9.0
C.itemStartRadius=12.0

local function Dist(x1,y1,x2,y2)
  local dx=x1-x2
  local dy=y1-y2
  return math.sqrt(dx*dx+dy*dy)
end

function C:BuildAreas(points,radius)
  local areas={}
  if not points then return areas end

  table.sort(points,function(a,b)
    if a.x==b.x then return a.y<b.y end
    return a.x<b.x
  end)

  for _,p in pairs(points) do
    local best=nil
    local bestDist=nil

    for _,area in pairs(areas) do
      local cx=area.sx/area.n
      local cy=area.sy/area.n
      local d=Dist(p.x,p.y,cx,cy)

      if d<=radius and (not bestDist or d<bestDist) then
        best=area
        bestDist=d
      end
    end

    if best then
      best.sx=best.sx+p.x
      best.sy=best.sy+p.y
      best.n=best.n+1
      if p.x<best.anchorX or (p.x==best.anchorX and p.y<best.anchorY) then
        best.anchorX=p.x
        best.anchorY=p.y
      end
    else
      table.insert(areas,{sx=p.x,sy=p.y,n=1,anchorX=p.x,anchorY=p.y})
    end
  end

  for _,area in pairs(areas) do
    area.x=area.sx/area.n
    area.y=area.sy/area.n
    area.key=string.format("%.1f:%.1f",area.anchorX,area.anchorY)
  end

  return areas
end

function C:PointsForNodeOnMap(node,mapID)
  local result={}
  if not node or not node.coords then return result end

  for _,coord in pairs(node.coords) do
    if type(coord)=="table" and tonumber(coord[3])==tonumber(mapID) then
      local x=tonumber(coord[1])
      local y=tonumber(coord[2])
      if x and y then table.insert(result,{x=x,y=y}) end
    end
  end

  return result
end
