QuestieOcto.QuestLog = QuestieOcto.QuestLog or {}
local QL = QuestieOcto.QuestLog

QL.started=false
QL.running=false
QL.pending=false
QL.fastPending=false
QL.acceptedQuestID=nil
QL.acceptedHints={}
QL.acceptPollGeneration=0
QL.acceptPollUntil=0
QL.active={}
QL.snapshot=nil
QL.mapSnapshot=nil
QL.mapState=nil
QL.stats={ entries=0, quests=0, resolved=0, refreshes=0, acceptedFastRefreshes=0, acceptedEvents=0, acceptedResolved=0, acceptedFromIndex=0, acceptedHintsUsed=0, acceptedPrimes=0, acceptedPolls=0, lastAcceptedQuestID=0, removedEvents=0, removedResolved=0, removedFromIndex=0, lastRemovedQuestID=0, completeRaw=0, completeObjectives=0, completeNoObjectives=0, failed=0, mapChanges=0, progressOnlyChanges=0 }

local function ParseObjectiveProgress(text)
  if not text then return nil,nil end

  -- Vanilla objective strings are usually "Something: 3/10".
  local matchStart,matchEnd,current,required=string.find(text,"(%d+)%s*/%s*(%d+)")
  return tonumber(current),tonumber(required)
end

local function ObjectiveProgressFallback(text)
  if not text then return nil,nil end
  local matchStart,matchEnd,current,required=string.find(text,"(%d+)%s*/%s*(%d+)")
  return tonumber(current),tonumber(required)
end

local function SortedNumericKeys(src)
  local keys={}
  if type(src)~="table" then return keys end
  for k in pairs(src) do
    if type(k)=="number" then table.insert(keys,k) end
  end
  table.sort(keys)
  return keys
end

