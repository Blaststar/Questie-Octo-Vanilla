QuestieOcto.Map = QuestieOcto.Map or {}
local M = QuestieOcto.Map

local function DisplaySettings()
  return QuestieOcto.MinimapSettings
end

local function IsPermanentRole(role)
  return role=="flightMaster" or role=="auctioneer" or role=="banker"
      or role=="mailbox" or role=="battlemaster" or role=="innkeeper"
      or role=="meetingStone" or role=="repair" or role=="spiritHealer"
      or role=="stableMaster" or role=="vendor" or role=="rareMob"
end

local function IsSpecialQuestNode(node)
  return node and (node.pvp or node.repeatable or node.event) and true or false
end

local function IsQuestMarkerNodeEnabled(node)
  local settings=DisplaySettings()
  if IsSpecialQuestNode(node) then
    return settings:Get("showSpecialQuestsWorldMap") and true or false
  end
  return settings:Get("showAllQuestsWorldMap") and true or false
end

local function IsPvPQuestNodeEnabled(node)
  if node and node.pvp then
    return DisplaySettings():Get("showPvPRelatedQuests") and true or false
  end
  return true
end

local function IsRoleEnabled(role)
  local settings=DisplaySettings()
  if role=="auctioneer" then return settings:Get("showMapAuctioneer") and true or false end
  if role=="banker" then return settings:Get("showMapBanker") and true or false end
  if role=="flightMaster" then return settings:Get("showMapFlightMaster") and true or false end
  if role=="mailbox" then return settings:Get("showMapMailbox") and true or false end
  if role=="battlemaster" then return settings:Get("showMapBattlemaster") and true or false end
  if role=="innkeeper" then return settings:Get("showMapInnkeeper") and true or false end
  if role=="meetingStone" then return settings:Get("showMapMeetingStone") and true or false end
  if role=="repair" then return settings:Get("showMapRepair") and true or false end
  if role=="spiritHealer" then return settings:Get("showMapSpiritHealer") and true or false end
  if role=="stableMaster" then return settings:Get("showMapStableMaster") and true or false end
  if role=="vendor" then return settings:Get("showMapVendor") and true or false end
  if role=="rareMob" then return settings:Get("showMapRareMonsters") and true or false end
  if not settings:Get("enableMapIcons") then return false end

  if role=="itemStart" then
    return settings:Get("enableAvailable")
       and settings:Get("showItemStartQuests")
       and settings:Get("showItemStartMap")
       and true or false
  elseif role=="available" then
    return settings:Get("enableAvailable") and true or false
  elseif role=="turnin" then
    return settings:Get("enableTurnins") and true or false
  else
    return settings:Get("enableObjectives") and true or false
  end
end


M.enabled=true
M.mapID=nil
M.generation=0
M.syncing=false
M.resync=false
M.prune=false
M.frames={}
M.activeFrames={}
M.buildActiveFrames=nil
M.renderedPreparedPlan=nil
M.syncPreparedPlan=nil
M.renderedNodeRevision=0
M.syncNodeRevision=nil
M.stats={active=0,created=0,reused=0,hidden=0,exact=0,objectiveAreas=0,itemStartAreas=0,syncs=0,visibleAvailable=0,visibleItemStart=0,visibleObjective=0,visibleTurnin=0,inputNodes=0,multiEntryPins=0,itemStartRawNodes=0,itemStartAreaPins=0,preparedHits=0,preparedMisses=0,preparedDescriptors=0,mapPriorityRequests=0}

local ICON_ROOT="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\"
local TEX_AVAILABLE=ICON_ROOT.."available"
local TEX_MOBDROP=ICON_ROOT.."available_mobdrop"
local TEX_OBJECTSTART=ICON_ROOT.."available_object"
local TEX_COMPLETE=ICON_ROOT.."complete"
local TEX_EVENT_AVAILABLE=ICON_ROOT.."eventquest"
local TEX_EVENT_COMPLETE=ICON_ROOT.."eventquest_complete"
local TEX_REPEATABLE_AVAILABLE=ICON_ROOT.."repeatable"
local TEX_PVP_AVAILABLE=ICON_ROOT.."pvp_available"
local TEX_PVP_COMPLETE=ICON_ROOT.."pvp_complete"
local TEX_INCOMPLETE=ICON_ROOT.."incomplete"
local TEX_SLAY=ICON_ROOT.."slay"
local TEX_LOOT=ICON_ROOT.."loot"
local TEX_OBJECT=ICON_ROOT.."object"
local TEX_EVENT=ICON_ROOT.."event"
local TEX_INTERACT=ICON_ROOT.."interact"
local TEX_FLIGHT=ICON_ROOT.."flight"
local TEX_AUCTIONEER=ICON_ROOT.."auctioneer"
local TEX_BANKER=ICON_ROOT.."banker"
local TEX_MAILBOX=ICON_ROOT.."mailbox"
local TEX_BATTLEMASTER=ICON_ROOT.."battlemaster"
local TEX_INNKEEPER=ICON_ROOT.."innkeeper"
local TEX_MEETINGSTONE=ICON_ROOT.."meetingstone"
local TEX_REPAIR=ICON_ROOT.."repair"
local TEX_SPIRITHEALER=ICON_ROOT.."spirithealer"
local TEX_STABLEMASTER=ICON_ROOT.."stablemaster"
local TEX_VENDOR=ICON_ROOT.."vendor"
local TEX_RARE=ICON_ROOT.."rares"

local function TextureForNode(node)
  if node.role=="flightMaster" then return TEX_FLIGHT end
  if node.role=="auctioneer" then return TEX_AUCTIONEER end
  if node.role=="banker" then return TEX_BANKER end
  if node.role=="mailbox" then return TEX_MAILBOX end
  if node.role=="battlemaster" then return TEX_BATTLEMASTER end
  if node.role=="innkeeper" then return TEX_INNKEEPER end
  if node.role=="meetingStone" then return TEX_MEETINGSTONE end
  if node.role=="repair" then return TEX_REPAIR end
  if node.role=="spiritHealer" then return TEX_SPIRITHEALER end
  if node.role=="stableMaster" then return TEX_STABLEMASTER end
  if node.role=="vendor" then return TEX_VENDOR end
  if node.role=="rareMob" then return TEX_RARE end
  if node.role=="itemStart" then
    -- Presentation priority: PvP > Repeatable > Event > Normal.
    if node.pvp then return TEX_PVP_AVAILABLE end
    if node.repeatable then return TEX_REPEATABLE_AVAILABLE end
    if node.event then return TEX_EVENT_AVAILABLE end
    return TEX_AVAILABLE
  end
  if node.role=="available" then
    if node.pvp then return TEX_PVP_AVAILABLE end
    if node.repeatable then return TEX_REPEATABLE_AVAILABLE end
    if node.event then return TEX_EVENT_AVAILABLE end
    return TEX_AVAILABLE
  end
  if node.role=="turnin" then
    if node.pvp then return TEX_PVP_COMPLETE end
    -- Questie 6 uses its ordinary completion question mark for repeatable
    -- turn-ins. Repeatability therefore wins over event presentation here too.
    if node.repeatable then return TEX_COMPLETE end
    if node.event then return TEX_EVENT_COMPLETE end
    return TEX_COMPLETE
  end
  if node.role=="objectiveItemSource" then
    if node.sourceKind=="gameObject" then return TEX_OBJECT end
    return TEX_LOOT
  end
  if node.role=="objectiveObject" then return TEX_OBJECT end
  if node.role=="objectiveCreature" then return TEX_SLAY end
  return TEX_INCOMPLETE
