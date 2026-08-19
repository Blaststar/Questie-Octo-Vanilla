-- Native Quest Log presentation enhancements for Vanilla/Turtle 1.12.
--
-- Backport trace:
--   Questie 5.2.3/6.0.0: quest-log title click interception for tracking.
--   Questie 3.3.5: primary compatibility semantics for quest-log/tracker state.
--   Questie 7/8: keep quest-log refresh authoritative after interactions.
--
-- Those Questie versions do not contain a transferable Vanilla visual restyle.
-- For the missing presentation mechanic only, Vanilla UI compatibility
-- references confirm the safe approach: post-process the existing Blizzard
-- QuestLogTitle1..N rows after their native update instead of skinning/replacing
-- the Quest Log. This preserves Blizzard UI, ShaguTweaks and pfUI appearance.

QuestieOcto.QuestLogEnhancements = QuestieOcto.QuestLogEnhancements or {}
local Q=QuestieOcto.QuestLogEnhancements

Q.started=false
Q.hooked=false
Q.originalUpdate=nil
Q.eventFrame=nil
Q.lastOffset=nil
Q.refreshPending=false
Q.nativeQuestColors=Q.nativeQuestColors or {}
Q.showMapButton=Q.showMapButton or nil

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function GetTitleButton(i)
  if getglobal then return getglobal("QuestLogTitle"..tostring(i)) end
  if _G then return _G["QuestLogTitle"..tostring(i)] end
  return nil
end

local function GetButtonFontString(button)
  if not button then return nil end
  if button.GetFontString then
    local ok,fs=pcall(button.GetFontString,button)
    if ok and fs then return fs end
  end
  if button.GetName then
    local name=button:GetName()
    if name and getglobal then
      return getglobal(name.."NormalText") or getglobal(name.."Text")
    end
  end
  return nil
end


local function CacheNativeQuestColor(button,index)
  if not button or not index or index<1 then return end
  local r,g,b
  -- Vanilla QuestLog_Update stores its chosen color directly on the title
  -- button (button.r/g/b). Prefer that over the FontString so UI skins cannot
  -- accidentally become the gameplay color source.
  if tonumber(button.r) and tonumber(button.g) and tonumber(button.b) then
    r,g,b=tonumber(button.r),tonumber(button.g),tonumber(button.b)
  else
    local fs=GetButtonFontString(button)
    if fs and fs.GetTextColor then
      local ok,fr,fg,fb=pcall(fs.GetTextColor,fs)
      if ok then r,g,b=tonumber(fr),tonumber(fg),tonumber(fb) end
    end
  end
  if not r then return end
  local questID
  if QuestieOcto.API and QuestieOcto.API.GetQuestIDForLogIndex then
    questID=QuestieOcto.API:GetQuestIDForLogIndex(index)
  end
  if questID and tonumber(questID) and tonumber(questID)>0 then
    Q.nativeQuestColors[tonumber(questID)]={r=r,g=g,b=b}
  end
end

function Q:GetCachedQuestColor(questID)
  local c=self.nativeQuestColors and self.nativeQuestColors[tonumber(questID)]
  if not c then return nil,nil,nil end
  return c.r,c.g,c.b
end

local function ApplyHeaderFont(button)
  local fs=GetButtonFontString(button)
  if not fs or not fs.SetFont or not fs.GetFont then return end

  local currentFont,currentSize,currentFlags=fs:GetFont()
  currentFont=currentFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  currentSize=tonumber(currentSize) or 12
  currentFlags=currentFlags or ""

  -- Questie-Octo does not own the skin. Capture whatever Blizzard/pfUI/
  -- ShaguTweaks supplied, then change only the size by +1. If another UI
  -- addon restyles the row later, adopt that new style instead of fighting it.
  local expectedSize=fs.questieOctoBaseSize and (fs.questieOctoBaseSize+1) or nil
  local externalChange=not fs.questieOctoHeaderStyled
    or currentFont~=fs.questieOctoBaseFont
    or currentFlags~=(fs.questieOctoBaseFlags or "")
    or (expectedSize and math.abs(currentSize-expectedSize)>0.01)

  if externalChange then
    fs.questieOctoBaseFont=currentFont
    fs.questieOctoBaseSize=currentSize
    fs.questieOctoBaseFlags=currentFlags
  end

  fs:SetFont(fs.questieOctoBaseFont,fs.questieOctoBaseSize+1,fs.questieOctoBaseFlags or "")
  fs.questieOctoHeaderStyled=true
end

