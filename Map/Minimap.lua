QuestieOcto.Minimap = QuestieOcto.Minimap or {}
local MM = QuestieOcto.Minimap

MM.enabled=true
MM.mapID=nil
MM.plan=nil
MM.planRevision=nil
MM.frames={}
MM.activeFrames={}
MM.bindRevision=1
MM.elapsed=0
MM.updateInterval=0.05
MM.globalScale=1
MM.stats={
  active=0,created=0,reused=0,hidden=0,
  refreshes=0,positionUpdates=0,mapChanges=0,
  mapContextRestores=0,lastMapContextReason="none",
  visibleAvailable=0,visibleItemStart=0,visibleObjective=0,visibleTurnin=0
}


local function Settings()
  return QuestieOcto.MinimapSettings
end

-- Lua 5.0 compatibility: RefreshVisualSettings/RescaleIcons are defined
-- before the implementations below, so forward-declare both locals explicitly.
local RefreshPinVisual
local ResizePin

local function IsPermanentRole(role)
  return role=="flightMaster" or role=="auctioneer" or role=="banker"
      or role=="mailbox" or role=="battlemaster" or role=="innkeeper"
      or role=="meetingStone" or role=="repair" or role=="spiritHealer"
      or role=="stableMaster" or role=="vendor" or role=="rareMob"
end

local function IsRoleEnabled(role)
  local settings=Settings()
  if role=="auctioneer" then return settings:Get("showMinimapAuctioneer") and true or false end
  if role=="banker" then return settings:Get("showMinimapBanker") and true or false end
  if role=="flightMaster" then return settings:Get("showMinimapFlightMaster") and true or false end
  if role=="mailbox" then return settings:Get("showMinimapMailbox") and true or false end
  if role=="battlemaster" then return settings:Get("showMinimapBattlemaster") and true or false end
  if role=="innkeeper" then return settings:Get("showMinimapInnkeeper") and true or false end
  if role=="meetingStone" then return settings:Get("showMinimapMeetingStone") and true or false end
  if role=="repair" then return settings:Get("showMinimapRepair") and true or false end
  if role=="spiritHealer" then return settings:Get("showMinimapSpiritHealer") and true or false end
  if role=="stableMaster" then return settings:Get("showMinimapStableMaster") and true or false end
  if role=="vendor" then return settings:Get("showMinimapVendor") and true or false end
  if role=="rareMob" then return settings:Get("showMinimapRareMonsters") and true or false end
  if not settings:Get("enableMiniMapIcons") then return false end

  if role=="itemStart" then
    return settings:Get("enableAvailable")
       and settings:Get("showItemStartQuests")
       and settings:Get("showItemStartMinimap")
       and true or false
  elseif role=="available" then
    return settings:Get("enableAvailable") and true or false
  elseif role=="turnin" then
    return settings:Get("enableTurnins") and true or false
  else
    return settings:Get("enableObjectives") and true or false
  end
end

local function SetTextureAlpha(pin,alpha)
  alpha=tonumber(alpha) or 1
  if alpha<0 then alpha=0 end
  if alpha>1 then alpha=1 end

  if pin.lastAlpha==alpha then return end
  pin.lastAlpha=alpha

  if QuestieOcto.Visuals then
    QuestieOcto.Visuals:SetAlpha(pin,alpha)
  elseif pin.texture and pin.texture.SetVertexColor then
    pin.texture:SetVertexColor(1,1,1,alpha)
  end
end

function MM:RefreshVisualSettings()
  -- Visible minimap frames are a small recyclable pool. Force a rebind on the
  -- next position pass instead of walking/rebuilding every coordinate in the
  -- zone just because a presentation option changed.
  self.bindRevision=(self.bindRevision or 0)+1
  self:UpdatePositions(true)
end

function MM:RescaleIcons(changedKey,changedValue)
  self.stats.rescalePasses=(self.stats.rescalePasses or 0)+1
  if changedKey=="globalMiniMapScale" and tonumber(changedValue) then
    self.globalScale=tonumber(changedValue)
  else
    self.globalScale=tonumber(Settings():Get("globalMiniMapScale")) or 1
  end

  for _,pin in pairs(self.activeFrames or {}) do ResizePin(pin) end
  self:UpdatePositions(true)