end
local function RolePriority(role)
  if IsPermanentRole(role) then return role=="rareMob" and 6 or 5 end
  -- A quest that can be picked up should be visually dominant when the
  -- exact same source/area also participates in active objective/loot data.
  if role=="turnin" then return 50 end
  if role=="available" or role=="itemStart" then return 40 end
  -- At a shared Full Nodes coordinate, a direct objective should own the
  -- displayed quest color over an indirect item-drop source. The merged pin
  -- still retains every quest/objective entry for its tooltip.
  if role=="objectiveObject" or role=="objectiveCreature" then return 20 end
  if role=="objectiveItemSource" then return 15 end
  return 10
end

local function VariantPriority(node)
  if node and node.pvp then return 3 end
  if node and node.repeatable then return 2 end
  if node and node.event then return 1 end
  return 0
end

local function VisualPriority(node)
  return RolePriority(node.role)*10+VariantPriority(node)
end

local function ScaleKeyForRole(role)
  return nil
end

local function DrawSublevelForRole(role)
  if IsPermanentRole(role) then return role=="rareMob" and 2 or 1 end
  -- Questie 5.2.3/6.0.0/3.3.5 map utils:
  -- available = OVERLAY 5, complete = OVERLAY 6, objectives = OVERLAY 0.
  if role=="turnin" then return 6 end
  if role=="available" or role=="itemStart" then return 5 end
  return 0
end

local function ApplyVisualRole(pin,node)
  local priority=VisualPriority(node)
  if not pin.visualPriority or priority>pin.visualPriority then
    pin.visualPriority=priority
    pin.role=node.role
    pin.questID=node.questID
    pin.event=node.event
    pin.pvp=node.pvp and true or false
    pin.repeatable=node.repeatable and true or false
    pin.sourceKind=node.sourceKind
    pin.sourceID=node.sourceID
    pin.displayName=node.sourceName or pin.displayName or "Quest source"
    pin.iconScaleKey=node.iconScaleKey or ScaleKeyForRole(node.role)
    pin.texture:SetTexture(TextureForNode(node))
    pin.texture:SetDrawLayer("OVERLAY",DrawSublevelForRole(node.role))
    -- Miscellaneous/rare markers stay below quest pins so an overlapping
    -- quest objective, starter or turn-in remains visible and clickable.
    if pin.SetFrameLevel and WorldMapButton then
      if IsPermanentRole(node.role) then
        pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+7)
      else
        pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)
      end
    end
    if QuestieOcto.Visuals then QuestieOcto.Visuals:ApplyPin(pin,node,false,1) end
  end
end


function M:GetTextureForNode(node)
  return TextureForNode(node)
end

function M:GetRolePriority(role)
  return RolePriority(role)
end

function M:GetVisualPriority(node)
  return VisualPriority(node)
end

function M:GetDrawSublevelForRole(role)
  return DrawSublevelForRole(role)
end

function M:GetScaleKeyForRole(role)
  return ScaleKeyForRole(role)
end

function M:GetIconTypeScale(node)
  return 1
end

function M:GetPinScale(pin)
  -- Keep every townsfolk/service marker on the same compact footprint.
  -- Rare Monsters intentionally stay on their dedicated 12px footprint below.
  -- The player-facing global map/minimap scale remains unchanged.
  if pin and (pin.role=="auctioneer" or pin.role=="banker" or pin.role=="flightMaster" or
              pin.role=="mailbox" or pin.role=="battlemaster" or pin.role=="innkeeper" or
              pin.role=="meetingStone" or pin.role=="repair" or pin.role=="spiritHealer" or
              pin.role=="stableMaster" or pin.role=="vendor") then
    return 0.9
  end
  return 1
end

function M:ResizePin(pin)
  if not pin then return end
  local globalScale=tonumber(DisplaySettings():Get("globalScale")) or 1
  local typeScale=self:GetPinScale(pin)
  -- pfQuest renders tracking/rares.tga inside a 14px node with a 1px inset,
  -- leaving a 12px visible star.  Our texture fills the pin, so use 12px
  -- for the miscellaneous rare marker to match that less-intrusive footprint.
  local baseSize=pin.fullNode and 14 or ((pin.role=="rareMob") and 12 or 16)
  local size=baseSize*globalScale*typeScale
  pin:SetWidth(size)
  pin:SetHeight(size)
  if QuestieOcto.Visuals then QuestieOcto.Visuals:ResizeGlow(pin) end
  pin.questieOctoScaleSize=size
  self.stats.scaleResizes=(self.stats.scaleResizes or 0)+1
  self.stats.lastScaleSize=size
end


local function IsExactRole(role)
  return role=="available" or role=="turnin" or IsPermanentRole(role)
end

local function EntryKey(node)
  return tostring(node.questID)..":"..tostring(node.role)..":"..
    tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..tostring(node.itemID or 0)
end

local function AddEntry(pin,node)
  pin.entries=pin.entries or {}
  local key=EntryKey(node)
  if not pin.entries[key] then
    pin.entries[key]={node=node}
  end
  ApplyVisualRole(pin,node)
end

local function UpdatePosition(pin,x,y,offsetX,offsetY)
  offsetX=offsetX or 0
  offsetY=offsetY or 0

  if pin.x==x and pin.y==y and pin.offsetX==offsetX and pin.offsetY==offsetY then
    return
  end

  pin.x=x
  pin.y=y
  pin.offsetX=offsetX
  pin.offsetY=offsetY

  pin:ClearAllPoints()
  pin:SetPoint(
    "CENTER",WorldMapButton,"TOPLEFT",
    WorldMapButton:GetWidth()*(x/100)+offsetX,
    -WorldMapButton:GetHeight()*(y/100)+offsetY
  )
end

