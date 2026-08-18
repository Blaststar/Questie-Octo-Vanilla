-- Quest guidance overlays adapted from pfQuest's route.lua: a screen arrow that
-- points at the nearest active objective, and a dotted route across the map and
-- minimap that walks the current zone's objectives in nearest-first order.
QuestieOcto.Arrow = QuestieOcto.Arrow or {}
local A = QuestieOcto.Arrow

local ARROW_TEXTURE="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\arrow"
local ROUTE_TEXTURE="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\route"
local atan2=atan2 or math.atan2

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function modulo(value,by)
  return value-math.floor(value/by)*by
end

-- Red at the player's back, yellow at the sides, green straight ahead.
local function ColorGradient(perc)
  if perc>1 then perc=1 elseif perc<0 then perc=0 end
  local r1,g1,b1,r2,g2,b2
  if perc<=0.5 then
    perc=perc*2
    r1,g1,b1=1,0,0
    r2,g2,b2=1,1,0
  else
    perc=perc*2-1
    r1,g1,b1=1,1,0
    r2,g2,b2=0,1,0
  end
  return r1+(r2-r1)*perc, g1+(g2-g1)*perc, b1+(b2-b1)*perc
end

local function PlayerFacing()
  if GetPlayerFacing then return GetPlayerFacing() or 0 end
  if MiniMapCompassRing and MiniMapCompassRing.GetFacing then
    return MiniMapCompassRing:GetFacing()*-1
  end
  return 0
end

local function CurrentMapID()
  if GetRealZoneText and QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetMapIDByName then
    local id=QuestieOcto.DatabaseAPI:GetMapIDByName(GetRealZoneText())
    if id then return tonumber(id) end
  end
  if QuestieOcto.API and QuestieOcto.API.GetBestMapForPlayer then
    return tonumber(QuestieOcto.API:GetBestMapForPlayer())
  end
  return nil
end

local function IsArrowRole(role)
  return role=="objectiveCreature" or role=="objectiveObject"
      or role=="objectiveItemSource" or role=="turnin"
end

-- Pull the current map's prepared plan and keep only objective/turn-in slots,
-- dropping any the quest menu has hidden and recording each node's objective
-- index so focus can filter by objective.
local function CollectTargets(mapID)
  local targets={}
  local plan=mapID and QuestieOcto.PreparedMap and QuestieOcto.PreparedMap:Get(mapID) or nil
  if not plan then return targets end

  local menu=QuestieOcto.QuestMenu
  for _,desc in pairs(plan) do
    local node
    if desc.type=="nodeSlot" then
      for _,entry in pairs(desc.entries or {}) do
        local n=entry.node
        if n and IsArrowRole(n.role) then node=n; break end
      end
    elseif desc.type=="node" and desc.node and IsArrowRole(desc.node.role) then
      node=desc.node
    end

    if node and (not menu or not menu:IsNodeHidden(node)) then
      local x,y=tonumber(desc.x),tonumber(desc.y)
      if x and y then table.insert(targets,{x,y,node.questID,tonumber(node.objectiveIndex)}) end
    end
  end

  return targets
end

-- When an objective is focused, restrict to its nodes (falling back to all when
-- the focused objective has no node in this zone).
local function FocusTargets(targets)
  if not QuestieOcto.QuestMenu then return targets end
  local fq,fo=QuestieOcto.QuestMenu:GetFocus()
  if not fq then return targets end
  local filtered={}
  local i=1
  local total=table.getn(targets)
  while i<=total do
    local t=targets[i]
    if tonumber(t[3])==fq and tonumber(t[4])==fo then table.insert(filtered,t) end
    i=i+1
  end
  if table.getn(filtered)>0 then return filtered end
  return targets
end

local function NearestTarget(targets,px,py)
  local best,bestDist
  for _,t in pairs(targets or {}) do
    local dx,dy=(px-t[1])*1.5,(py-t[2])
    local d=math.sqrt(dx*dx+dy*dy)
    if not bestDist or d<bestDist then bestDist=d; best=t end
  end
  return best,bestDist
end