end

function MM:ApplySettings()
  local settings=Settings()
  self.enabled=true
  self.globalScale=tonumber(settings:Get("globalMiniMapScale")) or 1
  self.bindRevision=(self.bindRevision or 0)+1
  self:RefreshPlan()
end

function MM:OnSettingChanged(key,value)
  if key=="globalMiniMapScale" then
    self:RescaleIcons(key,value)
    return
  end

  self.bindRevision=(self.bindRevision or 0)+1
  if key=="enableMiniMapIcons" or key=="enableObjectives" or key=="enableTurnins" or
     key=="enableAvailable" or key=="showPvPRelatedQuests" or
     key=="showItemStartQuests" or key=="showItemStartMinimap" or
     key=="showMinimapAuctioneer" or key=="showMinimapBanker" or
     key=="showMinimapFlightMaster" or key=="showMinimapMailbox" or
     key=="showMinimapBattlemaster" or key=="showMinimapInnkeeper" or key=="showMinimapMeetingStone" or
     key=="showMinimapRepair" or key=="showMinimapSpiritHealer" or key=="showMinimapStableMaster" or key=="showMinimapVendor" or
     key=="showMinimapRareMonsters" then
    self:UpdatePositions(true)
    return
  end

  self:UpdatePositions(true)
end

-- pfQuest compatibility reference for Vanilla 1.12 minimap world span.
-- Questie 3.3.5/7/8 delegate this projection to HereBeDragons; Turtle does not
-- ship that library, so only the coordinate projection is adapted from pfQuest.
local MINIMAP_ZOOM={
  [0]={
    [0]=300,[1]=240,[2]=180,[3]=120,[4]=80,[5]=50
  },
  [1]={
    [0]=466.6666667,[1]=400,[2]=333.3333333,
    [3]=266.3333333,[4]=200,[5]=133.3333333
  }
}

local function RestoreCurrentZoneMapContext(reason)
  if not SetMapToCurrentZone then return end
  if WorldMapFrame and WorldMapFrame:IsShown() then return end

  SetMapToCurrentZone()
  MM.stats.mapContextRestores=(MM.stats.mapContextRestores or 0)+1
  MM.stats.lastMapContextReason=reason or "unknown"
end

local function CurrentMapID()
  -- The minimap must follow the player's PHYSICAL zone, never the zone being
  -- browsed in WorldMapFrame. On Vanilla/Turtle the global map context can
  -- leak into C_Map/GetPlayerMapPosition while the World Map is open, so use
  -- GetRealZoneText first just like pfQuest's minimap projection does.
  if GetRealZoneText and QuestieOcto.DatabaseAPI.GetMapIDByName then
    local zoneName=GetRealZoneText()
    local id=zoneName and QuestieOcto.DatabaseAPI:GetMapIDByName(zoneName)
    if id then
      MM.physicalMapID=tonumber(id)
      return MM.physicalMapID
    end
  end

  -- If the World Map is currently browsing somewhere else and the physical
  -- zone name could not be resolved, keep the last known physical map rather
  -- than adopting the browsed map context.
  if WorldMapFrame and WorldMapFrame:IsShown() and MM.physicalMapID then
    return MM.physicalMapID
  end

  local id=QuestieOcto.API:GetBestMapForPlayer()
  if id then
    MM.physicalMapID=tonumber(id)
    return MM.physicalMapID
  end

  return MM.physicalMapID
end

local function MinimapIndoor()
  if not Minimap or not Minimap.GetZoom or not Minimap.SetZoom then return 0 end
  if not GetCVar then return 0 end

  -- pfQuest Vanilla/Turtle compatibility, kept with the SAME state mapping.
  -- Important: pfQuest's state 0 selects the 300-yard table and state 1
  -- selects the 466.67-yard table. The previous Questie-Octo port inverted
  -- this result, causing minimap offsets to grow too quickly as the player
  -- moved away from a fixed quest target.
  local tempzoom=0
  local state=1

  if GetCVar("minimapZoom")==GetCVar("minimapInsideZoom") then
    if (tonumber(GetCVar("minimapInsideZoom")) or 0)>=3 then
      Minimap:SetZoom(Minimap:GetZoom()-1)
      tempzoom=1
    else
      Minimap:SetZoom(Minimap:GetZoom()+1)
      tempzoom=-1
    end
  end

  if (tonumber(GetCVar("minimapInsideZoom")) or -1)==Minimap:GetZoom() then
    state=0
  end

  Minimap:SetZoom(Minimap:GetZoom()+tempzoom)
  return state
