QuestieOcto.Objectives = QuestieOcto.Objectives or {}
local O = QuestieOcto.Objectives

O.byQuest={}
O.ready=false
O.running=false
O.pending=false
O.generation=0
O.stats={
  quests=0, creature=0, object=0, item=0, areaTrigger=0, itemSources=0, irTargets=0,
  mapped=0, unmapped=0, direct=0, fallback=0, fuzzy=0, single=0, typeMismatch=0,
  rebuilds=0, dependencyWaits=0
}

local MIN_DROP_CHANCE=1

local function ResetStats()
  local rebuilds=O.stats.rebuilds or 0
  local waits=O.stats.dependencyWaits or 0
  O.stats={
    quests=0, creature=0, object=0, item=0, areaTrigger=0, itemSources=0, irTargets=0,
    mapped=0, unmapped=0, direct=0, fallback=0, fuzzy=0, single=0, typeMismatch=0,
    rebuilds=rebuilds, dependencyWaits=waits
  }
end

local function DependenciesReady()
  return QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:IsReady()
    and QuestieOcto.QuestLog and QuestieOcto.QuestLog.snapshot
end

local function AddSource(list,kind,id,itemID,chance,vendor)
  table.insert(list,{kind=kind,id=id,itemID=itemID,chance=chance,vendor=vendor and true or false})
end

local function AddUniqueSource(list,seen,kind,id,itemID,chance,vendor)
  local key=kind..":"..tostring(id)
  if seen[key] then return end
  seen[key]=true
  AddSource(list,kind,id,itemID,chance,vendor)
  O.stats.itemSources=O.stats.itemSources+1
end

-- pfQuest SearchItemID semantics: direct creature/object drops above the
-- configured threshold, reference-loot owners, and vendors. The original
-- pfQuest default threshold is 1%, which we preserve here without adding a
-- new player-facing option.
local function ResolveItemSources(itemID)
  local result={}
  local seen={}
  local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)

  if sources and sources.Creature then
    for creatureID,chance in pairs(sources.Creature) do
      chance=tonumber(chance) or 0
      if chance>=MIN_DROP_CHANCE then
        AddUniqueSource(result,seen,"creature",creatureID,itemID,chance,false)
      end
    end
  end

  if sources and sources.GameObject then
    for objectID,chance in pairs(sources.GameObject) do
      chance=tonumber(chance) or 0
      if chance>=MIN_DROP_CHANCE and chance>0 then
        AddUniqueSource(result,seen,"gameObject",objectID,itemID,chance,false)
      end
    end
  end

  if sources and sources.Reference then
    for refID,chance in pairs(sources.Reference) do
      chance=tonumber(chance) or 0
      if chance>=MIN_DROP_CHANCE then
        local ref=QuestieOcto.DatabaseAPI:GetReferenceLootRaw(refID)
        if ref and ref["U"] then
          for creatureID in pairs(ref["U"]) do
            AddUniqueSource(result,seen,"creature",creatureID,itemID,chance,false)
          end
        end
        if ref and ref["O"] then
          for objectID in pairs(ref["O"]) do
            AddUniqueSource(result,seen,"gameObject",objectID,itemID,chance,false)
          end
        end
      end
    end
  end

  if sources and sources.Vendor then
    for creatureID in pairs(sources.Vendor) do
      AddUniqueSource(result,seen,"creature",creatureID,itemID,nil,true)
    end
  end

  return result
end

local function ItemIDFromLink(link)
  if not link then return nil end
  local _,_,id=string.find(link,"item:(%d+)")
  return tonumber(id)
end

local function PlayerHasItem(itemID)
  itemID=tonumber(itemID)
  if not itemID then return false end

  if GetContainerNumSlots and GetContainerItemLink then
    for bag=0,4 do
      local slots=GetContainerNumSlots(bag) or 0
      for slot=1,slots do
        if ItemIDFromLink(GetContainerItemLink(bag,slot))==itemID then return true end
      end
    end
  end

  if GetInventoryItemLink then
    for slot=1,19 do
      if ItemIDFromLink(GetInventoryItemLink("player",slot))==itemID then return true end
    end
  end

  return false