-- Greedy nearest-neighbor ordering starting from the objective closest to the
-- player, the same heuristic pfQuest uses to approximate the shortest route.
local function BuildRoute(targets,px,py,forceFirst)
  local n=table.getn(targets)
  if n==0 then return {} end
  local used={}
  local route={}
  local cx,cy=px,py
  if forceFirst then
    local fi=1
    while fi<=n do
      if targets[fi]==forceFirst then
        used[fi]=true
        route[1]=forceFirst
        cx,cy=forceFirst[1],forceFirst[2]
        break
      end
      fi=fi+1
    end
  end
  local placed=table.getn(route)
  while placed<n do
    local bestIdx,bestDist
    local j=1
    while j<=n do
      if not used[j] then
        local dx,dy=(cx-targets[j][1])*1.5,(cy-targets[j][2])
        local d=dx*dx+dy*dy
        if not bestDist or d<bestDist then bestDist=d; bestIdx=j end
      end
      j=j+1
    end
    if not bestIdx then break end
    used[bestIdx]=true
    route[table.getn(route)+1]=targets[bestIdx]
    cx,cy=targets[bestIdx][1],targets[bestIdx][2]
    placed=placed+1
  end
  return route
end

local routeWorldDots={}
local routeMiniDots={}
local routeWorldFrame=nil
local routeMiniFrame=nil

local function EnsureRouteFrames()
  if not routeWorldFrame and WorldMapButton then
    routeWorldFrame=CreateFrame("Frame","QuestieOctoRouteWorld",WorldMapButton)
    routeWorldFrame:SetAllPoints(WorldMapButton)
    if routeWorldFrame.SetFrameLevel and WorldMapButton.GetFrameLevel then
      routeWorldFrame:SetFrameLevel(WorldMapButton:GetFrameLevel()+1)
    end
  end
  if not routeMiniFrame and Minimap then
    routeMiniFrame=CreateFrame("Frame","QuestieOctoRouteMini",Minimap)
    routeMiniFrame:SetAllPoints(Minimap)
  end
end

local function AcquireDot(pool,parent,index)
  local tex=pool[index]
  if not tex then
    tex=parent:CreateTexture(nil,"OVERLAY")
    tex:SetWidth(5)
    tex:SetHeight(5)
    tex:SetTexture(ROUTE_TEXTURE)
    tex:SetVertexColor(1,.8,.2,.9)
    pool[index]=tex
  end
  return tex
end

local function HideDotsFrom(pool,index)
  local i=index
  local total=table.getn(pool)
  while i<=total do
    if pool[i] then pool[i]:Hide() end
    i=i+1
  end
end

local function SegmentSteps(dx,dy)
  local steps=math.floor(math.sqrt(dx*1.5*dx*1.5+dy*dy))
  if steps<1 then steps=1 end
  return steps
end

local function DrawWorldSegment(x1,y1,x2,y2,index)
  local width=WorldMapButton:GetWidth()
  local height=WorldMapButton:GetHeight()
  if not width or width<=0 or not height or height<=0 then return index end
  local dx,dy=x2-x1,y2-y1
  local steps=SegmentSteps(dx,dy)
  local i=1
  while i<=steps do
    local x=x1+dx*i/steps
    local y=y1+dy*i/steps
    local tex=AcquireDot(routeWorldDots,routeWorldFrame,index)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER",WorldMapButton,"TOPLEFT",width*(x/100),-height*(y/100))
    tex:Show()
    index=index+1
    i=i+1
  end
  return index
end

local function DrawMiniSegment(proj,x1,y1,x2,y2,index)
  local dx,dy=x2-x1,y2-y1
  local steps=SegmentSteps(dx,dy)
  local i=1
  while i<=steps do
    local x=x1+dx*i/steps
    local y=y1+dy*i/steps
    local ox=(x-proj.px)*proj.xDraw
    local oy=-(y-proj.py)*proj.yDraw
    local inside
    if proj.square then
      inside=math.abs(ox)<(proj.width/2) and math.abs(oy)<(proj.height/2)
    else
      inside=(ox*ox+oy*oy)<(proj.radius*proj.radius)
    end
    if inside then
      local tex=AcquireDot(routeMiniDots,routeMiniFrame,index)
      tex:ClearAllPoints()
      tex:SetPoint("CENTER",Minimap,"CENTER",ox,oy)
      tex:Show()
      index=index+1
    end
    i=i+1
  end
  return index