local function RestoreQuestFont(button)
  local fs=GetButtonFontString(button)
  if not fs or not fs.SetFont then return end

  -- Only restore a font when this pooled Blizzard row was previously used as
  -- a zone header by Questie-Octo. Otherwise leave the active UI skin alone.
  if fs.questieOctoHeaderStyled and fs.questieOctoBaseFont and fs.questieOctoBaseSize then
    fs:SetFont(fs.questieOctoBaseFont,fs.questieOctoBaseSize,fs.questieOctoBaseFlags or "")
  end
  fs.questieOctoHeaderStyled=nil
end

local function StyleButton(button,index)
  if not button or not index or index<1 or type(GetQuestLogTitle)~="function" then return end

  -- Work from the native visible log entry. This keeps the enhancement
  -- independent of whichever addon is skinning the Blizzard Quest Log rows.
  local title,level,tag,isHeader=GetQuestLogTitle(index)
  if not title then return end

  if isHeader then
    ApplyHeaderFont(button)
    local fs=GetButtonFontString(button)
    if fs then fs.questieOctoHeaderStyled=true end
    return
  end

  -- Capture Turtle/OctoWoW's native row color before Questie-Octo changes
  -- the displayed title. Do not repaint the Quest Log afterward.
  CacheNativeQuestColor(button,index)
  RestoreQuestFont(button)

  local nativeTitle=title
  local questID
  if QuestieOcto.API and QuestieOcto.API.GetQuestIDForLogIndex then
    questID=QuestieOcto.API:GetQuestIDForLogIndex(index)
  end
  if questID and QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestTitle then
    title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID) or nativeTitle
  end

  local text=title
  if Settings():Get("questLogShowLevels") then
    local numericLevel=tonumber(level)
    local levelText=numericLevel and tostring(numericLevel) or "??"
    local groupTag=(tag and tag~="") and "+" or ""
    text="["..levelText..groupTag.."] "..title
  end
  if button.SetText then button:SetText(text) end

  -- Difficulty color is intentionally left untouched. The native Quest Log
  -- already painted this row according to the Turtle/OctoWoW client rules.

  -- Let Blizzard resize its own clickable row after the text change.
  if QuestLogTitleButton_Resize then
    pcall(QuestLogTitleButton_Resize,button)
  end
end

local function SelectedQuestID()
  if type(GetQuestLogSelection)~="function" then return nil end
  local index=GetQuestLogSelection()
  if not index or index<1 then return nil end
  -- Headers and unmatched rows resolve to no quest ID, which disables the button.
  local questID
  if QuestieOcto.API and QuestieOcto.API.GetQuestIDForLogIndex then
    questID=QuestieOcto.API:GetQuestIDForLogIndex(index)
  end
  return questID and tonumber(questID) or nil
end

local function QuestZoneMapID(questID)
  local maps=QuestieOcto.Nodes and QuestieOcto.Nodes.questMaps and QuestieOcto.Nodes.questMaps[tonumber(questID)]
  if not maps then return nil end
  -- Pick the lowest zone map ID so repeated presses stay deterministic.
  local best
  for mapID in pairs(maps) do
    mapID=tonumber(mapID)
    if mapID and (not best or mapID<best) then best=mapID end
  end
  return best
end

local function OpenWorldMapToZone(mapID)
  mapID=tonumber(mapID)
  if not mapID or type(SetMapZoom)~="function" or type(GetMapZones)~="function"
     or type(GetMapContinents)~="function" or not QuestieOcto.DatabaseAPI then
    return false
  end
  -- Resolve the quest's zone map ID to a continent/zone index, mirroring the
  -- world-map pin zone-entry lookup.
  local continents={GetMapContinents()}
  for continent=1,table.getn(continents) do
    local zones={GetMapZones(continent)}
    for index,name in ipairs(zones) do
      if QuestieOcto.DatabaseAPI:GetMapIDByName(name)==mapID then
        if WorldMapFrame and not WorldMapFrame:IsShown() and ShowUIPanel then ShowUIPanel(WorldMapFrame) end
        SetMapZoom(continent,index)
        return true
      end
    end
  end
  return false
end