end

-- pfQuest only reacts to bag changes that affect registered quest-item
-- dependencies. Normal objective counts refresh the Tracker directly; map
-- objectives only rebuild when their todo/done semantics actually change.
local function CollectIRItemIDs()
  local tracked={}
  for questID in pairs(QuestieOcto.QuestLog.active or {}) do
    local q=QuestieOcto.QuestModel:Get(questID)
    if q and q.objectives and q.objectives.irItems then
      for _,itemID in pairs(q.objectives.irItems) do
        itemID=tonumber(itemID)
        if itemID and itemID>0 then tracked[itemID]=true end
      end
    end
  end
  return tracked
end

local function SnapshotIRPresence()
  local state={}
  local tracked=CollectIRItemIDs()
  for itemID in pairs(tracked) do
    state[itemID]=PlayerHasItem(itemID) and true or false
  end
  return state
end

local function RefreshIRPresence()
  O.irPresence=SnapshotIRPresence()
end

local function IRPresenceChanged()
  local previous=O.irPresence or {}
  local current=SnapshotIRPresence()

  for itemID,present in pairs(current) do
    if previous[itemID]~=present then
      O.irPresence=current
      return true
    end
  end
  for itemID in pairs(previous) do
    if current[itemID]==nil then
      O.irPresence=current
      return true
    end
  end

  O.irPresence=current
  return false
end

local function BuildIRTargets(q)
  local targets={}
  local skipCreature={}
  local skipObject={}

  for _,itemID in pairs(q.objectives.irItems or {}) do
    local requirement=QuestieOcto.DatabaseAPI:GetQuestItemRequirementRaw(itemID)
    if requirement then
      local hasItem=PlayerHasItem(itemID)
      for signedID in pairs(requirement) do
        signedID=tonumber(signedID)
        if signedID and signedID<0 then
          local id=math.abs(signedID)
          skipObject[id]=true
          if hasItem then
            table.insert(targets,{kind="gameObject",id=id,itemID=itemID,ir=true})
          end
        elseif signedID and signedID>0 then
          skipCreature[signedID]=true
          if hasItem then
            table.insert(targets,{kind="creature",id=signedID,itemID=itemID,ir=true})
          end
        end
      end
    end
  end

  return targets,skipCreature,skipObject
end

local function NormalizeLogType(typ)
  typ=string.lower(tostring(typ or ""))
  if typ=="monster" or typ=="creature" or typ=="kill" then return "creature" end
  if typ=="item" then return "item" end
  if typ=="object" or typ=="gameobject" then return "gameObject" end
  return typ
end

-- Sparse presentation-only corrections for capture/transform objectives where
-- the server awards quest credit against a temporary NPC entry that has no
-- natural spawn points. Keep the authoritative live objective ID for progress
-- and completion; only map/minimap guidance uses the actionable source NPC.
--
-- Plagued Lands (2118): Tortoise darkshore.cpp handles spell 9439 by changing
-- Rabid Thistle Bear (2164) into Captured Rabid Thistle Bear (11836), then
-- awards KilledMonsterCredit for 11836. The player must therefore find 2164,
-- while 11836 remains the correct completion target in the quest log/database.
local CREATURE_OBJECTIVE_SOURCE_OVERRIDES={
  [2118]={ [11836]=2164 },
}

local function PresentationCreatureSourceID(questID,objectiveID)
  local byQuest=CREATURE_OBJECTIVE_SOURCE_OVERRIDES[tonumber(questID)]
  local sourceID=byQuest and byQuest[tonumber(objectiveID)]
  return tonumber(sourceID) or tonumber(objectiveID)
end

local function Levenshtein(str1,str2)
  str1=string.lower(tostring(str1 or ""))
  str2=string.lower(tostring(str2 or ""))
  local len1=string.len(str1)
  local len2=string.len(str2)
  local matrix={}
  local cost=0
  if len1==0 then return len2 end
  if len2==0 then return len1 end
  if str1==str2 then return 0 end
  for i=0,len1 do matrix[i]={}; matrix[i][0]=i end
  for j=0,len2 do matrix[0][j]=j end
  for i=1,len1 do
    for j=1,len2 do
      if string.byte(str1,i)==string.byte(str2,j) then cost=0 else cost=1 end
      matrix[i][j]=math.min(matrix[i-1][j]+1,matrix[i][j-1]+1,matrix[i-1][j-1]+cost)
    end
  end
  return matrix[len1][len2]