local function DisplayedMapID()
  -- Vanilla selected-zone map -> name -> canonical DB map ID.
  local cid=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  local zid=GetCurrentMapZone and GetCurrentMapZone() or 0
  if not cid or cid<=0 or not zid or zid<=0 then return nil end
  if not GetMapZones then return nil end

  local zones={GetMapZones(cid)}
  local name=zones[zid]
  if not name then return nil end

  -- Derive ID by looking at existing canonical node map indexes.
  -- Zone DB identity remains hidden behind generated node coordinates.
  if QuestieOcto.DatabaseAPI.GetMapIDByName then
    return QuestieOcto.DatabaseAPI:GetMapIDByName(name)
  end

  return nil
end

local function DisplayedContinentMapID()
  local cid=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  local zid=GetCurrentMapZone and GetCurrentMapZone() or 0
  if not cid or cid<=0 or (zid and zid>0) then return nil end
  if not QuestieOcto.ContinentProjection then return nil end
  return QuestieOcto.ContinentProjection:GetClientContinentMapID(cid)
end

local function DisplayedContextKey()
  local mapID=DisplayedMapID()
  if mapID then return tonumber(mapID) end
  local continentMapID=DisplayedContinentMapID()
  if continentMapID~=nil then return -1000-tonumber(continentMapID) end
  return nil
end

local function OpenContinentZoneForPin(pin)
  if not pin or not pin.continentZoneMapID or not SetMapZoom or not GetMapZones then return false end
  local continent=GetCurrentMapContinent and GetCurrentMapContinent() or 0
  if not continent or continent<=0 then return false end

  local target=tonumber(pin.continentZoneMapID)
  if not target then return false end
  local zones={GetMapZones(continent)}
  local index,name
  for index,name in ipairs(zones) do
    if QuestieOcto.DatabaseAPI:GetMapIDByName(name)==target then
      if QuestieOcto.Tooltips then QuestieOcto.Tooltips:Hide(pin) end
      SetMapZoom(continent,index)
      return true
    end
  end
  return false
end

local function AttachWorldMapPinInput(pin)
  if not pin then return end
  pin:EnableMouse(true)
  pin:RegisterForClicks("LeftButtonUp")
  pin:SetScript("OnEnter",function() QuestieOcto.Tooltips:Show(this) end)
  pin:SetScript("OnLeave",function() QuestieOcto.Tooltips:Hide(this) end)
  -- Continent-map markers should behave as zone-entry targets instead of
  -- swallowing the click that would otherwise select the zone underneath.
  pin:SetScript("OnClick",function() OpenContinentZoneForPin(this) end)
end

function M:GetOrCreate(key,node,x,y,clusterCount,generation,kind)
  if not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) then return nil end

  local pin=self.frames[key]

  if not pin then
    pin=CreateFrame("Button",nil,WorldMapButton)
    pin:SetWidth(16)
    pin:SetHeight(16)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)

    local tex=pin:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints(pin)
    pin.texture=tex

    AttachWorldMapPinInput(pin)

    self.frames[key]=pin
    self.stats.created=self.stats.created+1
  else
    self.stats.reused=self.stats.reused+1
  end

  pin.itemStartArea=nil
  if pin.seenGeneration~=generation then
    pin.seenGeneration=generation
    if self.buildActiveFrames then table.insert(self.buildActiveFrames,pin) end
  end

  if pin.entryGeneration~=generation then
    pin.entryGeneration=generation
    pin.entries={}
    pin.displayName=nil
    pin.clusterCount=1
    pin.visualPriority=nil
    pin.role=nil
    pin.event=nil
    pin.pvp=nil
    pin.repeatable=nil
    pin.fullNode=nil
    pin.fullNodeNode=nil
    pin.iconScaleKey=nil
    pin.sourceKind=node.sourceKind
    pin.continentZoneMapID=nil
    if QuestieOcto.Visuals then QuestieOcto.Visuals:ClearPin(pin,1) end
  end

  pin.clusterCount=math.max(pin.clusterCount or 1,clusterCount or 1)

  -- Place at canonical coordinates first. Final layout resolves overlap
  -- after the complete visible pin set is known.
  UpdatePosition(pin,x,y,0,0)
  AddEntry(pin,node)
  if kind=="objectiveFull" or kind=="itemStartFull" then
    local current=pin.fullNodeNode
    if not current or self:GetVisualPriority(node)>self:GetVisualPriority(current) then
      pin.fullNodeNode=node
    end
    if QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
      QuestieOcto.Visuals:ApplyFullNode(pin,pin.fullNodeNode,false,1)
    end
  end
  self:ResizePin(pin)

  if not pin:IsShown() then pin:Show() end

  if kind=="exact" then
    self.stats.exact=self.stats.exact+1
  elseif kind=="itemStart" then
    self.stats.itemStartAreas=self.stats.itemStartAreas+1
  else
    self.stats.objectiveAreas=self.stats.objectiveAreas+1
  end

  return pin
end

local function RefreshPinVisual(pin)
  local wasFull=pin.fullNode and true or false
  pin.visualPriority=nil
  pin.role=nil
  pin.questID=nil
  pin.sourceID=nil
  pin.iconScaleKey=nil
  pin.fullNode=nil

  local fullNode=nil
  for _,entry in pairs(pin.entries or {}) do
    if entry.node then
      ApplyVisualRole(pin,entry.node)
      if wasFull and (not fullNode or M:GetVisualPriority(entry.node)>M:GetVisualPriority(fullNode)) then
        fullNode=entry.node
      end
    end
  end
  pin.fullNodeNode=fullNode
  if fullNode and QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
    QuestieOcto.Visuals:ApplyFullNode(pin,fullNode,false,1)
  end
  M:ResizePin(pin)
end

function M:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return 0 end

  local removed=0

  for _,pin in pairs(self.activeFrames or {}) do
    local changed=false

    if pin.itemStartArea and tonumber(pin.itemStartArea.questID)==questID then
      pin.itemStartArea=nil
      pin.entries={}
      changed=true
    else
      for key,entry in pairs(pin.entries or {}) do
        if entry.node and tonumber(entry.node.questID)==questID then
          pin.entries[key]=nil
          removed=removed+1
          changed=true
        end
      end
    end

    if changed then
      if pin.itemStartArea or next(pin.entries or {}) then
        RefreshPinVisual(pin)
      else
        if pin:IsShown() then
          pin:Hide()
          self.stats.hidden=self.stats.hidden+1
        end
      end
    end
  end

  -- Questie 5.2.3/6.0.0 UnloadQuestFrames removes every frame belonging
  -- to the quest, including both world-map and minimap copies.
  if QuestieOcto.Minimap and QuestieOcto.Minimap.RemoveQuest then
    removed=removed+QuestieOcto.Minimap:RemoveQuest(questID)
  end

  return removed
