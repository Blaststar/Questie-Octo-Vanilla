-- Questie-Octo tracker driver/state layer.
--
-- Backport lineage:
--   Questie 5.2.3/6.0.0: Shift+Click quest-log interception and native watch bypass.
--   Questie 3.3.5: TrackedQuests / AutoUntrackedQuests semantics and tracker source state.
--   Questie 7/8: keep quest-log cache authoritative; tracker renderer consumes state.
--
-- This module deliberately does NOT draw the tracker. It produces stable tracked quest
-- state for the upcoming 3.3.5-style TrackerBaseFrame/TrackerQuestFrame renderer.

QuestieOcto.TrackerDriver = QuestieOcto.TrackerDriver or {}
local D=QuestieOcto.TrackerDriver

D.started=false
D.tracked={}
D.ordered={}
D.snapshot=""
D.questLogHooked=false
D.stats={ rebuilds=0, tracked=0, manualToggles=0, shiftClicks=0 }

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function EnsureCharacterDB()
  QuestieOctoDB=QuestieOctoDB or {}
  QuestieOctoDB.tracker=QuestieOctoDB.tracker or {}
  local db=QuestieOctoDB.tracker
  db.TrackedQuests=db.TrackedQuests or {}
  db.AutoUntrackedQuests=db.AutoUntrackedQuests or {}
  return db
end

function D:IsTracked(questID)
  questID=tonumber(questID)
  if not questID then return false end
  local db=EnsureCharacterDB()
  if Settings():Get("trackerAutoTrack") then
    return QuestieOcto.QuestLog.active[questID] and not db.AutoUntrackedQuests[questID] and true or false
  end
  return db.TrackedQuests[questID] and QuestieOcto.QuestLog.active[questID] and true or false
end

function D:Track(questID)
  questID=tonumber(questID)
  if not questID or not QuestieOcto.QuestLog.active[questID] then return false end
  local db=EnsureCharacterDB()
  if Settings():Get("trackerAutoTrack") then
    db.AutoUntrackedQuests[questID]=nil
  else
    db.TrackedQuests[questID]=true
  end
  self:Rebuild()
  return true
end

function D:Untrack(questID)
  questID=tonumber(questID)
  if not questID then return false end
  local db=EnsureCharacterDB()
  if Settings():Get("trackerAutoTrack") then
    db.AutoUntrackedQuests[questID]=true
  else
    db.TrackedQuests[questID]=nil
  end
  self:Rebuild()
  return true
end

function D:Toggle(questID)
  self.stats.manualToggles=self.stats.manualToggles+1
  if self:IsTracked(questID) then return self:Untrack(questID) end
  return self:Track(questID)
end

local function CompareZone(a,b)
  -- Questie 3.3.5: zone first, then quest level, then a stable title fallback.
  local az=string.lower(a.zoneGroup or "Other")
  local bz=string.lower(b.zoneGroup or "Other")
  if az~=bz then return az<bz end
  if (a.level or 0)~=(b.level or 0) then return (a.level or 0)<(b.level or 0) end
  return string.lower(a.title or "")<string.lower(b.title or "")
end

local function CompareLevel(a,b)
  -- Questie 3.3.5 byLevel: lower-level quests first, independent of completion.
  if (a.level or 0)~=(b.level or 0) then return (a.level or 0)<(b.level or 0) end
  return string.lower(a.title or "")<string.lower(b.title or "")
end

local function CompareProximity(a,b)
  -- Coordinate-aware proximity is populated by the map layer when available.
  -- Unknown distances sort after known distances, with zone ordering as a
  -- deterministic fallback.
  local ad=tonumber(a.distance)
  local bd=tonumber(b.distance)
  if ad and bd and ad~=bd then return ad<bd end
  if ad and not bd then return true end
  if bd and not ad then return false end
  return CompareZone(a,b)
end