end

local function MaskTextureSquareHint()
  -- Prefer the minimap's actual mask when the client/API exposes a getter.
  -- This keeps Questie-Octo independent from whichever UI addon supplied it.
  if not Minimap or type(Minimap.GetMaskTexture)~="function" then return nil end

  local ok,mask=pcall(Minimap.GetMaskTexture,Minimap)
  if not ok or type(mask)~="string" then return nil end

  local lower=string.lower(mask)
  lower=string.gsub(lower,"/","\\")

  -- WHITE8X8 is the common Vanilla square-mask technique (ShaguTweaks and
  -- DragonflightUI use it). Custom square masks commonly identify themselves
  -- as a minimap/square texture; pfUI ships its own minimap mask texture.
  if string.find(lower,"white8x8") then return true end
  if string.find(lower,"minimap") and string.find(lower,"square") then return true end
  if string.find(lower,"pfui") and string.find(lower,"minimap") then return true end

  -- Blizzard's stock circular minimap mask.
  if string.find(lower,"textures\\minimapmask") then return false end
  if string.find(lower,"interface\\minimap\\minimapmask") then return false end

  return nil
end

local function PfUISquareMinimap()
  -- pfUI reparents the active Minimap into pfUI.minimap and applies its own
  -- square mask. Checking the live parent avoids relying on a saved setting.
  if not pfUI or not pfUI.minimap or not Minimap or type(Minimap.GetParent)~="function" then
    return false
  end
  local ok,parent=pcall(Minimap.GetParent,Minimap)
  return ok and parent==pfUI.minimap and true or false
end

local function ShaguTweaksSquareMinimap()
  -- ShaguTweaks' MiniMap Square module creates this border only when the
  -- square-mask module is active. Its option requires a UI reload to change.
  return ShaguTweaks and Minimap and Minimap.border and true or false
end

local function DragonflightUISquareMinimap()
  -- DragonflightUI can switch its map mask from round to square at runtime.
  if not DFRL or type(DFRL.GetTempDB)~="function" then return false end
  local okEnabled,enabled=pcall(DFRL.GetTempDB,DFRL,"Map","enabled")
  if not okEnabled or not enabled then return false end
  local okSquare,square=pcall(DFRL.GetTempDB,DFRL,"Map","mapSquare")
  return okSquare and square and true or false
end

local function UsesSquareMinimap()
  local maskHint=MaskTextureSquareHint()
  if maskHint~=nil then return maskHint end

  -- Vanilla/Turtle clients may not expose GetMaskTexture(). Fall back to
  -- concrete live-state signals from UIs known to replace the minimap mask.
  if PfUISquareMinimap() then return true end
  if ShaguTweaksSquareMinimap() then return true end
  if DragonflightUISquareMinimap() then return true end

  return false
end

local function WorldMapBrowsingAwayFromPlayer(mapID)
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return false end
  if not QuestieOcto.Map or not QuestieOcto.Map.GetDisplayedMapID then return true end

  local displayed=QuestieOcto.Map:GetDisplayedMapID()
  -- Continent/world views have no zone map ID and therefore cannot provide
  -- physical-zone player coordinates through Vanilla's global map context.
  if not displayed then return true end
  return tonumber(displayed)~=tonumber(mapID)
end