end

function M:HideAll()
  for _,pin in pairs(self.activeFrames or {}) do
    if pin:IsShown() then
      pin:Hide()
      self.stats.hidden=self.stats.hidden+1
    end
  end
  self.activeFrames={}
  self.buildActiveFrames=nil
  self.stats.active=0
end

function M:GetDisplayedMapID()
  return DisplayedMapID()
end

function M:GetNearbyQuestTooltipPins(pin,maxPixels)
  local result={}
  if not pin or not pin:IsShown() then return result end

  maxPixels=tonumber(maxPixels) or 5
  local width=WorldMapButton and WorldMapButton:GetWidth() or 0
  local height=WorldMapButton and WorldMapButton:GetHeight() or 0
  if width<=0 or height<=0 then
    result[1]=pin
    return result
  end

  local px=(tonumber(pin.x) or 0)*width/100+(tonumber(pin.offsetX) or 0)
  local py=(tonumber(pin.y) or 0)*height/100+(tonumber(pin.offsetY) or 0)

  local _,other
  for _,other in pairs(self.activeFrames or {}) do
    if other and other:IsShown() and not IsPermanentRole(other.role) and (other.itemStartArea or next(other.entries or {})) then
      local ox=(tonumber(other.x) or 0)*width/100+(tonumber(other.offsetX) or 0)
      local oy=(tonumber(other.y) or 0)*height/100+(tonumber(other.offsetY) or 0)
      local dx=px-ox
      local dy=py-oy
      if dx*dx+dy*dy<=maxPixels*maxPixels then
        result[table.getn(result)+1]=other
      end
    end
  end

  if table.getn(result)==0 then result[1]=pin end

  table.sort(result,function(a,b)
    local ay=tonumber(a.y) or 0
    local by=tonumber(b.y) or 0
    if ay==by then return (tonumber(a.x) or 0)<(tonumber(b.x) or 0) end
    return ay<by
  end)

  return result
end

function M:SetMap(mapID)
  mapID=tonumber(mapID)
  if tonumber(self.mapID)==mapID then return end
  self.mapID=mapID
  self.generation=self.generation+1
  self.syncing=false
  self.resync=false
  self.prune=false
  self.renderedPreparedPlan=nil
  self.syncPreparedPlan=nil
  self:HideAll()
end

function M:RenderItemStartArea(area,generation,continentZoneMapID)
  if not IsRoleEnabled("itemStart") then return end
  local itemQuest=QuestieOcto.QuestModel:Get(area.questID)
  if itemQuest and itemQuest.pvp and not DisplaySettings():Get("showPvPRelatedQuests") then return end
  local itemEvent=itemQuest and itemQuest.eventID and QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:IsPresentationEvent(itemQuest.eventID) or false
  local itemPvP=itemQuest and itemQuest.pvp or false
  local itemRepeatable=itemQuest and itemQuest.repeatable or false

  local key="itemarea:"..tostring(area.key)
  local pin=self.frames[key]

  if not pin then
    pin=CreateFrame("Button",nil,WorldMapButton)
    pin:SetWidth(16)
    pin:SetHeight(16)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel()+8)

    local tex=pin:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints(pin)
    pin.texture=tex

    AttachWorldMapPinInput(pin)

    self.frames[key]=pin
    self.stats.created=self.stats.created+1
  else
    self.stats.reused=self.stats.reused+1
  end

  if pin.seenGeneration~=generation then
    pin.seenGeneration=generation
    if self.buildActiveFrames then table.insert(self.buildActiveFrames,pin) end
  end
  pin.itemStartArea=area
  pin.entries={}
  pin.continentZoneMapID=tonumber(continentZoneMapID)
  pin.visualPriority=40
  pin.role="itemStart"
  pin.questID=area.questID
  pin.event=itemEvent
  pin.pvp=itemPvP
  pin.repeatable=itemRepeatable
  pin.iconScaleKey=nil
  pin.sourceKind="area"
  pin.displayName=area.displayName
  pin.clusterCount=area.n
  pin.texture:SetTexture(TextureForNode({role="itemStart",event=pin.event,pvp=pin.pvp,repeatable=pin.repeatable}))
  pin.texture:SetDrawLayer("OVERLAY",5)
  if QuestieOcto.Visuals then
    QuestieOcto.Visuals:ApplyPin(pin,{role="itemStart",questID=area.questID,pvp=pin.pvp,repeatable=pin.repeatable},false,1)
  end
  self:ResizePin(pin)

  UpdatePosition(pin,area.x,area.y,0,0)

  if not pin:IsShown() then pin:Show() end
  self.stats.itemStartAreaPins=self.stats.itemStartAreaPins+1
  return pin
end

function M:RenderNode(node,generation)
  if not self.mapID then return end

  -- Clustered item-start sources are represented by geographic area pins.
  -- Full Nodes intentionally renders their raw spawn coordinates.
  if node.role=="itemStart" and DisplaySettings():Get("itemStartDensity")~="full" then return end

  local radius=QuestieOcto.Clustering.objectiveRadius
  local kind="objective"

  if node.role=="itemStart" then
    radius=QuestieOcto.Clustering.itemStartRadius
    kind="itemStart"
  end

  if IsExactRole(node.role) then
    local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,self.mapID)
    for _,p in pairs(points) do
      local key="exact:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
        string.format("%.2f",p.x)..":"..string.format("%.2f",p.y)
      self:GetOrCreate(key,node,p.x,p.y,1,generation,"exact")
    end
    return
  end

  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,self.mapID)
  local areas=QuestieOcto.Clustering:BuildAreas(points,radius)

  for _,area in pairs(areas) do
    local key="area:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..tostring(area.key)
    self:GetOrCreate(key,node,area.x,area.y,area.n,generation,kind)
  end
end

local function ResetVisibleOffsets(generation,frames)
  local groups={}

  for _,pin in pairs(frames or {}) do
    if pin:IsShown() and pin.seenGeneration==generation and pin.x and pin.y then
      local key=string.format("%.2f:%.2f",tonumber(pin.x) or 0,tonumber(pin.y) or 0)
      groups[key]=groups[key] or {}
      table.insert(groups[key],pin)
    end
  end

  local offsets={{0,0},{10,0},{-10,0},{0,10},{0,-10},{8,8},{-8,8},{8,-8},{-8,-8}}
  for _,group in pairs(groups) do
    table.sort(group,function(a,b)
      local ap=IsPermanentRole(a.role) and 1 or 0
      local bp=IsPermanentRole(b.role) and 1 or 0
      if ap~=bp then return ap<bp end
      if tostring(a.role)~=tostring(b.role) then return tostring(a.role)<tostring(b.role) end
      return tonumber(a.sourceID or 0)<tonumber(b.sourceID or 0)
    end)

    for index,pin in ipairs(group) do
      local off=offsets[math.mod(index-1,table.getn(offsets))+1]
      UpdatePosition(pin,pin.x,pin.y,off[1],off[2])
    end
  end