end

function A:ClearRoute()
  HideDotsFrom(routeWorldDots,1)
  HideDotsFrom(routeMiniDots,1)
end

function A:UpdateRoute()
  if (self.routeThrottle or 0)>GetTime() then return end
  self.routeThrottle=GetTime()+0.1

  EnsureRouteFrames()

  if not Settings():Get("showQuestRoute") then
    self:ClearRoute()
    return
  end

  local px,py
  if GetPlayerMapPosition then px,py=GetPlayerMapPosition("player") end
  px,py=(px or 0)*100,(py or 0)*100
  if px==0 and py==0 then self:ClearRoute(); return end

  local mapID=CurrentMapID()
  if mapID~=self.routeMapID or (self.routeRefresh or 0)<GetTime() then
    self.routeMapID=mapID
    self.routeTargets=CollectTargets(mapID)
    self.routeRefresh=GetTime()+1
  end

  local targets=self.routeTargets or {}
  if table.getn(targets)==0 then self:ClearRoute(); return end

  -- A focused objective becomes the route's first stop.
  local forceFirst,fq,fo
  if QuestieOcto.QuestMenu then fq,fo=QuestieOcto.QuestMenu:GetFocus() end
  if fq then
    local bestD
    local i=1
    local total=table.getn(targets)
    while i<=total do
      local t=targets[i]
      if tonumber(t[3])==fq and tonumber(t[4])==fo then
        local dx,dy=(px-t[1])*1.5,(py-t[2])
        local d=dx*dx+dy*dy
        if not bestD or d<bestD then bestD=d; forceFirst=t end
      end
      i=i+1
    end
  end

  -- Only reorder when the target set, the nearest objective, or the focus changes.
  local nearest=NearestTarget(targets,px,py)
  local sig=tostring(table.getn(targets))..":"..(nearest and (tostring(nearest[1])..":"..tostring(nearest[2])) or "")
    ..":"..tostring(fq)..":"..tostring(fo)
  if sig~=self.routeSig then
    self.routeSig=sig
    self.routeOrder=BuildRoute(targets,px,py,forceFirst)
  end
  local order=self.routeOrder or {}

  -- World-map dots sit at fixed zone coordinates, so only redraw them when the
  -- route, the displayed map, or the map size actually changes.
  local displayed=QuestieOcto.Map and QuestieOcto.Map.GetDisplayedMapID and QuestieOcto.Map:GetDisplayedMapID()
  local worldVisible=WorldMapButton and WorldMapButton:IsVisible() and tonumber(displayed)==tonumber(mapID)
  local worldSig=worldVisible and (sig.."@"..tostring(WorldMapButton:GetWidth())) or "hidden"
  if worldSig~=self.routeWorldSig then
    self.routeWorldSig=worldSig
    local worldIndex=1
    if worldVisible then
      if order[1] then worldIndex=DrawWorldSegment(px,py,order[1][1],order[1][2],worldIndex) end
      local i=2
      while i<=table.getn(order) do
        worldIndex=DrawWorldSegment(order[i-1][1],order[i-1][2],order[i][1],order[i][2],worldIndex)
        i=i+1
      end
    end
    HideDotsFrom(routeWorldDots,worldIndex)
  end

  local miniIndex=1
  local proj=QuestieOcto.Minimap and QuestieOcto.Minimap.GetProjection and QuestieOcto.Minimap:GetProjection()
  if proj then
    if order[1] then miniIndex=DrawMiniSegment(proj,px,py,order[1][1],order[1][2],miniIndex) end
    local i=2
    while i<=table.getn(order) do
      miniIndex=DrawMiniSegment(proj,order[i-1][1],order[i-1][2],order[i][1],order[i][2],miniIndex)
      i=i+1
    end
  end
  HideDotsFrom(routeMiniDots,miniIndex)
end