local function PlayerPosition()
  -- Questie owns minimap refresh timing/state. Never retarget the World Map
  -- every 0.05s just to obtain player coordinates: that would fight the user
  -- while they browse. Instead, keep the last physical-zone position while the
  -- World Map is displaying another zone/continent, then resume live reads as
  -- soon as the physical map context is available again.
  if not GetPlayerMapPosition then return nil,nil end

  local physicalMapID=CurrentMapID()
  if WorldMapBrowsingAwayFromPlayer(physicalMapID) then
    return MM.physicalPlayerX,MM.physicalPlayerY
  end

  local x,y=GetPlayerMapPosition("player")
  x=tonumber(x)
  y=tonumber(y)

  if not x or not y or (x==0 and y==0) then
    if WorldMapFrame and WorldMapFrame:IsShown() then
      return MM.physicalPlayerX,MM.physicalPlayerY
    end
    return nil,nil
  end

  MM.physicalPlayerX=x*100
  MM.physicalPlayerY=y*100
  return MM.physicalPlayerX,MM.physicalPlayerY
end

local function EntryKey(node)
  return tostring(node.questID)..":"..tostring(node.role)..":"..
    tostring(node.sourceKind)..":"..tostring(node.sourceID)..":"..
    tostring(node.itemID or 0)
end

local function ResetPin(pin)
  pin.itemStartArea=nil
  pin.entries={}
  pin.visualPriority=nil
  pin.role=nil
  pin.questID=nil
  pin.event=nil
  pin.pvp=nil
  pin.repeatable=nil
  pin.fullNode=nil
  pin.fullNodeNode=nil
  pin.sourceID=nil
  pin.iconScaleKey=nil
  pin.sourceKind=nil
  pin.displayName=nil
  pin.clusterCount=1
  pin.mapX=nil
  pin.mapY=nil
  pin.coordKey=nil
  pin.lastAlpha=nil
  if QuestieOcto.Visuals then QuestieOcto.Visuals:ClearPin(pin,1) end
  SetTextureAlpha(pin,1)
end

local function ApplyVisual(pin,node)
  local priority=QuestieOcto.Map:GetVisualPriority(node)

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
    pin.iconScaleKey=node.iconScaleKey or QuestieOcto.Map:GetScaleKeyForRole(node.role)
    pin.texture:SetTexture(QuestieOcto.Map:GetTextureForNode(node))
    pin.texture:SetDrawLayer("OVERLAY",QuestieOcto.Map:GetDrawSublevelForRole(node.role))
    -- Keep townsfolk/rare markers below quest pins at identical coordinates.
    if pin.SetFrameLevel and Minimap then
      if IsPermanentRole(node.role) then
        pin:SetFrameLevel(Minimap:GetFrameLevel()+6)
      else
        pin:SetFrameLevel(Minimap:GetFrameLevel()+7)
      end
    end
    if QuestieOcto.Visuals then
      QuestieOcto.Visuals:ApplyPin(pin,node,true,pin.lastAlpha or 1)
    end
  end
end



ResizePin=function(pin)
  if not pin then return end

  local typeScale=QuestieOcto.Map:GetPinScale(pin)
  -- Keep miscellaneous rare stars proportionally smaller on the minimap too.
  -- This mirrors pfQuest's 12px visible rare icon footprint.
  local baseSize=pin.fullNode and 14 or ((pin.role=="rareMob") and 12 or 16)
  local size=baseSize*(MM.globalScale or 1)*typeScale
  pin:SetWidth(size)
  pin:SetHeight(size)
  if QuestieOcto.Visuals then QuestieOcto.Visuals:ResizeGlow(pin) end
  pin.questieOctoScaleSize=size
  MM.stats.scaleResizes=(MM.stats.scaleResizes or 0)+1
  MM.stats.lastScaleSize=size
end

local function AddEntry(pin,node)
  local key=EntryKey(node)
  if not pin.entries[key] then pin.entries[key]={node=node} end
  ApplyVisual(pin,node)
  ResizePin(pin)
end

function MM:GetOrCreate(index)
  index=tonumber(index)
  if not index then return nil end

  local pin=self.frames[index]
  if not pin then
    pin=CreateFrame("Button",nil,Minimap)
    pin:SetWidth(16)
    pin:SetHeight(16)
    pin:SetFrameStrata(Minimap:GetFrameStrata())
    pin:SetFrameLevel(Minimap:GetFrameLevel()+7)
    pin:EnableMouse(true)

    local tex=pin:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints(pin)
    pin.texture=tex

    pin:SetScript("OnEnter",function() QuestieOcto.Tooltips:Show(this) end)
    pin:SetScript("OnLeave",function() QuestieOcto.Tooltips:Hide(this) end)

    self.frames[index]=pin
    self.stats.created=self.stats.created+1
  else
    self.stats.reused=self.stats.reused+1
  end

  return pin