local function ReadObjectives(index,questID)
  local objectives={}
  local snapshot={}
  local mapSnapshot={}
  local allDone=false

  -- Questie v7+ source of truth.
  local apiObjectives=QuestieOcto.API:GetQuestObjectives(questID,index)

  if type(apiObjectives)=="table" then
    allDone=false
    local nonLogCount=0

    -- ClassicAPI returns objectives indexed by their quest-log objective
    -- number. Keep that numeric identity/order instead of relying on pairs(),
    -- whose iteration order can differ between Lua tables/clients. The row's
    -- text, progress and completion therefore stay attached to the same
    -- objective while LocalizeObjectiveRows applies the compact DB ordinal.
    local objectiveKeys=SortedNumericKeys(apiObjectives)
    for keyIndex=1,table.getn(objectiveKeys) do
      local i=objectiveKeys[keyIndex]
      local row=apiObjectives[i]
      local typ=row.type
      local text=row.text
      local current=tonumber(row.numFulfilled)
      local required=tonumber(row.numRequired)
      if current==nil or required==nil then
        local parsedCurrent,parsedRequired=ParseObjectiveProgress(text)
        if current==nil then current=parsedCurrent end
        if required==nil then required=parsedRequired end
      end
      local finished=row.finished and true or false
      local objectiveID=QuestieOcto.API and QuestieOcto.API.GetQuestLogLeaderBoardID
        and QuestieOcto.API:GetQuestLogLeaderBoardID(i,index) or nil

      -- ClassicAPI/Turtle can publish the numerical counter before its separate
      -- `finished` boolean catches up. Treat a fulfilled numerical objective as
      -- complete immediately, matching the legacy leaderboard fallback below.
      -- Without this, the Tracker can already display 10/10 while the semantic
      -- quest state (and therefore the map) remains stuck on the objective.
      if not finished and current and required and required>0 and current>=required then
        finished=true
      end

      if typ~="log" then
        nonLogCount=nonLogCount+1
        if nonLogCount==1 then allDone=true end
        table.insert(objectives,{
          index=i,
          text=text,
          rawText=text,
          type=typ,
          complete=finished,
          finished=finished,
          current=current,
          required=required,
          numFulfilled=current,
          numRequired=required,
          objectiveID=objectiveID
        })
        if not finished then allDone=false end
      end

      table.insert(snapshot,tostring(text or ""))
      table.insert(snapshot,tostring(typ or ""))
      table.insert(snapshot,finished and "1" or "0")
      table.insert(snapshot,tostring(current or -1))
      table.insert(snapshot,tostring(required or -1))
      table.insert(snapshot,tostring(objectiveID or 0))

      -- Map nodes only care whether an objective is still active. pfQuest's
      -- quest-state signature likewise records todo/done, not 3/10 -> 4/10.
      -- Keep the full snapshot above for Tracker/UI updates, but exclude the
      -- numerical counter (and counter-bearing text) from map invalidation.
      if typ~="log" then
        table.insert(mapSnapshot,tostring(i))
        table.insert(mapSnapshot,tostring(typ or ""))
        table.insert(mapSnapshot,finished and "1" or "0")
        table.insert(mapSnapshot,tostring(objectiveID or 0))
      end
    end

    return objectives,table.concat(snapshot,"\\030"),allDone,"QuestieAPI",table.concat(mapSnapshot,"\\030")
  end

  -- 1.12 compatibility fallback. The legacy leaderboard API only supplies
  -- text/type/finished, so numeric progress is parsed from the displayed text.
  local n=GetNumQuestLeaderBoards(index) or 0
  allDone=false
  local nonLogCount=0

  for i=1,n do
    local text,typ,done=GetQuestLogLeaderBoard(i,index)
    local current,required=ObjectiveProgressFallback(text)
    local finished=done and true or false
    local objectiveID=QuestieOcto.API and QuestieOcto.API.GetQuestLogLeaderBoardID
      and QuestieOcto.API:GetQuestLogLeaderBoardID(i,index) or nil

    if current and required and required>0 and current>=required then
      finished=true
    end

    if typ~="log" then
      nonLogCount=nonLogCount+1
      if nonLogCount==1 then allDone=true end
      table.insert(objectives,{
        index=i,text=text,rawText=text,type=typ,
        complete=finished,finished=finished,
        current=current,required=required,
        numFulfilled=current,numRequired=required,
        objectiveID=objectiveID
      })
      if not finished then allDone=false end
    end

    table.insert(snapshot,tostring(text or ""))
    table.insert(snapshot,tostring(typ or ""))
    table.insert(snapshot,finished and "1" or "0")
    table.insert(snapshot,tostring(current or -1))
    table.insert(snapshot,tostring(required or -1))
    table.insert(snapshot,tostring(objectiveID or 0))

    if typ~="log" then
      table.insert(mapSnapshot,tostring(i))
      table.insert(mapSnapshot,tostring(typ or ""))
      table.insert(mapSnapshot,finished and "1" or "0")
      table.insert(mapSnapshot,tostring(objectiveID or 0))
    end
  end

  return objectives,table.concat(snapshot,"\\030"),allDone,"LeaderboardFallback",table.concat(mapSnapshot,"\\030")
end


local function ContainsObjectiveID(list,id)
  id=tonumber(id)
  if not id then return false end
  for i=1,table.getn(list or {}) do
    if tonumber(list[i])==id then return true end
  end
  return false
end

local function LiveObjectiveKind(q,row)
  local id=tonumber(row and row.objectiveID)
  if not q or not id then return nil end
  local typ=string.lower(tostring(row.type or ""))

  -- pfQuest uses ClassicAPI's GetQuestLogLeaderBoardID and then determines
  -- whether the returned ID is a unit/object/item from the quest/database.
  -- Vanilla can report some object interactions as "monster", so prefer the
  -- native type but allow the live ID to disambiguate creature vs game object.
  if typ=="item" and ContainsObjectiveID(q.objectives.item,id) then return "item" end
  if (typ=="object" or typ=="gameobject") and ContainsObjectiveID(q.objectives.gameObject,id) then return "gameObject" end
  if typ=="monster" or typ=="creature" or typ=="kill" then
    if ContainsObjectiveID(q.objectives.creature,id) then return "creature" end
    if ContainsObjectiveID(q.objectives.gameObject,id) then return "gameObject" end
  end

  if ContainsObjectiveID(q.objectives.creature,id) then return "creature" end
  if ContainsObjectiveID(q.objectives.gameObject,id) then return "gameObject" end
  if ContainsObjectiveID(q.objectives.item,id) then return "item" end
  return nil