end

local function MergeState(entry,row)
  entry.objectiveIndex=row.index
  entry.objectiveID=row.objectiveID
  entry.objectiveText=row.text
  entry.rawObjectiveText=row.rawText or row.text
  entry.objectiveType=row.type
  entry.current=row.current
  entry.required=row.required
  entry.complete=row.complete and true or false
  return entry
end

local function ObjectiveTypesMatch(logType,dbType)
  local kind=NormalizeLogType(logType)
  if kind=="creature" then return dbType=="monster" end
  if kind=="gameObject" then return dbType=="object" end
  if kind=="item" then return dbType=="item" end
  return false
end

local function EntryFromLiveObjectiveID(q,row)
  local id=tonumber(row and row.objectiveID)
  if not q or not id then return nil end
  local typ=string.lower(tostring(row.type or ""))
  local creatureMatch=nil
  local objectMatch=nil
  local itemMatch=nil

  for i=1,table.getn(q.objectiveData or {}) do
    local entry=q.objectiveData[i]
    if entry and tonumber(entry.id)==id then
      if entry.kind=="creature" then creatureMatch=entry
      elseif entry.kind=="gameObject" then objectMatch=entry
      elseif entry.kind=="item" then itemMatch=entry end
    end
  end

  if typ=="item" then return itemMatch end
  if typ=="object" or typ=="gameobject" then return objectMatch end
  if typ=="monster" or typ=="creature" or typ=="kill" then
    -- pfQuest notes that Vanilla can return "monster" for some object-style
    -- objectives; let the live ClassicAPI ID disambiguate the namespace.
    return creatureMatch or objectMatch
  end
  return creatureMatch or objectMatch or itemMatch
end

local function CandidateName(kind,id)
  if kind=="creature" then return QuestieOcto.DatabaseAPI:GetCreatureName(id) end
  if kind=="gameObject" then return QuestieOcto.DatabaseAPI:GetObjectName(id) end
  if kind=="item" then return QuestieOcto.DatabaseAPI:GetItemName(id) end
  return nil
end

local function CandidateIDs(q,kind)
  if kind=="creature" then return q.objectives.creature or {} end
  if kind=="gameObject" then return q.objectives.gameObject or {} end
  if kind=="item" then return q.objectives.item or {} end
  return {}
end

local function BestSameTypeCandidate(q,kind,row,used)
  local ids=CandidateIDs(q,kind)
  local count=0
  local onlyID=nil
  for _,id in pairs(ids) do
    if not used[kind..":"..tostring(id)] then count=count+1; onlyID=id end
  end
  if count==1 then O.stats.single=O.stats.single+1; return onlyID end

  local bestID=nil
  local bestDistance=999999
  local desc=row.text or ""
  for _,id in pairs(ids) do
    if not used[kind..":"..tostring(id)] then
      local name=CandidateName(kind,id)
      if name then
        local distance=Levenshtein(desc,name)
        if distance<bestDistance then bestDistance=distance; bestID=id end
      end
    end
  end
  if bestID then O.stats.fuzzy=O.stats.fuzzy+1 end
  return bestID
end