end

RefreshPinVisual=function(pin)
  local wasFull=pin.fullNode and true or false
  pin.visualPriority=nil
  pin.role=nil
  pin.questID=nil
  pin.event=nil
  pin.pvp=nil
  pin.repeatable=nil
  pin.fullNode=nil
  pin.fullNodeNode=nil
  pin.sourceID=nil
  pin.iconScaleKey=nil

  local fullNode=nil
  for _,entry in pairs(pin.entries or {}) do
    if entry.node then
      ApplyVisual(pin,entry.node)
      if wasFull and (not fullNode or QuestieOcto.Map:GetVisualPriority(entry.node)>QuestieOcto.Map:GetVisualPriority(fullNode)) then
        fullNode=entry.node
      end
    end
  end
  if fullNode and QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
    QuestieOcto.Visuals:ApplyFullNode(pin,fullNode,true,pin.lastAlpha or 1)
  end
  ResizePin(pin)
end

local function PvPNodeVisible(node)
  if not node or not node.pvp then return true end
  return Settings():Get("showPvPRelatedQuests") and true or false
end

local function ItemAreaVisible(area)
  if not area or not IsRoleEnabled("itemStart") then return false end
  local q=QuestieOcto.QuestModel:Get(area.questID)
  if q and q.pvp and not Settings():Get("showPvPRelatedQuests") then return false end
  return true
end

local function DescriptorCoordinates(desc)
  if not desc then return nil,nil end
  if desc.type=="itemStartArea" and desc.area then
    return tonumber(desc.area.x),tonumber(desc.area.y)
  end
  if desc.type=="nodeSlot" then return tonumber(desc.x),tonumber(desc.y) end
  if desc.type=="node" then return tonumber(desc.x),tonumber(desc.y) end
  return nil,nil
end

local function DescriptorHasVisibleEntry(desc,revision)
  if not desc then return false end
  if desc.minimapVisibilityRevision==revision then return desc.minimapVisible and true or false end

  local visible=false
  if desc.type=="itemStartArea" then
    visible=ItemAreaVisible(desc.area)
  elseif desc.type=="nodeSlot" then
    for _,entry in pairs(desc.entries or {}) do
      local node=entry.node
      if node and IsRoleEnabled(node.role) and PvPNodeVisible(node) then visible=true; break end
    end
  elseif desc.type=="node" and desc.node then
    visible=IsRoleEnabled(desc.node.role) and PvPNodeVisible(desc.node)
  end

  desc.minimapVisibilityRevision=revision
  desc.minimapVisible=visible and true or false
  return visible
end