end

local function LocalizeObjectiveRows(questID,objectives)
  if not questID or type(objectives)~="table" then return objectives end
  if not QuestieOcto.DatabaseAPI or not QuestieOcto.DatabaseAPI:IsReady() then return objectives end

  local q=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
  if not q then return objectives end

  for i=1,table.getn(objectives) do
    local row=objectives[i]
    local id=tonumber(row and row.objectiveID)
    local kind=LiveObjectiveKind(q,row)
    local name=nil

    if id and kind=="creature" then name=QuestieOcto.DatabaseAPI:GetCreatureName(id)
    elseif id and kind=="gameObject" then name=QuestieOcto.DatabaseAPI:GetObjectName(id)
    elseif id and kind=="item" then name=QuestieOcto.DatabaseAPI:GetItemName(id) end

    -- Never localize by objective array position. Questie 5/6 only assumes
    -- positional identity when both sides contain one objective; pfQuest uses
    -- ClassicAPI's live leaderboard ID. If no trustworthy ID is available,
    -- keep Turtle's native objective text intact for the fallback matcher.
    if row and name and name~="" then
      if row.current~=nil and row.required~=nil then
        row.text=name..": "..tostring(row.current).."/"..tostring(row.required)
      else
        row.text=name
      end
    end
  end
  return objectives
end

-- Questie 5.2.3/6.0.0 explicitly "prime" the native quest log on accept
-- because first-time quest data can arrive several seconds later than a
-- re-accepted/cached quest on old clients. Turtle/ClassicAPI exhibits the same
-- behavior. Touch the native title/leaderboard APIs so the client requests and
-- exposes the fresh quest data as early as possible.
local function PrimeQuestLog()
  local entries=GetNumQuestLogEntries() or 0
  for i=1,entries+1 do
    if GetQuestLogTitle then GetQuestLogTitle(i) end
    if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
      local count=GetNumQuestLeaderBoards(i) or 0
      for objectiveIndex=1,count do
        GetQuestLogLeaderBoard(objectiveIndex,i)
      end
    end
    -- Touch the ClassicAPI bridge too. It may still return nil on the first
    -- pass, but subsequent accepted-poll passes can then observe the ID as soon
    -- as the bridge has it.
    if QuestieOcto.API and QuestieOcto.API.GetQuestIDForLogIndex then
      QuestieOcto.API:GetQuestIDForLogIndex(i)
    end
  end
  QL.stats.acceptedPrimes=(QL.stats.acceptedPrimes or 0)+1
end

local function AddAcceptedHint(questID,questLogIndex)
  questID=tonumber(questID)
  questLogIndex=tonumber(questLogIndex)
  if not questID or questID<=0 then return end

  local title=nil
  if QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestTitle then
    title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID)
  end

  QL.acceptedHints[questID]={
    id=questID,
    index=questLogIndex,
    title=title,
    expires=(GetTime and GetTime() or 0)+8
  }
end

local function AcceptedHintForEntry(index,title)
  local now=GetTime and GetTime() or 0
  local best=nil
  for questID,hint in pairs(QL.acceptedHints or {}) do
    if hint and (not hint.expires or hint.expires>=now) then
      local titleMatches=(not hint.title or not title or hint.title==title)
      if titleMatches and tonumber(hint.index)==tonumber(index) then
        return tonumber(questID)
      end
      if titleMatches and not best then best=tonumber(questID) end
    end
  end
  return best
end

local function PurgeAcceptedHints(nativeResolved)
  local now=GetTime and GetTime() or 0
  for questID,hint in pairs(QL.acceptedHints or {}) do
    if (nativeResolved and nativeResolved[questID]) or (hint and hint.expires and hint.expires<now) then
      QL.acceptedHints[questID]=nil
    end
  end
end

local function QuestLogIDsResolved()
  local entries=GetNumQuestLogEntries() or 0
  for i=1,entries do
    local info=QuestieOcto.API:GetQuestLogInfo(i)
    if not info or not info.title then return false end
    if not info.isHeader and not info.questID then return false end
  end
  return true
end