function O:ResolveQuest(questID)
  if not DependenciesReady() then return nil end
  local q=QuestieOcto.QuestModel:Get(questID)
  if not q then return nil end

  local state=QuestieOcto.QuestLog.active[questID]
  local result={questID=questID,creature={},gameObject={},item={},areaTrigger={}}

  -- Failed quests retain their tracker state but have no active objective map
  -- guidance until the server permits a retry.
  if state and state.failed then return result end

  local used={}
  local irTargets,skipCreature,skipObject=BuildIRTargets(q)

  for _,row in pairs(state and state.objectives or {}) do
    local direct=EntryFromLiveObjectiveID(q,row)
    local kind=nil
    local id=nil

    if direct then
      -- pfQuest-style primary path: use ClassicAPI's live leaderboard entity
      -- ID so server objective ordering cannot attach one boss's progress to
      -- another boss's map node.
      kind=direct.kind
      id=direct.id
      O.stats.direct=O.stats.direct+1
    else
      -- Questie 5/6-style fallback: when no trustworthy live ID is available,
      -- match the native objective text against same-type DB candidates rather
      -- than assuming objective array positions are identical.
      kind=NormalizeLogType(row.type)
      id=BestSameTypeCandidate(q,kind,row,used)
      if id then O.stats.fallback=O.stats.fallback+1 end
    end

    if id and kind then
      local key=kind..":"..tostring(id)
      if not used[key] then
        used[key]=true
        O.stats.mapped=O.stats.mapped+1

        if kind=="creature" and not skipCreature[id] then
          local sourceID=PresentationCreatureSourceID(questID,id)
          table.insert(result.creature,MergeState({
            kind="creature",id=sourceID,objectiveTargetID=id,
            sourceOverride=(sourceID~=id) and true or nil
          },row))
          O.stats.creature=O.stats.creature+1
        elseif kind=="gameObject" and not skipObject[id] then
          table.insert(result.gameObject,MergeState({kind="gameObject",id=id},row))
          O.stats.object=O.stats.object+1
        elseif kind=="item" then
          table.insert(result.item,MergeState({
            itemID=id,name=QuestieOcto.DatabaseAPI:GetItemName(id),sources=ResolveItemSources(id)
          },row))
          O.stats.item=O.stats.item+1
        end
      else
        O.stats.unmapped=O.stats.unmapped+1
      end
    else
      O.stats.unmapped=O.stats.unmapped+1
    end
  end

  -- Preserve DB-only/special candidates without inventing progress state.
  for i=1,table.getn(q.objectiveData or {}) do
    local entry=q.objectiveData[i]
    local key=entry.kind..":"..tostring(entry.id)
    if not used[key] then
      if entry.kind=="creature" and not skipCreature[entry.id] then
        table.insert(result.creature,{kind="creature",id=entry.id})
        O.stats.creature=O.stats.creature+1
      elseif entry.kind=="gameObject" and not skipObject[entry.id] then
        table.insert(result.gameObject,{kind="gameObject",id=entry.id})
        O.stats.object=O.stats.object+1
      elseif entry.kind=="item" then
        table.insert(result.item,{
          itemID=entry.id,name=QuestieOcto.DatabaseAPI:GetItemName(entry.id),sources=ResolveItemSources(entry.id)
        })
        O.stats.item=O.stats.item+1
      end
    end
  end

  -- Quest-bound area triggers are not generic exploration/fog helpers. pfQuest
  -- resolves obj["A"] through ClassicAPI and shows those points while the quest
  -- is active. Keep them separate from ordinary leaderboard entity matching:
  -- Vanilla does not provide a reliable creature/object-style namespace for
  -- these event triggers, and pfQuest likewise keeps them until the quest as a
  -- whole is complete.
  for _,areaTriggerID in pairs(q.objectives.areaTrigger or {}) do
    local info=QuestieOcto.API and QuestieOcto.API.GetAreaTriggerInfo
      and QuestieOcto.API:GetAreaTriggerInfo(areaTriggerID) or nil
    if info then
      table.insert(result.areaTrigger,{
        kind="areaTrigger",
        id=tonumber(areaTriggerID),
        mapID=info.areaID,
        x=info.mapX,
        y=info.mapY
      })
      O.stats.areaTrigger=(O.stats.areaTrigger or 0)+1
    end
  end

  -- IR target guidance appears only while the required quest item is in the
  -- player's bags/equipment. Its corresponding ordinary U/O objective is
  -- suppressed even while the item is missing, matching pfQuest SearchQuestID.
  for _,target in pairs(irTargets) do
    if target.kind=="creature" then
      table.insert(result.creature,target)
      O.stats.creature=O.stats.creature+1
    else
      table.insert(result.gameObject,target)
      O.stats.object=O.stats.object+1
    end
    O.stats.irTargets=O.stats.irTargets+1
  end

  return result