end

function M:Finish(generation,doPrune)
  if generation~=self.generation then return end

  local nextActive=self.buildActiveFrames or {}
  local seen={}
  for _,pin in pairs(nextActive) do seen[pin]=true end

  -- A completed sync is authoritative for the displayed map. Hide only frames
  -- from the previous active set that are no longer used; never scan the entire
  -- historical frame cache accumulated across zones.
  for _,pin in pairs(self.activeFrames or {}) do
    if not seen[pin] and pin:IsShown() then
      pin:Hide()
      self.stats.hidden=self.stats.hidden+1
    end
  end

  self.activeFrames=nextActive
  self.buildActiveFrames=nil
  ResetVisibleOffsets(generation,self.activeFrames)

  local active=0
  local visibleAvailable=0
  local visibleItemStart=0
  local visibleObjective=0
  local visibleTurnin=0
  local multiEntryPins=0

  for _,pin in pairs(self.activeFrames) do
    if pin:IsShown() then
      active=active+1
      if pin.role=="available" then visibleAvailable=visibleAvailable+1
      elseif pin.role=="itemStart" then visibleItemStart=visibleItemStart+1
      elseif pin.role=="turnin" then visibleTurnin=visibleTurnin+1
      else visibleObjective=visibleObjective+1 end

      local entries=0
      for _ in pairs(pin.entries or {}) do entries=entries+1 end
      if entries>1 then multiEntryPins=multiEntryPins+1 end
    end
  end

  self.stats.active=active
  self.stats.visibleAvailable=visibleAvailable
  self.stats.visibleItemStart=visibleItemStart
  self.stats.visibleObjective=visibleObjective
  self.stats.visibleTurnin=visibleTurnin
  self.stats.multiEntryPins=multiEntryPins
  self.stats.syncs=self.stats.syncs+1
  self.renderedPreparedPlan=self.syncPreparedPlan
  if self.syncNodeRevision~=nil then
    self.renderedNodeRevision=self.syncNodeRevision
  end
  self.syncPreparedPlan=nil
  self.syncNodeRevision=nil
  self.syncing=false

  if self.resync then
    local p=self.prune
    self.resync=false
    self.prune=false
    self:RequestSync(p)
  end
end

function M:RenderPreparedDescriptor(desc,generation,renderItemStarts)
  if desc.type=="itemStartArea" then
    if renderItemStarts then M:RenderItemStartArea(desc.area,generation) end
    return
  end

  if desc.type=="nodeSlot" then
    for _,entry in pairs(desc.entries or {}) do
      if entry.node and (renderItemStarts or entry.node.role~="itemStart") then
        M:GetOrCreate(
          desc.key,
          entry.node,
          desc.x,
          desc.y,
          entry.clusterCount or 1,
          generation,
          entry.kind or "objective"
        )
      end
    end
    return
  end

  -- Backward compatibility for a prepared map published by an older cache
  -- during an in-session update/reload boundary.
  if desc.type=="node" and desc.node
     and (renderItemStarts or desc.node.role~="itemStart") then
    M:GetOrCreate(desc.key,desc.node,desc.x,desc.y,desc.clusterCount or 1,generation,desc.kind or "objective")
  end
end

local function IsContinentQuestRole(role)
  return role=="available" or role=="turnin" or role=="itemStart"
end

local function ContinentPinKey(node,mapID,x,y)
  if IsContinentQuestRole(node.role) then
    return "continent:quest-source:"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
      tostring(mapID)..":"..string.format("%.2f",x)..":"..string.format("%.2f",y)
  end
  return "continent:"..tostring(node.role)..":"..tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
    tostring(mapID)..":"..string.format("%.2f",x)..":"..string.format("%.2f",y)
end

function M:RenderContinentNode(node,mapID,generation)
  if not node or not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) then return 0 end
  if node.role=="itemStart" and QuestieOcto.ItemStartAreas:IsZoneWideRareChance(node.chance) then return 0 end
  -- World Map Visibility toggles apply only to continent/world overviews.
  -- Selected zone and city maps keep normal/special quest markers visible and
  -- are controlled by Enable Available/Completed Quest Icons instead.
  if IsContinentQuestRole(node.role) and not IsQuestMarkerNodeEnabled(node) then return 0 end
  -- The continent overview intentionally shows only quest start/turn-in markers
  -- plus Flight Masters. Objective/slay/full-node/cluster data remains zone-only.
  if not IsContinentQuestRole(node.role) and node.role~="flightMaster" then return 0 end

  local projection=QuestieOcto.ContinentProjection
  if not projection then return 0 end
  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,mapID)
  if not points or table.getn(points)==0 then return 0 end

  local rendered=0
  if node.role=="itemStart" then
    -- Item-start sources can have dozens of spawn points. On a continent map
    -- they represent one available quest, so use a single centroid marker per
    -- source/zone instead of turning the continent into an objective-node map.
    local sx,sy,n=0,0,0
    for _,point in pairs(points) do
      local px,py=projection:Project(mapID,point.x,point.y)
      if px and py then sx=sx+px; sy=sy+py; n=n+1 end
    end
    if n>0 then
      local x,y=sx/n,sy/n
      local pin=self:GetOrCreate(ContinentPinKey(node,mapID,x,y),node,x,y,1,generation,"exact")
      if pin then pin.continentZoneMapID=mapID end
      return 1
    end
    return 0
  end

  for _,point in pairs(points) do
    local x,y=projection:Project(mapID,point.x,point.y)
    if x and y then
      local pin=self:GetOrCreate(ContinentPinKey(node,mapID,x,y),node,x,y,1,generation,"exact")
      if pin then pin.continentZoneMapID=mapID end
      rendered=rendered+1
    end
  end
  return rendered
end