function QL:BeginAcceptedPolling()
  self.acceptPollGeneration=(self.acceptPollGeneration or 0)+1
  local generation=self.acceptPollGeneration
  local started=GetTime and GetTime() or 0
  self.acceptPollUntil=started+4
  local minimumUntil=started+0.35

  local function poll()
    if generation~=QL.acceptPollGeneration then return end
    QL.stats.acceptedPolls=(QL.stats.acceptedPolls or 0)+1
    PrimeQuestLog()
    QL:Schedule(0.01,true)

    local now=GetTime and GetTime() or 0
    if now>=minimumUntil and QuestLogIDsResolved() then
      QL.acceptPollUntil=0
      return
    end
    if now<QL.acceptPollUntil then
      QuestieOcto.Scheduler:After(0.08,poll,"questlog-accepted-poll")
    else
      QL.acceptPollUntil=0
    end
  end

  -- Do the Questie-style priming immediately, then keep a short fast poll
  -- alive while ClassicAPI catches up. Repeated accepts restart/extend this
  -- window, so accepting several starter quests quickly is also handled.
  PrimeQuestLog()
  QuestieOcto.Scheduler:After(0.08,poll,"questlog-accepted-poll")
end

function QL:Schedule(delay,fastRefresh)
  if not self.started then return end
  self.pending=true
  if fastRefresh then self.fastPending=true end

  QuestieOcto.Scheduler:After(delay or 0.25,function()
    if QL.pending then
      local fast=QL.fastPending and true or false
      QL.pending=false
      QL.fastPending=false
      QL:Refresh(fast)
    end
  end,"questlog-refresh")
end