end

function O:Rebuild()
  if not DependenciesReady() then
    self.ready=false
    self.pending=true
    self.stats.dependencyWaits=(self.stats.dependencyWaits or 0)+1
    return
  end
  if self.running then self.pending=true; return end

  self.pending=false
  self.stats.rebuilds=(self.stats.rebuilds or 0)+1
  self.generation=self.generation+1
  local generation=self.generation
  self.byQuest={}
  self.ready=false
  self.running=true
  ResetStats()

  local ids={}
  for questID in pairs(QuestieOcto.QuestLog.active or {}) do table.insert(ids,questID) end
  table.sort(ids)

  local pos=1
  local function step()
    if generation~=O.generation then return end
    local count=0
    while pos<=table.getn(ids) and count<32 do
      local questID=ids[pos]
      pos=pos+1
      local resolved=O:ResolveQuest(questID)
      if resolved then O.byQuest[questID]=resolved end
      O.stats.quests=O.stats.quests+1
      count=count+1
    end
    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"objective-resolve")
      return
    end
    O.running=false
    O.ready=true
    RefreshIRPresence()
    QuestieOcto:SendMessage("OBJECTIVES_READY")
    if O.pending then O.pending=false; O:Schedule(0.01) end
  end
  QuestieOcto.Scheduler:Enqueue(step,"objective-resolve")
end

function O:Schedule(delay)
  self.pending=true
  QuestieOcto.Scheduler:After(delay or 0.15,function()
    if O.pending then O.pending=false; O:Rebuild() end
  end,"objectives-rebuild")
end

function O:RefreshQuests(changedQuests)
  if not self.ready or self.running or not DependenciesReady() then
    self:Schedule(0.01)
    return
  end

  local ids={}
  for questID in pairs(changedQuests or {}) do table.insert(ids,tonumber(questID)) end
  table.sort(ids)
  if table.getn(ids)==0 then return end

  self.running=true
  self.generation=self.generation+1
  local generation=self.generation
  local pos=1

  local function step()
    if generation~=O.generation then return end
    local count=0
    while pos<=table.getn(ids) and count<8 do
      local questID=ids[pos]
      pos=pos+1
      if QuestieOcto.QuestLog.active[questID] then
        O.byQuest[questID]=O:ResolveQuest(questID)
      else
        O.byQuest[questID]=nil
      end
      count=count+1
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"objective-refresh-quests")
      return
    end

    O.running=false
    RefreshIRPresence()
    QuestieOcto:SendMessage("OBJECTIVES_CHANGED",changedQuests)
    if O.pending then O.pending=false; O:Schedule(0.01) end
  end

  QuestieOcto.Scheduler:Enqueue(step,"objective-refresh-quests")
end

function O:OnDependencyChanged(changedQuests)
  if type(changedQuests)=="table" and self.ready then
    self:RefreshQuests(changedQuests)
  else
    self:Schedule(0.01)
  end
end

QuestieOcto:RegisterMessage("QUEST_MAP_STATE_CHANGED",O,"OnDependencyChanged")
QuestieOcto:RegisterMessage("DATABASE_API_READY",O,"OnDependencyChanged")

local bagFrame=CreateFrame("Frame","QuestieOctoObjectiveItemEvents",UIParent)
bagFrame:RegisterEvent("BAG_UPDATE")
bagFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
bagFrame:SetScript("OnEvent",function()
  if event=="UNIT_INVENTORY_CHANGED" and arg1 and arg1~="player" then return end

  -- Coalesce the entire loot/equipment burst, then touch the objective pipeline
  -- only if an IR quest-item dependency actually appeared/disappeared.
  QuestieOcto.Scheduler:After(0.25,function()
    if IRPresenceChanged() then
      local affected={}
      for questID in pairs(QuestieOcto.QuestLog.active or {}) do
        local q=QuestieOcto.QuestModel:Get(questID)
        if q and q.objectives and q.objectives.irItems and table.getn(q.objectives.irItems)>0 then
          affected[questID]=true
        end
      end
      if next(affected) then O:RefreshQuests(affected) end
    end
  end,"objective-ir-bag-check")
end)