local function BindDescriptor(pin,desc,revision)
  ResetPin(pin)
  pin.boundDescriptor=desc
  pin.boundRevision=revision

  if desc.type=="itemStartArea" and desc.area then
    if not ItemAreaVisible(desc.area) then return false end
    local area=desc.area
    pin.itemStartArea=area
    pin.displayName=area.displayName
    pin.clusterCount=area.n or 1
    pin.mapX=tonumber(area.x)
    pin.mapY=tonumber(area.y)
    pin.coordKey=string.format("%.2f:%.2f",pin.mapX or 0,pin.mapY or 0)
    pin.role="itemStart"
    pin.questID=area.questID
    local q=QuestieOcto.QuestModel:Get(area.questID)
    pin.event=q and q.eventID and QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:IsPresentationEvent(q.eventID) or false
    pin.pvp=q and q.pvp or false
    pin.repeatable=q and q.repeatable or false
    pin.visualPriority=40
    pin.texture:SetTexture(QuestieOcto.Map:GetTextureForNode({role="itemStart",event=pin.event,pvp=pin.pvp,repeatable=pin.repeatable}))
    pin.texture:SetDrawLayer("OVERLAY",5)
    if QuestieOcto.Visuals then
      QuestieOcto.Visuals:ApplyPin(pin,{role="itemStart",questID=area.questID,pvp=pin.pvp,repeatable=pin.repeatable},true,pin.lastAlpha or 1)
    end
    ResizePin(pin)
    return true
  end

  local x,y=DescriptorCoordinates(desc)
  pin.mapX=x
  pin.mapY=y
  pin.coordKey=desc.coordKey or (x and y and string.format("%.2f:%.2f",x,y)) or nil

  local visible=false
  local entries=desc.entries
  if desc.type=="node" and desc.node then
    entries={{node=desc.node,clusterCount=desc.clusterCount or 1,kind=desc.kind}}
  end

  local fullNode=nil
  for _,entry in pairs(entries or {}) do
    local node=entry.node
    if node and IsRoleEnabled(node.role) and PvPNodeVisible(node) then
      visible=true
      pin.clusterCount=math.max(pin.clusterCount or 1,entry.clusterCount or 1)
      AddEntry(pin,node)
      if entry.kind=="objectiveFull" or entry.kind=="itemStartFull" then
        if not fullNode or QuestieOcto.Map:GetVisualPriority(node)>QuestieOcto.Map:GetVisualPriority(fullNode) then
          fullNode=node
        end
      end
    end
  end

  if not visible then return false end

  if fullNode and QuestieOcto.Visuals and QuestieOcto.Visuals.ApplyFullNode then
    QuestieOcto.Visuals:ApplyFullNode(pin,fullNode,true,pin.lastAlpha or 1)
    pin.fullNodeNode=fullNode
    ResizePin(pin)
  end

  return true
end

function MM:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return 0 end

  local removed=0
  for _,pin in pairs(self.activeFrames or {}) do
    local changed=false
    if pin.itemStartArea and tonumber(pin.itemStartArea.questID)==questID then
      pin.itemStartArea=nil
      pin.entries={}
      changed=true
      removed=removed+1
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
      -- PreparedMap.RemoveQuest mutates the shared prepared descriptor before
      -- this immediate visual removal, so keep the binding but refresh content.
      if pin.itemStartArea or next(pin.entries or {}) then
        RefreshPinVisual(pin)
      else
        if pin:IsShown() then pin:Hide(); self.stats.hidden=self.stats.hidden+1 end
      end
    end
  end
  return removed
end

function MM:HideAll()
  for _,pin in pairs(self.activeFrames or {}) do
    if pin:IsShown() then pin:Hide(); self.stats.hidden=self.stats.hidden+1 end
  end
  self.activeFrames={}
  self.stats.active=0
end

function MM:RefreshPlan()
  local mapID=CurrentMapID()
  if not mapID then
    self.mapID=nil
    self.plan=nil
    self.planRevision=nil
    self:HideAll()
    return
  end

  if tonumber(self.mapID)~=mapID then
    self.mapID=mapID
    self.stats.mapChanges=self.stats.mapChanges+1
    self.lastPlayerX=nil
    self.lastPlayerY=nil
    self.lastZoom=nil
  end

  local plan=QuestieOcto.PreparedMap:Get(mapID)
  if not plan then
    self.plan=nil
    self.planRevision=nil
    self:HideAll()
    if QuestieOcto.ZoneBootstrap then QuestieOcto.ZoneBootstrap:Request(mapID,0.01) end
    return
  end

  self.plan=plan
  self.planRevision=QuestieOcto.PreparedMap.stateRevision
  self.stats.refreshes=self.stats.refreshes+1
  self:UpdatePositions(true)
end

local function ResetVisibleStats()
  MM.stats.visibleAvailable=0
  MM.stats.visibleItemStart=0
  MM.stats.visibleObjective=0
  MM.stats.visibleTurnin=0
end

local function CountVisible(pin)
  if pin.role=="itemStart" then
    MM.stats.visibleItemStart=MM.stats.visibleItemStart+1
  elseif pin.role=="available" then
    MM.stats.visibleAvailable=MM.stats.visibleAvailable+1
  elseif pin.role=="turnin" then
    MM.stats.visibleTurnin=MM.stats.visibleTurnin+1
  else
    MM.stats.visibleObjective=MM.stats.visibleObjective+1
  end