function QL:Refresh(fastRefresh)
  if self.running then
    self.pending=true
    if fastRefresh then self.fastPending=true end
    return
  end

  self.running=true

  local entries,quests=GetNumQuestLogEntries()
  entries=entries or 0
  quests=quests or 0

  self.stats.entries=entries
  self.stats.quests=quests
  self.stats.resolved=0
  self.stats.completeRaw=0
  self.stats.completeObjectives=0
  self.stats.completeNoObjectives=0
  self.stats.failed=0

  local nextActive={}
  local snapshotParts={}
  local nextMapState={}
  local pos=1
  local currentHeader="Other"
  local nativeResolved={}

  local function step()
    local count=0
    local batch=fastRefresh and 32 or 4

    while pos<=entries and count<batch do
      local index=pos
      pos=pos+1

      local info=QuestieOcto.API:GetQuestLogInfo(index)
      local title=info and info.title
      local level=info and info.level
      local tag=info and info.tag
      local isHeader=info and info.isHeader
      local isComplete=info and info.isComplete
      if title and isHeader then
        currentHeader=title
      elseif title then
        local nativeTitle=title
        local nativeQuestID=(info and info.questID) or QuestieOcto.API:GetQuestIDForLogIndex(index)
        local questID=nativeQuestID
        if not questID then
          questID=AcceptedHintForEntry(index,nativeTitle)
          if questID then QL.stats.acceptedHintsUsed=(QL.stats.acceptedHintsUsed or 0)+1 end
        end
        if nativeQuestID and tonumber(nativeQuestID)>0 then nativeResolved[tonumber(nativeQuestID)]=true end
        if questID and QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestTitle then
          title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID) or nativeTitle
        end
        local objectives,objectiveSnapshot,allObjectivesDone,objectiveSource,objectiveMapSnapshot=ReadObjectives(index,questID)
        objectives=LocalizeObjectiveRows(questID,objectives)

        -- Preserve the client/server tri-state exactly:
        --   1 = complete, 0 = incomplete, -1 = failed.
        -- Lua 5.0 treats -1 as truthy, so never coerce this with a generic
        -- truthiness check.
        local status=0
        if isComplete==1 or isComplete==true then
          status=1
          QL.stats.completeRaw=QL.stats.completeRaw+1
        elseif isComplete==-1 then
          status=-1
          QL.stats.failed=(QL.stats.failed or 0)+1
        end

        -- Vanilla can omit GetQuestLogTitle().isComplete for some quests.
        -- Ask the quest-state API before considering objective counters.
        if status==0 and IsQuestComplete and questID then
          local ok,result=pcall(IsQuestComplete,questID)
          if ok then
            if result==1 or result==true then status=1
            elseif result==-1 then
              status=-1
              QL.stats.failed=(QL.stats.failed or 0)+1
            end
          end
        end

        -- Vanilla/pfQuest/Questie behavior for breadcrumb/talk quests: an
        -- ACTIVE, non-failed quest with zero native quest-log objectives is
        -- ready for turn-in even when GetQuestLogTitle().isComplete is nil.
        --
        -- Keep one safety guard for Turtle's first-accept cache delay: if our
        -- database already knows the quest has ordinary objectives (or IR item
        -- requirements), a transient native leaderboard count of zero must not
        -- briefly turn a fresh kill/loot quest into a completed quest. Failed
        -- quests never reach this branch because status is already -1.
        if status==0 and GetNumQuestLeaderBoards then
          local ok,leaderboardCount=pcall(GetNumQuestLeaderBoards,index)
          leaderboardCount=ok and tonumber(leaderboardCount) or nil
          if leaderboardCount==0 then
            local model=questID and QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
            local knownObjectives=model and model.objectiveData and table.getn(model.objectiveData) or 0
            local knownIR=0
            if model and model.objectives and model.objectives.irItems then
              knownIR=table.getn(model.objectives.irItems)
            end
            if knownObjectives==0 and knownIR==0 then
              status=1
              QL.stats.completeNoObjectives=(QL.stats.completeNoObjectives or 0)+1
            end
          end
        end

        -- Objective-counter fallback for normal kill/loot/use quests when the
        -- client does not publish isComplete but every live objective is done.
        if status==0 and table.getn(objectives)>0 and allObjectivesDone then
          status=1
          QL.stats.completeObjectives=QL.stats.completeObjectives+1
        end

        local complete=status==1 and true or false
        local failed=status==-1 and true or false

        table.insert(snapshotParts,tostring(questID or 0))
        table.insert(snapshotParts,title)
        table.insert(snapshotParts,tostring(level or 0))
        table.insert(snapshotParts,tostring(tag or ""))
        table.insert(snapshotParts,tostring(status))
        table.insert(snapshotParts,objectiveSnapshot)

        if questID and questID>0 then
          nextActive[questID]={
            id=questID,
            logIndex=index,
            title=title,
            level=level,
            -- Vanilla/pfQuest uses GetQuestLogTitle().tag as the live elite
            -- marker. Preserve it with the quest instead of reclassifying
            -- quests from database metadata.
            tag=tag,
            zoneGroup=currentHeader,
            status=status,
            complete=complete,
            failed=failed,
            objectives=objectives,
            objectiveSource=objectiveSource
          }
          -- Separate map semantics from live progress text. A simple 3/10 ->
          -- 4/10 update must refresh the Tracker, but it must not reconstruct
          -- thousands of Full Nodes whose visibility did not change.
          nextMapState[questID]=tostring(status).."\031"..tostring(objectiveMapSnapshot or "")
          QL.stats.resolved=QL.stats.resolved+1
        end

        count=count+1
      end
    end

    if pos<=entries then
      QuestieOcto.Scheduler:Enqueue(step,"questlog-scan")
      return
    end

    local nextSnapshot=table.concat(snapshotParts,"\031")
    local changed=(nextSnapshot~=QL.snapshot)

    local previousActive=QL.active or {}
    local activeSetChangedQuests={}
    local activeSetChanged=false
    for questID in pairs(nextActive) do
      if previousActive[questID]==nil then
        activeSetChangedQuests[questID]=true
        activeSetChanged=true
      end
    end
    for questID in pairs(previousActive) do
      if nextActive[questID]==nil then
        activeSetChangedQuests[questID]=true
        activeSetChanged=true
      end
    end

    -- Eligibility consumers need active membership and whole-quest status, but
    -- not every individual objective completion. Keep that signal separate so
    -- availability/completion services preserve their old correctness without
    -- forcing a Full Nodes rebuild for 3/10 -> 4/10 or one sub-objective done.
    local eligibilityChangedQuests={}
    local eligibilityChanged=activeSetChanged and true or false
    for questID in pairs(activeSetChangedQuests) do eligibilityChangedQuests[questID]=true end
    for questID,state in pairs(nextActive) do
      local previous=previousActive[questID]
      if previous and tonumber(previous.status or 0)~=tonumber(state.status or 0) then
        eligibilityChangedQuests[questID]=true
        eligibilityChanged=true
      end
    end

    local firstMapPublication=(QL.mapState==nil)
    local previousMapState=QL.mapState or {}
    local mapChangedQuests={}
    local mapChanged=firstMapPublication and true or false
    for questID,state in pairs(nextMapState) do
      if previousMapState[questID]~=state then
        mapChangedQuests[questID]=true
        mapChanged=true
      end
    end
    for questID in pairs(previousMapState) do
      if nextMapState[questID]==nil then
        mapChangedQuests[questID]=true
        mapChanged=true
      end
    end

    QL.snapshot=nextSnapshot
    QL.mapState=nextMapState
    QL.mapSnapshot=true
    QL.active=nextActive
    PurgeAcceptedHints(nativeResolved)
    QL.running=false
    QL.stats.refreshes=QL.stats.refreshes+1
    if fastRefresh then
      QL.stats.acceptedFastRefreshes=(QL.stats.acceptedFastRefreshes or 0)+1
    end

    if changed then
      QuestieOcto:SendMessage("QUEST_LOG_CHANGED")
      if activeSetChanged then
        QuestieOcto:SendMessage("QUEST_ACTIVE_SET_CHANGED",activeSetChangedQuests)
      end
      if eligibilityChanged then
        QuestieOcto:SendMessage("QUEST_ELIGIBILITY_STATE_CHANGED",eligibilityChangedQuests)
      end
      if mapChanged then
        QL.stats.mapChanges=(QL.stats.mapChanges or 0)+1
        QuestieOcto:SendMessage("QUEST_MAP_STATE_CHANGED",mapChangedQuests)
      else
        QL.stats.progressOnlyChanges=(QL.stats.progressOnlyChanges or 0)+1
      end
    end

    if QL.acceptedQuestID then
      local accepted=QL.active[QL.acceptedQuestID]
      if accepted and accepted.objectives then
        QL.acceptedQuestID=nil
      end
    end

    if QL.pending then
      local fast=QL.fastPending and true or false
      QL.pending=false
      QL.fastPending=false
      QL:Schedule(fast and 0.01 or 0.20,fast)
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"questlog-scan")
end