function Q:EnsureShowMapButton()
  if self.showMapButton or not QuestLogFrame or type(CreateFrame)~="function" then return end

  local button=CreateFrame("Button","QuestieOctoShowMapButton",QuestLogFrame,"UIPanelButtonTemplate")
  button:SetWidth(80)
  button:SetHeight(22)
  button:SetText("Show Map")

  -- Match the requested placement to the left of the "Quests x/25" counter,
  -- falling back to the frame's top-right corner if that element is absent.
  local counter=getglobal and getglobal("QuestLogQuestCount")
  if counter then
    button:SetPoint("RIGHT",counter,"LEFT",-20,0)
  else
    button:SetPoint("TOPRIGHT",QuestLogFrame,"TOPRIGHT",-40,-40)
  end

  -- The template label renders blurry under custom UI scales; re-apply a
  -- standard font at an integer point size so it stays crisp.
  local fs=button.GetFontString and button:GetFontString()
  if fs and fs.SetFont then fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"") end

  button:SetScript("OnClick",function()
    local questID=SelectedQuestID()
    local mapID=questID and QuestZoneMapID(questID)
    if mapID then OpenWorldMapToZone(mapID) end
  end)

  self.showMapButton=button

  -- Questie Options button sits just left of "Show Map" and opens the same
  -- options window the Game Menu button uses.
  local optionsButton=CreateFrame("Button","QuestieOctoQuestLogOptionsButton",QuestLogFrame,"UIPanelButtonTemplate")
  optionsButton:SetWidth(104)
  optionsButton:SetHeight(22)
  optionsButton:SetText("Questie Options")
  optionsButton:SetPoint("RIGHT",button,"LEFT",-6,0)

  local ofs=optionsButton.GetFontString and optionsButton:GetFontString()
  if ofs and ofs.SetFont then ofs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"") end

  optionsButton:SetScript("OnClick",function()
    if QuestieOcto.Options and QuestieOcto.Options.Show then QuestieOcto.Options:Show() end
  end)

  self.optionsButton=optionsButton
end

function Q:UpdateShowMapButton()
  local button=self.showMapButton
  if not button then return end
  -- Enable only when the selected quest has a known zone to open.
  local questID=SelectedQuestID()
  local hasZone=questID and QuestZoneMapID(questID) and true or false
  if hasZone then
    if button.Enable then button:Enable() end
  else
    if button.Disable then button:Disable() end
  end
end

function Q:Refresh()
  if not QuestLogFrame or not QuestLogFrame:IsShown() then return end
  self:EnsureShowMapButton()

  local displayed=tonumber(QUESTS_DISPLAYED) or tonumber(QUESTLOG_QUESTS_DISPLAYED) or 6
  local offset=0
  if FauxScrollFrame_GetOffset and QuestLogListScrollFrame then
    offset=FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
  end

  for i=1,displayed do
    local button=GetTitleButton(i)
    if button and button:IsShown() then StyleButton(button,i+offset) end
  end

  self:UpdateShowMapButton()
end

function Q:ScheduleRefresh()
  if self.refreshPending then return end
  self.refreshPending=true
  if QuestieOcto.Scheduler and QuestieOcto.Scheduler.After then
    QuestieOcto.Scheduler:After(0,function()
      Q.refreshPending=false
      Q:Refresh()
    end,"questlog-enhancement-refresh")
  else
    self.refreshPending=false
    self:Refresh()
  end
end

function Q:InstallVisibilityWatcher()
  if self.eventFrame then return end
  local frame=CreateFrame("Frame","QuestieOctoQuestLogEnhancementWatcher",UIParent)
  self.eventFrame=frame
  frame:RegisterEvent("QUEST_LOG_UPDATE")
  frame:SetScript("OnEvent",function()
    Q:ScheduleRefresh()
  end)

  -- Some Vanilla/Turtle quest-log scroll paths retain an older update
  -- function reference. Watch only the scroll offset while the log is open;
  -- this adds no work while the Quest Log is closed and avoids replacing
  -- Blizzard's scrolling behavior.
  frame:SetScript("OnUpdate",function()
    if not QuestLogFrame or not QuestLogFrame:IsShown() then
      Q.lastOffset=nil
      return
    end
    local offset=0
    if FauxScrollFrame_GetOffset and QuestLogListScrollFrame then
      offset=FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
    end
    if Q.lastOffset~=offset then
      Q.lastOffset=offset
      Q:ScheduleRefresh()
    end
    if not Q.hooked then Q:InstallHook() end
  end)

  if QuestLogFrame and QuestLogFrame.GetScript and QuestLogFrame.SetScript then
    local originalOnShow=QuestLogFrame:GetScript("OnShow")
    QuestLogFrame:SetScript("OnShow",function()
      if originalOnShow then originalOnShow() end
      Q:ScheduleRefresh()
    end)
  end
end

function Q:InstallHook()
  if self.hooked or type(QuestLog_Update)~="function" then return end
  local original=QuestLog_Update
  self.originalUpdate=original

  QuestLog_Update=function()
    local result=original()
    Q:ScheduleRefresh()
    return result
  end

  -- Vanilla FauxScrollFrame can retain an older update function reference.
  if QuestLogScrollFrame then QuestLogScrollFrame.update=QuestLog_Update end

  self.hooked=true
end

function Q:Start()
  if self.started then return end
  self.started=true
  self:InstallHook()
  self:InstallVisibilityWatcher()
  self:EnsureShowMapButton()
  self:ScheduleRefresh()
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",Q,"Start")