end

function MM:UpdatePositions(force)
  if not self.enabled or not Minimap or not self.plan or not self.mapID then
    self:HideAll()
    return
  end

  local current=CurrentMapID()
  if tonumber(current)~=tonumber(self.mapID) then self:RefreshPlan(); return end
  if self.planRevision~=QuestieOcto.PreparedMap.stateRevision then self:RefreshPlan(); return end
  local published=QuestieOcto.PreparedMap:Get(self.mapID)
  if published and published~=self.plan then self:RefreshPlan(); return end

  local px,py=PlayerPosition()
  if not px or not py then self:HideAll(); return end

  local mapWidth,mapHeight=QuestieOcto.DatabaseAPI:GetMinimapSize(self.mapID)
  if not mapWidth or not mapHeight or mapWidth<=0 or mapHeight<=0 then self:HideAll(); return end

  local zoom=Minimap.GetZoom and Minimap:GetZoom() or 0
  local squareMinimap=UsesSquareMinimap()
  local now=GetTime and GetTime() or 0
  if not force and self.lastPlayerX==px and self.lastPlayerY==py and self.lastZoom==zoom
     and self.lastSquareMinimap==squareMinimap
     and self.nextStaticRefresh and now<self.nextStaticRefresh then
    return
  end
  self.lastPlayerX=px
  self.lastPlayerY=py
  self.lastZoom=zoom
  self.lastSquareMinimap=squareMinimap
  self.nextStaticRefresh=now+1

  local indoor=MinimapIndoor()
  local mapZoom=MINIMAP_ZOOM[indoor] and MINIMAP_ZOOM[indoor][zoom]
  if not mapZoom or mapZoom<=0 then self:HideAll(); return end

  local width=Minimap:GetWidth()
  local height=Minimap:GetHeight()
  if not width or width<=0 or not height or height<=0 then return end

  local xScale=mapZoom/mapWidth
  local yScale=mapZoom/mapHeight
  local xDraw=width/xScale/100
  local yDraw=height/yScale/100
  local radius=math.min(width,height)/2
  local radiusSquared=radius*radius

  ResetVisibleStats()
  local visibleGroups={}
  local activeFrames={}
  local frameIndex=0
  local revision=self.bindRevision or 1

  -- pfQuest architecture: scan coordinate data, but allocate/reuse UI Buttons
  -- only for coordinates that are actually inside the current minimap circle.
  -- There is intentionally no hard node cap here.
  for _,desc in ipairs(self.plan or {}) do
    if DescriptorHasVisibleEntry(desc,revision) then
      local x,y=DescriptorCoordinates(desc)
      if x and y then
        local xPos=(x-px)*xDraw
        local yPos=(y-py)*yDraw
        local inside=false
        if squareMinimap then
          inside=math.abs(xPos)<(width/2) and math.abs(yPos)<(height/2)
        else
          inside=xPos*xPos+yPos*yPos<radiusSquared
        end
        if inside then
          frameIndex=frameIndex+1
          local pin=self:GetOrCreate(frameIndex)
          local bound=(pin.boundDescriptor==desc and pin.boundRevision==revision)
          if not bound then bound=BindDescriptor(pin,desc,revision) end

          if bound then
            pin.questieOctoBaseX=xPos
            pin.questieOctoBaseY=-yPos
            local groupKey=pin.coordKey or tostring(x)..":"..tostring(y)
            visibleGroups[groupKey]=visibleGroups[groupKey] or {}
            table.insert(visibleGroups[groupKey],pin)
            table.insert(activeFrames,pin)
            if not pin:IsShown() then pin:Show() end
            CountVisible(pin)
          else
            frameIndex=frameIndex-1
          end
        end
      end
    end
  end

  local offsets={{0,0},{10,0},{-10,0},{0,10},{0,-10},{8,8},{-8,8},{8,-8},{-8,-8}}
  for _,group in pairs(visibleGroups) do
    table.sort(group,function(a,b)
      local ap=IsPermanentRole(a.role) and 1 or 0
      local bp=IsPermanentRole(b.role) and 1 or 0
      if ap~=bp then return ap<bp end
      if tostring(a.role)~=tostring(b.role) then return tostring(a.role)<tostring(b.role) end
      return tonumber(a.sourceID or 0)<tonumber(b.sourceID or 0)
    end)
    for index,pin in ipairs(group) do
      local off=offsets[math.mod(index-1,table.getn(offsets))+1]
      local targetX=(pin.questieOctoBaseX or 0)+off[1]
      local targetY=(pin.questieOctoBaseY or 0)+off[2]
      -- Like pfQuest's world-map path, avoid ClearAllPoints/SetPoint if the
      -- recyclable frame is already at the requested screen coordinate.
      if pin.lastDrawX~=targetX or pin.lastDrawY~=targetY then
        pin.lastDrawX=targetX
        pin.lastDrawY=targetY
        pin:ClearAllPoints()
        pin:SetPoint("CENTER",Minimap,"CENTER",targetX,targetY)
      end
    end
  end

  for i=frameIndex+1,table.getn(self.frames) do
    local pin=self.frames[i]
    if pin and pin:IsShown() then pin:Hide(); self.stats.hidden=self.stats.hidden+1 end
  end

  self.activeFrames=activeFrames
  self.stats.active=frameIndex
  self.stats.positionUpdates=self.stats.positionUpdates+1
  self.stats.scannedDescriptors=table.getn(self.plan or {})
  self.stats.poolSize=table.getn(self.frames or {})