function QL:IsOnQuest(questID)
  return self.active[questID] and true or false
end

function QL:GetQuestStatus(questID)
  local state=self.active[questID]
  return state and state.status or nil
end

function QL:IsFailed(questID)
  local state=self.active[questID]
  return state and state.failed and true or false
end

local function ResolveAcceptedQuestID(questLogIndex,eventQuestID)
  local questID=tonumber(eventQuestID)

  -- Questie 5/6 receive (questLogIndex, questId). Prefer the explicit questId.
  if questID and questID>0 and QuestieOcto.QuestModel:Get(questID) then
    return questID,false
  end

  -- ClassicAPI/Turtle compatibility: if only the log index is present,
  -- resolve it through the same C_QuestLog bridge used by Questie's cache.
  local index=tonumber(questLogIndex)
  if index and index>0 then
    local fromIndex=QuestieOcto.API:GetQuestIDForLogIndex(index)
    if fromIndex and tonumber(fromIndex)>0 then
      return tonumber(fromIndex),true
    end

    -- Some compatibility layers pass questId as the only argument.
    if QuestieOcto.API:IsOnQuest(index) and QuestieOcto.QuestModel:Get(index) then
      return index,false
    end
  end

  return nil,false
end

local function ResolveRemovedQuestID(eventValue)
  local value=tonumber(eventValue)
  if not value or value<=0 then return nil,false end

  -- Questie 7/8 define QUEST_REMOVED's argument as questId. Our cached active
  -- quest log still contains the removed quest until the fast refresh runs.
  if QL.active[value] then return value,false end

  -- Turtle/ClassicAPI compatibility: if an older event bridge supplies the
  -- former quest-log index, resolve it against the PREVIOUS QuestLog cache.
  -- C_QuestLog can no longer be trusted for an abandoned quest after removal.
  for questID,state in pairs(QL.active or {}) do
    if state and tonumber(state.logIndex)==value then
      return tonumber(questID),true
    end
  end

  return nil,false