function D:Rebuild()
  local db=EnsureCharacterDB()
  local nextTracked={}
  local ordered={}
  local snapshot={}
  local auto=Settings():Get("trackerAutoTrack") and true or false
  local showCompleted=Settings():Get("trackerShowCompleted") and true or false
  local hideCompletedObjectives=Settings():Get("trackerHideCompletedObjectives") and true or false

  -- Purge character exceptions for quests no longer in the log. This matches
  -- Questie 3.3.5 lifecycle cleanup and prevents abandoned/completed IDs leaking.
  for questID in pairs(db.TrackedQuests) do
    if not QuestieOcto.QuestLog.active[questID] then db.TrackedQuests[questID]=nil end
  end
  for questID in pairs(db.AutoUntrackedQuests) do
    if not QuestieOcto.QuestLog.active[questID] then db.AutoUntrackedQuests[questID]=nil end
  end

  for questID,state in pairs(QuestieOcto.QuestLog.active or {}) do
    local tracked
    if auto then tracked=not db.AutoUntrackedQuests[questID]
    else tracked=db.TrackedQuests[questID] and true or false end

    if tracked and (showCompleted or not state.complete) then
      local objectives={}
      for i=1,table.getn(state.objectives or {}) do
        local objective=state.objectives[i]
        if not (hideCompletedObjectives and objective.complete) then
          table.insert(objectives,objective)
        end
      end
      local row={
        id=questID,
        logIndex=state.logIndex,
        title=state.title,
        level=state.level or 0,
        zoneGroup=state.zoneGroup or "Other",
        complete=state.complete and true or false,
        failed=state.failed and true or false,
        objectives=objectives,
        objectiveSource=state.objectiveSource
      }
      nextTracked[questID]=row
      table.insert(ordered,row)
    end
  end

  local sortMode=Settings():Get("trackerSort")
  if sortMode=="level" then table.sort(ordered,CompareLevel)
  elseif sortMode=="proximity" then table.sort(ordered,CompareProximity)
  else table.sort(ordered,CompareZone) end

  for i=1,table.getn(ordered) do
    local row=ordered[i]
    table.insert(snapshot,tostring(row.id))
    table.insert(snapshot,row.zoneGroup or "")
    table.insert(snapshot,row.complete and "1" or "0")
    table.insert(snapshot,row.failed and "1" or "0")
    for j=1,table.getn(row.objectives or {}) do
      local o=row.objectives[j]
      table.insert(snapshot,tostring(o.text or ""))
      table.insert(snapshot,o.complete and "1" or "0")
      table.insert(snapshot,tostring(o.current or -1))
      table.insert(snapshot,tostring(o.required or -1))
    end
  end

  local nextSnapshot=table.concat(snapshot,"\031")
  local changed=nextSnapshot~=self.snapshot
  self.snapshot=nextSnapshot
  self.tracked=nextTracked
  self.ordered=ordered
  self.stats.rebuilds=self.stats.rebuilds+1
  self.stats.tracked=table.getn(ordered)

  if changed then QuestieOcto:SendMessage("TRACKER_STATE_CHANGED") end
end

function D:OnSettingChanged(key,value)
  if key=="trackerAutoTrack" then
    -- Match Questie 3.3.5 mode transitions exactly. Enabling automatic mode
    -- discards the old manual allow-list; disabling automatic mode discards
    -- the auto-mode exception list so manual tracking starts cleanly.
    local db=EnsureCharacterDB()
    if value then
      db.TrackedQuests={}
    else
      db.AutoUntrackedQuests={}
    end
  end
  self:Rebuild()
  -- Presentation settings such as lock/font can change without changing the
  -- tracked quest snapshot, so notify the visual shell explicitly as well.
  QuestieOcto:SendMessage("TRACKER_SETTING_CHANGED",key,value)
end

local function ResolveQuestLogButton(button)
  button=button or this
  if not button or button.isHeader then return nil,nil end
  local id=button.GetID and button:GetID() or nil
  if not id then return nil,nil end
  local offset=0
  if FauxScrollFrame_GetOffset and QuestLogListScrollFrame then
    offset=FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0
  end
  local index=id+offset
  local info=QuestieOcto.API:GetQuestLogInfo(index)
  if not info or info.isHeader then return nil,nil end
  local questID=info.questID or QuestieOcto.API:GetQuestIDForLogIndex(index)
  return tonumber(questID),index
end

function D:InstallQuestLogShiftClick()
  if self.questLogHooked or type(QuestLogTitleButton_OnClick)~="function" then return end
  local original=QuestLogTitleButton_OnClick
  self.originalQuestLogTitleButtonOnClick=original

  -- Questie 5.2.3/6.0.0 use a pre-hook replacement because a secure post-hook
  -- cannot stop Blizzard's five-watch behavior. Do the same on Vanilla 1.12.
  QuestLogTitleButton_OnClick=function(firstArg,secondArg)
    -- Questie 5/6/3.3.5 use the newer (self, button) signature. Vanilla
    -- 1.12/Turtle uses the older FrameXML convention where `this` is the
    -- clicked title button and the sole Lua argument is the mouse button.
    -- Preserve the native convention when forwarding normal clicks; changing
    -- it breaks Blizzard header expand/collapse handling. pfQuest's Vanilla
    -- compatibility path uses the same old-client distinction.
    local modernCall=(type(firstArg)=="table" or type(firstArg)=="userdata")
    local actualButton=modernCall and firstArg or this
    local click
    if modernCall then
      click=secondArg or arg1 or "LeftButton"
    else
      click=firstArg or arg1 or "LeftButton"
    end

    if actualButton and not actualButton.isHeader and click=="LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
      local questID,index=ResolveQuestLogButton(actualButton)
      if questID then
        D.stats.shiftClicks=D.stats.shiftClicks+1
        D:Toggle(questID)
        if QuestLog_SetSelection and index then QuestLog_SetSelection(index) end
        if QuestLog_Update then QuestLog_Update() end
        return
      end
    end

    if modernCall then
      return original(firstArg,secondArg)
    end
    return original(firstArg)
  end

  self.questLogHooked=true
end

function D:Start()
  if self.started then return end
  self.started=true
  EnsureCharacterDB()
  self:InstallQuestLogShiftClick()
  QuestieOcto:RegisterMessage("QUEST_LOG_CHANGED",self,"Rebuild")
  self:Rebuild()
end

QuestieOcto:RegisterMessage("FOUNDATION_READY",D,"Start")