local function AddContinentRareItemStart(groups,node,mapID)
  if not node or node.role~="itemStart" or not QuestieOcto.ItemStartAreas:IsZoneWideRareChance(node.chance) then return false end
  -- Consume ultra-rare nodes even when their world-map category is disabled so
  -- they do not fall back to the ordinary per-source continent renderer.
  if not IsRoleEnabled(node.role) or not IsPvPQuestNodeEnabled(node) or not IsQuestMarkerNodeEnabled(node) then return true end
  local projection=QuestieOcto.ContinentProjection
  if not projection then return false end
  local key=tostring(node.questID)..":"..tostring(node.itemID or 0)
  local group=groups[key]
  if not group then
    group={
      questID=node.questID,itemID=node.itemID,itemName=node.itemName,
      sx=0,sy=0,n=0,sources={}
    }
    groups[key]=group
  end

  local points=QuestieOcto.Clustering:PointsForNodeOnMap(node,mapID)
  for _,point in pairs(points or {}) do
    local x,y=projection:Project(mapID,point.x,point.y)
    if x and y then
      group.sx=group.sx+x
      group.sy=group.sy+y
      group.n=group.n+1
      local source=group.sources[node.sourceID]
      if not source then
        source={
          id=node.sourceID,name=node.sourceName,count=0,chance=node.chance,
          rank=node.sourceRank,respawnSeconds=node.respawnSeconds
        }
        group.sources[node.sourceID]=source
      end
      source.count=source.count+1
    end
  end
  return true
end

local function RenderContinentRareItemStarts(groups,mapID,generation)
  for _,group in pairs(groups or {}) do
    if group.n and group.n>0 then
      local sourceList={}
      for _,source in pairs(group.sources or {}) do table.insert(sourceList,source) end
      table.sort(sourceList,function(a,b)
        if a.count==b.count then return tostring(a.name)<tostring(b.name) end
        return a.count>b.count
      end)
      local first=sourceList[1]
      local area={
        x=group.sx/group.n,y=group.sy/group.n,n=group.n,
        questID=group.questID,itemID=group.itemID,itemName=group.itemName,
        sourceList=sourceList,zoneWideRare=true,
        rareThreshold=QuestieOcto.ItemStartAreas.zoneWideRareThreshold,
        displayName=first and first.name or "Rare item-start source",
        key="continent:"..tostring(mapID)..":"..tostring(group.questID)..":"..tostring(group.itemID or 0)..":zone-rare"
      }
      M:RenderItemStartArea(area,generation,mapID)
    end
  end
end

function M:StartContinentSync(continentMapID,doPrune)
  continentMapID=tonumber(continentMapID)
  if continentMapID==nil or not QuestieOcto.ContinentProjection then return end

  local contextKey=-1000-continentMapID
  if tonumber(self.mapID)~=contextKey then self:SetMap(contextKey) end
  if not QuestieOcto.Nodes.ready then self.syncing=false; return end

  self.generation=self.generation+1
  local generation=self.generation
  self.syncing=true
  self.syncPreparedPlan=nil
  self.syncNodeRevision=QuestieOcto.Nodes.stateRevision or 0
  self.buildActiveFrames={}
  self.stats.reused=0
  self.stats.exact=0
  self.stats.objectiveAreas=0
  self.stats.itemStartAreas=0
  self.stats.inputNodes=0

  local mapIDs=QuestieOcto.ContinentProjection:GetZoneMapIDs(continentMapID)
  local mapPos=1
  local nodePos=1
  local nodes=nil
  local rareGroups={}

  local function step()
    if generation~=M.generation then return end

    local budget=96
    while budget>0 and mapPos<=table.getn(mapIDs) do
      if not nodes then
        nodes=QuestieOcto.Nodes:GetMapNodes(mapIDs[mapPos]) or {}
        nodePos=1
        rareGroups={}
        M.stats.inputNodes=M.stats.inputNodes+table.getn(nodes)
      end

      if nodePos<=table.getn(nodes) then
        local node=nodes[nodePos]
        if not AddContinentRareItemStart(rareGroups,node,mapIDs[mapPos]) then
          M:RenderContinentNode(node,mapIDs[mapPos],generation)
        end
        nodePos=nodePos+1
        budget=budget-1
      else
        RenderContinentRareItemStarts(rareGroups,mapIDs[mapPos],generation)
        nodes=nil
        rareGroups={}
        mapPos=mapPos+1
      end
    end

    if mapPos<=table.getn(mapIDs) then
      QuestieOcto.Scheduler:Enqueue(step,"map-continent-render")
    else
      M:Finish(generation,doPrune)
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"map-continent-render")
end

function M:StartSync(doPrune)
  if not self.enabled or not WorldMapButton then return end

  -- Quest icon visibility is separate from townsfolk/service markers.
  -- Always build the map pass; IsRoleEnabled filters each semantic role.
  local mapID=DisplayedMapID()
  if not mapID then
    local continentMapID=DisplayedContinentMapID()
    if continentMapID~=nil then
      self:StartContinentSync(continentMapID,doPrune)
      return
    end
    self:SetMap(nil)
    return
  end

  if not QuestieOcto.PreparedMap:Get(mapID) then
    -- Any map the player actually opens becomes top priority immediately.
    -- This works even before the global Nodes build has completed.
    if QuestieOcto.ZoneBootstrap then
      QuestieOcto.ZoneBootstrap:Request(mapID,0.01)
      self.stats.mapPriorityRequests=(self.stats.mapPriorityRequests or 0)+1
    end

    if not QuestieOcto.Nodes.ready then
      return
    end
  end

  if tonumber(self.mapID)~=tonumber(mapID) then self:SetMap(mapID) end

  self.generation=self.generation+1
  local generation=self.generation
  self.syncing=true
  self.buildActiveFrames={}
  self.stats.reused=0
  self.stats.exact=0
  self.stats.objectiveAreas=0
  self.stats.itemStartAreas=0

  local nodes=QuestieOcto.Nodes:GetMapNodes(mapID)
  self.stats.inputNodes=table.getn(nodes)
  self.stats.itemStartRawNodes=0
  self.stats.itemStartAreaPins=0

  for _,node in pairs(nodes) do
    if node.role=="itemStart" then
      self.stats.itemStartRawNodes=self.stats.itemStartRawNodes+1
    end
  end

  local prepared=QuestieOcto.PreparedMap:Get(mapID)
  self.syncPreparedPlan=prepared

  if prepared then
    self.stats.preparedHits=self.stats.preparedHits+1
    self.stats.preparedDescriptors=table.getn(prepared)

    -- Prepared descriptors contain no DB discovery or clustering work.
    -- Typical zone maps can therefore appear in one rendering tick.
    local worldItemStarts=QuestieOcto.PreparedMap:GetWorldItemStarts(mapID) or {}
    local pos=1
    local itemPos=1
    local function preparedStep()
      if generation~=M.generation then return end

      local count=0
      while pos<=table.getn(prepared) and count<128 do
        M:RenderPreparedDescriptor(prepared[pos],generation,false)
        pos=pos+1
        count=count+1
      end
      while pos>table.getn(prepared) and itemPos<=table.getn(worldItemStarts) and count<128 do
        M:RenderPreparedDescriptor(worldItemStarts[itemPos],generation,true)
        itemPos=itemPos+1
        count=count+1
      end

      if pos<=table.getn(prepared) or itemPos<=table.getn(worldItemStarts) then
        QuestieOcto.Scheduler:Enqueue(preparedStep,"map-prepared-render")
      else
        M:Finish(generation,doPrune)
      end
    end

    QuestieOcto.Scheduler:Enqueue(preparedStep,"map-prepared-render")
    return
  end

  self.stats.preparedMisses=self.stats.preparedMisses+1

  -- First visit before background preparation reached this zone:
  -- prepare just this map, then render it on the next scheduler turn.
  QuestieOcto.Scheduler:Enqueue(function()
    if generation~=M.generation then return end

    QuestieOcto.PreparedMap:BuildMap(mapID)
    local ready=QuestieOcto.PreparedMap:Get(mapID)
    M.syncPreparedPlan=ready

    if not ready then
      M.syncing=false
      return
    end

    local worldItemStarts=QuestieOcto.PreparedMap:GetWorldItemStarts(mapID) or {}
    local pos=1
    local itemPos=1
    local function fallbackPreparedStep()
      if generation~=M.generation then return end

      local count=0
      while pos<=table.getn(ready) and count<128 do
        M:RenderPreparedDescriptor(ready[pos],generation,false)
        pos=pos+1
        count=count+1
      end
      while pos>table.getn(ready) and itemPos<=table.getn(worldItemStarts) and count<128 do
        M:RenderPreparedDescriptor(worldItemStarts[itemPos],generation,true)
        itemPos=itemPos+1
        count=count+1
      end

      if pos<=table.getn(ready) or itemPos<=table.getn(worldItemStarts) then
        QuestieOcto.Scheduler:Enqueue(fallbackPreparedStep,"map-first-prepare-render")
      else
        M:Finish(generation,doPrune)
      end
    end

    fallbackPreparedStep()
  end,"map-first-prepare")