function A:OnUpdate()
  local frame=self.frame
  if not frame then return end

  if not Settings():Get("showQuestArrow") then
    if frame:IsShown() then frame:Hide() end
    return
  end

  local px,py
  if GetPlayerMapPosition then px,py=GetPlayerMapPosition("player") end
  px,py=(px or 0)*100,(py or 0)*100
  if px==0 and py==0 then
    if frame:IsShown() then frame:Hide() end
    return
  end

  local mapID=CurrentMapID()
  if mapID~=frame.mapID or (frame.refresh or 0)<GetTime() then
    frame.mapID=mapID
    frame.targets=CollectTargets(mapID)
    frame.refresh=GetTime()+1
  end

  local best,bestDist=NearestTarget(FocusTargets(frame.targets),px,py)
  if not best then
    if frame:IsShown() then frame:Hide() end
    return
  end
  if not frame:IsShown() then frame:Show() end

  -- Arrow direction and sprite-sheet cell math taken from pfQuest/TomTomVanilla.
  local xDelta=(best[1]-px)*1.5
  local yDelta=(best[2]-py)
  local dir=atan2(xDelta,-(yDelta))
  dir=dir>0 and (math.pi*2)-dir or -dir
  if dir<0 then dir=dir+360 end
  local angle=math.rad(dir)-PlayerFacing()
  local perc=math.abs((math.pi-math.abs(angle))/math.pi)
  local r,g,b=ColorGradient(math.floor(perc*100)/100)
  local cell=modulo(math.floor(angle/(math.pi*2)*108+0.5),108)
  local column=modulo(cell,9)
  local row=math.floor(cell/9)
  frame.model:SetTexCoord((column*56)/512,((column+1)*56)/512,(row*42)/512,((row+1)*42)/512)
  frame.model:SetVertexColor(r,g,b)

  if best[3]~=frame.lastQuest then
    frame.lastQuest=best[3]
    local q=best[3] and QuestieOcto.QuestModel:Get(best[3]) or nil
    local level=q and tonumber(q.level)
    local label=q and q.title or "Quest"
    if level and level>0 then label="["..tostring(level).."] "..label end
    frame.title:SetText(label)
    local cr,cg,cb=1,.82,0
    if q and QuestieOcto.GetNativeQuestDifficultyColor then
      local nr,ng,nb=QuestieOcto:GetNativeQuestDifficultyColor(q.level,q.id)
      if nr then cr,cg,cb=nr,ng,nb end
    end
    frame.title:SetTextColor(cr,cg,cb)
  end

  local shown=math.floor(bestDist*10)/10
  if shown~=frame.shownDistance then
    frame.shownDistance=shown
    frame.distance:SetText("Distance: "..string.format("%.1f",bestDist))
  end
end

function A:Initialize()
  if self.frame then return end

  local frame=CreateFrame("Frame","QuestieOctoQuestArrow",UIParent)
  frame:SetPoint("CENTER",UIParent,"CENTER",0,-100)
  frame:SetWidth(48)
  frame:SetHeight(36)
  if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart",function() if IsShiftKeyDown() then this:StartMoving() end end)
  frame:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)

  local model=frame:CreateTexture("QuestieOctoQuestArrowModel","ARTWORK")
  model:SetTexture(ARROW_TEXTURE)
  model:SetTexCoord(0,56/512,0,42/512)
  model:SetAllPoints(frame)
  frame.model=model

  local font=STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

  local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
  title:SetPoint("TOP",model,"BOTTOM",0,-10)
  title:SetFont(font,13,"OUTLINE")
  title:SetTextColor(1,.82,0)
  title:SetJustifyH("CENTER")
  frame.title=title

  local distance=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
  distance:SetPoint("TOP",title,"BOTTOM",0,-2)
  distance:SetFont(font,11,"OUTLINE")
  distance:SetTextColor(.8,.8,.8)
  distance:SetJustifyH("CENTER")
  frame.distance=distance

  frame:Hide()
  self.frame=frame

  -- A hidden frame receives no OnUpdate, so drive the logic from an always-shown
  -- frame that shows/hides the arrow.
  local driver=CreateFrame("Frame","QuestieOctoQuestArrowDriver",UIParent)
  driver:SetScript("OnUpdate",function() A:OnUpdate(); A:UpdateRoute() end)
  self.driver=driver
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",A,"Initialize")