end

function MM:OnUpdate(elapsed)
  self.elapsed=self.elapsed+(tonumber(elapsed) or 0)
  if self.elapsed<self.updateInterval then return end
  self.elapsed=0

  local current=CurrentMapID()
  if tonumber(current)~=tonumber(self.mapID) then
    self:RefreshPlan()
    return
  end

  self:UpdatePositions(false)
end

function MM:OnPreparedMapReady(mapID)
  if tonumber(mapID)==tonumber(CurrentMapID()) then
    self:RefreshPlan()
  end
end

function MM:OnNodesReady()
  local current=CurrentMapID()
  if current and QuestieOcto.ZoneBootstrap then
    QuestieOcto.ZoneBootstrap:Request(current,0.01)
  end
end

function MM:Start()
  if self.frame then return end

  self.enabled=true
  self.globalScale=tonumber(Settings():Get("globalMiniMapScale")) or 1

  local f=CreateFrame("Frame","QuestieOctoMinimapUpdater",Minimap)
  self.frame=f

  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("ZONE_CHANGED")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("MINIMAP_ZONE_CHANGED")

  f:SetScript("OnEvent",function()
    local eventName=event
    QuestieOcto.Scheduler:After(0.01,function()
      RestoreCurrentZoneMapContext(eventName)
      MM:RefreshPlan()
    end,"minimap-zone-refresh")
  end)

  f:SetScript("OnUpdate",function()
    MM:OnUpdate(arg1)
  end)

  if WorldMapFrame and not self.worldMapHideHooked then
    self.worldMapHideHooked=true
    local function OnWorldMapHide()
      QuestieOcto.Scheduler:After(0.01,function()
        RestoreCurrentZoneMapContext("WORLD_MAP_HIDE")
        MM:RefreshPlan()
      end,"minimap-worldmap-close")
    end

    -- Use an additive script hook when available so map UI addons can install
    -- or replace their own OnHide behavior without erasing the minimap refresh.
    if WorldMapFrame.HookScript then
      WorldMapFrame:HookScript("OnHide",OnWorldMapHide)
    else
      local previousOnHide=WorldMapFrame:GetScript("OnHide")
      WorldMapFrame:SetScript("OnHide",function()
        if previousOnHide then previousOnHide() end
        OnWorldMapHide()
      end)
    end
  end

  QuestieOcto.Scheduler:After(0.01,function()
    RestoreCurrentZoneMapContext("START")
    MM:RefreshPlan()
  end,"minimap-start")
end

QuestieOcto:RegisterMessage("PREPARED_MAP_READY",MM,"OnPreparedMapReady")
QuestieOcto:RegisterMessage("NODES_READY",MM,"OnNodesReady")

MM:Start()
