-- Quest arrow that points toward the nearest active quest objective in the
-- current zone, adapted from pfQuest's route arrow.
QuestieOcto.Arrow = QuestieOcto.Arrow or {}
local A = QuestieOcto.Arrow

local ARROW_TEXTURE="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\arrow"
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

-- Pull the current map's prepared plan and keep only objective/turn-in slots.
local function CollectTargets(mapID)
  local targets={}
  local plan=mapID and QuestieOcto.PreparedMap and QuestieOcto.PreparedMap:Get(mapID) or nil
  if not plan then return targets end

  for _,desc in pairs(plan) do
    local x,y,questID
    if desc.type=="nodeSlot" then
      for _,entry in pairs(desc.entries or {}) do
        local node=entry.node
        if node and IsArrowRole(node.role) then
          x,y,questID=tonumber(desc.x),tonumber(desc.y),node.questID
          break
        end
      end
    elseif desc.type=="node" and desc.node and IsArrowRole(desc.node.role) then
      x,y,questID=tonumber(desc.x),tonumber(desc.y),desc.node.questID
    end

    if x and y then table.insert(targets,{x,y,questID}) end
  end

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

  local best,bestDist=NearestTarget(frame.targets,px,py)
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
  driver:SetScript("OnUpdate",function() A:OnUpdate() end)
  self.driver=driver
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",A,"Initialize")