end

function M:RefreshVisualSettings()
  for _,pin in pairs(self.activeFrames or {}) do
    if pin.itemStartArea then
      if QuestieOcto.Visuals then QuestieOcto.Visuals:ClearPin(pin,1) end
    elseif pin.entries and next(pin.entries) then
      pin.visualPriority=nil
      pin.role=nil
      pin.iconScaleKey=nil
      RefreshPinVisual(pin)
      if QuestieOcto.Visuals then QuestieOcto.Visuals:SetAlpha(pin,1) end
    end
  end

  if QuestieOcto.Minimap and QuestieOcto.Minimap.RefreshVisualSettings then
    QuestieOcto.Minimap:RefreshVisualSettings()
  end
end

function M:RescaleIcons(changedKey,changedValue)
  self.stats.rescalePasses=(self.stats.rescalePasses or 0)+1

  -- Scaling is presentation-only. Do not rebuild a pin's semantic visual here:
  -- doing so used to replace Full Nodes with the normal Questie objective
  -- texture until the next map sync. The global slider now changes size only.
  for _,pin in pairs(self.activeFrames or {}) do
    self:ResizePin(pin)
  end
end

function M:ApplySettings()
  self:RescaleIcons()
  self:RequestSync(true)
end

function M:OnSettingChanged(key,value)
  if key=="enableMapIcons" or key=="showAllQuestsWorldMap" or key=="showSpecialQuestsWorldMap" or key=="showPvPRelatedQuests" or key=="enableObjectives" or key=="enableTurnins" or
     key=="enableAvailable" or key=="showItemStartQuests" or key=="showItemStartMap" or
     key=="showMapAuctioneer" or key=="showMapBanker" or
     key=="showMapFlightMaster" or key=="showMapMailbox" or
     key=="showMapBattlemaster" or key=="showMapInnkeeper" or key=="showMapMeetingStone" or
     key=="showMapRepair" or key=="showMapSpiritHealer" or key=="showMapStableMaster" or key=="showMapVendor" or
     key=="showMapRareMonsters" then
    self:RequestSync(true)
  end
end

function M:RequestSync(doPrune)
  if self.syncing then
    self.resync=true
    if doPrune then self.prune=true end
    return
  end

  QuestieOcto.Scheduler:After(0.01,function()
    M:StartSync(doPrune and true or false)
  end,"map-sync")
end