end

function QL:Start()
  if self.started then return end
  self.started=true

  local f=CreateFrame("Frame","QuestieOctoQuestLogEvents",UIParent)
  self.frame=f
  f:RegisterEvent("QUEST_LOG_UPDATE")
  f:RegisterEvent("QUEST_ACCEPTED")
  f:RegisterEvent("QUEST_REMOVED")
  f:RegisterEvent("QUEST_TURNED_IN")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:SetScript("OnEvent",function()
    if event=="QUEST_REMOVED" then
      QL.stats.removedEvents=(QL.stats.removedEvents or 0)+1

      local questID,fromIndex=ResolveRemovedQuestID(arg1)
      if questID then
        QL.stats.removedResolved=(QL.stats.removedResolved or 0)+1
        QL.stats.lastRemovedQuestID=questID
        if fromIndex then
          QL.stats.removedFromIndex=(QL.stats.removedFromIndex or 0)+1
        end

        -- Questie 5/6/7/8 AbandonedQuest unloads every frame for the quest
        -- before recalculating available quests. Do the same immediately.
        if QuestieOcto.PreparedMap and QuestieOcto.PreparedMap.RemoveQuest then
          QuestieOcto.PreparedMap:RemoveQuest(questID)
        end
        if QuestieOcto.Map and QuestieOcto.Map.RemoveQuest then
          QuestieOcto.Map:RemoveQuest(questID)
        end
      end

      -- Whether this becomes an abandon or a turn-in, refresh the quest-log
      -- cache immediately. Availability/objectives will then publish the new
      -- authoritative state; abandon redraws !, turn-in stays removed.
      QL:Schedule(0.01,true)
      return
    end

    if event=="QUEST_TURNED_IN" then
      -- QUEST_REMOVED/QUEST_LOG_UPDATE normally follow a turn-in, but some
      -- compatibility layers can delay or omit one of them. Force a fast cache
      -- pass so the Tracker cannot retain a rewarded quest until another UI
      -- action happens. A settled pass below/through QUEST_LOG_UPDATE remains
      -- harmless if the normal event sequence also arrives.
      QL:Schedule(0.01,true)
      QuestieOcto.Scheduler:After(1.00,function()
        QL:Schedule(0.01,true)
      end,"questlog-turnin-settle")
      return
    end

    if event=="QUEST_ACCEPTED" then
      QL.stats.acceptedEvents=(QL.stats.acceptedEvents or 0)+1

      local questID,fromIndex=ResolveAcceptedQuestID(arg1,arg2)
      if questID then
        QL.stats.acceptedResolved=(QL.stats.acceptedResolved or 0)+1
        QL.stats.lastAcceptedQuestID=questID
        if fromIndex then
          QL.stats.acceptedFromIndex=(QL.stats.acceptedFromIndex or 0)+1
        end
      end

      if questID and QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.RemoveQuest then
        QuestieOcto.AvailableQuests:RemoveQuest(questID)
      end

      QL.acceptedQuestID=questID
      if questID then AddAcceptedHint(questID,arg1) end
      QL:BeginAcceptedPolling()
      QL:Schedule(0.01,true)
      return
    end

    local acceptPolling=(QL.acceptPollUntil or 0)>(GetTime and GetTime() or 0)
    if event=="QUEST_LOG_UPDATE" and (QL.acceptedQuestID or acceptPolling) then
      QL:Schedule(0.01,true)
    else
      QL:Schedule(0.20)
    end

    if event=="QUEST_LOG_UPDATE" then
      -- Questie 5.2.3 and 6.0.0 intentionally bucket QUEST_LOG_UPDATE for about
      -- one second because completion/leaderboard data can propagate through
      -- Blizzard's API after the event itself. Keep our fast 0.20s pass for
      -- responsive counters, then perform one keyed settled pass for semantic
      -- todo -> complete transitions that arrive late. Repeated QLU events simply
      -- move this one follow-up pass rather than creating a polling storm.
      QuestieOcto.Scheduler:After(1.00,function()
        QL:Schedule(0.01,true)
      end,"questlog-settled-refresh")
    end
  end)

  self:Schedule(0.01,true)
end