function M:PatchContinentQuests(changedQuests)
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return false end
  local continentMapID=DisplayedContinentMapID()
  if continentMapID==nil or not QuestieOcto.ContinentProjection then return false end

  -- If a full continent render is already in flight, let it finish against the
  -- newest canonical Nodes snapshot rather than mutating its frame set midway.
  if self.syncing then
    self.resync=true
    self.prune=true
    return true
  end

  local changed={}
  for questID in pairs(changedQuests or {}) do
    questID=tonumber(questID)
    if questID and questID>0 then changed[questID]=true end
  end
  if not next(changed) then return true end

  local contextKey=-1000-tonumber(continentMapID)
  if tonumber(self.mapID)~=contextKey then return false end

  -- Remove only changed quest relationships from the currently visible pins,
  -- but do not hide them yet. A quest can disappear and reappear on the same
  -- physical source key during a filter change; deferring visibility decisions
  -- until after additions prevents an off/on frame flash.
  local touched={}
  for _,pin in pairs(self.activeFrames or {}) do
    if pin.itemStartArea and changed[tonumber(pin.itemStartArea.questID)] then
      pin.itemStartArea=nil
      touched[pin]=true
    end

    for key,entry in pairs(pin.entries or {}) do
      if entry and entry.node and changed[tonumber(entry.node.questID)] then
        pin.entries[key]=nil
        touched[pin]=true
      end
    end
  end

  -- A pin hidden by an earlier incremental filter patch can be reused later in
  -- this same continent generation. Reset only those empty hidden frames so a
  -- stale visual priority cannot prevent a newly visible quest from owning it.
  for _,pin in pairs(self.frames or {}) do
    if pin.seenGeneration==self.generation and not pin:IsShown()
       and not pin.itemStartArea and not next(pin.entries or {}) then
      pin.visualPriority=nil
      pin.role=nil
      pin.questID=nil
      pin.sourceID=nil
      pin.event=nil
      pin.pvp=nil
      pin.repeatable=nil
      pin.fullNode=nil
      pin.fullNodeNode=nil
      pin.iconScaleKey=nil
    end
  end

  -- Add only the new semantic state for the changed quests. Unrelated continent
  -- icons never get rebound, cleared or recreated when Low-Level Quest range
  -- changes, so they remain visually stable throughout the update.
  local mapIDs=QuestieOcto.ContinentProjection:GetZoneMapIDs(continentMapID)
  for _,mapID in ipairs(mapIDs or {}) do
    local rareGroups={}
    for _,node in pairs(QuestieOcto.Nodes:GetMapNodes(mapID) or {}) do
      if changed[tonumber(node.questID)] then
        if not AddContinentRareItemStart(rareGroups,node,mapID) then
          self:RenderContinentNode(node,mapID,self.generation)
        end
      end
    end
    RenderContinentRareItemStarts(rareGroups,mapID,self.generation)
  end

  -- Re-evaluate only pins that lost old relationships. AddEntry already handles
  -- newly added relationships, but a removed high-priority entry can otherwise
  -- leave its old visual owner cached on a shared coordinate.
  for pin in pairs(touched) do
    if pin.itemStartArea then
      -- RenderItemStartArea already refreshed this pin's complete visual state.
    elseif next(pin.entries or {}) then
      RefreshPinVisual(pin)
    else
      if pin:IsShown() then
        pin:Hide()
        self.stats.hidden=self.stats.hidden+1
      end
    end
  end

  -- Rebuild the small active-frame index from already-bound frames. Frames from
  -- older map contexts have a different generation and stay excluded.
  local active={}
  for _,pin in pairs(self.frames or {}) do
    if pin.seenGeneration==self.generation and (pin.itemStartArea or next(pin.entries or {})) then
      if not pin:IsShown() then pin:Show() end
      table.insert(active,pin)
    end
  end
  self.activeFrames=active
  ResetVisibleOffsets(self.generation,self.activeFrames)

  local visibleAvailable,visibleItemStart,visibleObjective,visibleTurnin=0,0,0,0
  for _,pin in pairs(self.activeFrames) do
    if pin.role=="available" then visibleAvailable=visibleAvailable+1
    elseif pin.role=="itemStart" then visibleItemStart=visibleItemStart+1
    elseif pin.role=="turnin" then visibleTurnin=visibleTurnin+1
    else visibleObjective=visibleObjective+1 end
  end
  self.stats.active=table.getn(self.activeFrames)
  self.stats.visibleAvailable=visibleAvailable
  self.stats.visibleItemStart=visibleItemStart
  self.stats.visibleObjective=visibleObjective
  self.stats.visibleTurnin=visibleTurnin
  self.stats.incrementalContinentPatches=(self.stats.incrementalContinentPatches or 0)+1
  self.renderedNodeRevision=QuestieOcto.Nodes.stateRevision or self.renderedNodeRevision
  return true
end

function M:EnsureDisplayedContextCurrent()
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end

  local contextKey=DisplayedContextKey()
  if tonumber(contextKey)~=tonumber(self.mapID) then
    self:SetMap(contextKey)
    self:RequestSync(false)
    return
  end

  local mapID=DisplayedMapID()
  if mapID then
    local prepared=QuestieOcto.PreparedMap:Get(mapID)
    -- PREPARED_MAP_READY can fire while the World Map is hidden. Comparing the
    -- actual published plan makes reopening the SAME zone self-healing even
    -- when WORLD_MAP_UPDATE does not change the map context. Do not queue a
    -- duplicate redraw if this exact plan is already the one being rendered.
    if prepared and prepared~=self.renderedPreparedPlan and prepared~=self.syncPreparedPlan then
      self:RequestSync(true)
    end
  elseif DisplayedContinentMapID()~=nil then
    -- NODES_CHANGED is intentionally ignored while the World Map is hidden.
    -- Remember the canonical Nodes revision rendered by the continent view so
    -- reopening the SAME continent after a quest completes self-heals just like
    -- selected zone maps already do through PreparedMap identity.
    local revision=QuestieOcto.Nodes and QuestieOcto.Nodes.stateRevision or 0
    if tonumber(self.renderedNodeRevision or 0)~=tonumber(revision) then
      self:RequestSync(true)
    end
  end
end

function M:OnNodesChanged(mapSet,changedQuests)
  if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end

  -- Zone maps consume PreparedMap's transactional replacement and refresh on
  -- PREPARED_MAP_READY. Continent maps do not use PreparedMap, so patch their
  -- changed quest relationships directly instead of starting a full re-render.
  if DisplayedMapID() then return end
  if DisplayedContinentMapID()~=nil then
    if not self:PatchContinentQuests(changedQuests) then self:RequestSync(true) end
  end
end

function M:OnNodesReady()
  -- Full node publications still drive continent maps directly. Selected zone
  -- maps must wait for PREPARED_MAP_READY; syncing here would consume the old
  -- prepared plan once and then the replacement plan moments later, producing
  -- an unnecessary visible rebind.
  if WorldMapFrame and WorldMapFrame:IsVisible()
     and not DisplayedMapID() and DisplayedContinentMapID()~=nil then
    self:RequestSync(true)
  end
end

QuestieOcto:RegisterMessage("NODES_CHANGED",M,"OnNodesChanged")
QuestieOcto:RegisterMessage("NODES_READY",M,"OnNodesReady")

function M:OnPreparedMapReady(mapID)
  if WorldMapFrame and WorldMapFrame:IsVisible()
     and tonumber(mapID)==tonumber(DisplayedMapID()) then
    self:RequestSync(true)
  end
end

QuestieOcto:RegisterMessage("PREPARED_MAP_READY",M,"OnPreparedMapReady")

local f=CreateFrame("Frame","QuestieOctoWorldMapEvents",UIParent)
f:RegisterEvent("WORLD_MAP_UPDATE")
f:SetScript("OnEvent",function()
  if event=="WORLD_MAP_UPDATE" then
    if WorldMapFrame and WorldMapFrame:IsVisible() then
      M:EnsureDisplayedContextCurrent()
    end
  end
end)

-- WORLD_MAP_UPDATE is not guaranteed to change context when the map is reopened
-- after a density change made while hidden. Revalidate the published prepared
-- plan on every show as a second, deterministic refresh boundary.
if WorldMapFrame and not M.worldMapShowHooked then
  M.worldMapShowHooked=true
  local function OnWorldMapShow()
    QuestieOcto.Scheduler:After(0.01,function()
      M:EnsureDisplayedContextCurrent()
    end,"map-show-density-sync")
  end

  -- HookScript is additive: UI replacements can keep their own OnShow handler
  -- without taking ownership away from Questie-Octo (and vice versa). Keep a
  -- forwarding SetScript fallback for older clients that do not expose it.
  if WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow",OnWorldMapShow)
  else
    local previousOnShow=WorldMapFrame:GetScript("OnShow")
    WorldMapFrame:SetScript("OnShow",function()
      if previousOnShow then previousOnShow() end
      OnWorldMapShow()
    end)
  end
end

