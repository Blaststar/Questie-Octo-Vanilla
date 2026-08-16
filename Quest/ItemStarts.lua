QuestieOcto.ItemStarts = QuestieOcto.ItemStarts or {}
local I = QuestieOcto.ItemStarts

I.byQuest={}
I.ready=false
I.running=false
I.generation=0
local function NewStats()
  return { quests=0, starterItems=0, creatureSources=0, objectSources=0 }
end

I.stats=NewStats()

-- Quest-starting items can intentionally be rare. A positive recorded
-- drop chance is enough to make the source useful guidance; filtering at 1%
-- caused legitimate starters such as Captain Sander's Treasure Map (0.75%)
-- to vanish after the full item-start resolver replaced the zone bootstrap.
local function PositiveDropChance(chance)
  chance=tonumber(chance) or 0
  return chance>0
end

function I:IsPositiveDropChance(chance)
  return PositiveDropChance(chance)
end

local function RecountStats(byQuest)
  local stats=NewStats()
  for _,resolved in pairs(byQuest or {}) do
    stats.quests=stats.quests+1
    for _,item in pairs(resolved.items or {}) do
      stats.starterItems=stats.starterItems+1
      stats.creatureSources=stats.creatureSources+table.getn(item.creatureSources or {})
      stats.objectSources=stats.objectSources+table.getn(item.objectSources or {})
    end
  end
  return stats
end

local function AddCreature(entry,seen,creatureID,chance,vendor)
  local key=tostring(creatureID)
  if seen[key] then return end
  seen[key]=true
  table.insert(entry.creatureSources,{
    kind="creature",id=creatureID,chance=chance,vendor=vendor and true or false,
    rank=QuestieOcto.DatabaseAPI:GetCreatureRank(creatureID),
    faction=QuestieOcto.DatabaseAPI:GetCreatureFaction(creatureID)
  })
end

local function AddObject(entry,seen,objectID,chance)
  local key=tostring(objectID)
  if seen[key] then return end
  seen[key]=true
  table.insert(entry.objectSources,{kind="gameObject",id=objectID,chance=chance})
end

local function ResolveSources(entry,itemID)
  local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)
  local seenCreature={}
  local seenObject={}

  if sources and sources.Creature then
    for creatureID,chance in pairs(sources.Creature) do
      chance=tonumber(chance) or 0
      if PositiveDropChance(chance) then AddCreature(entry,seenCreature,creatureID,chance,false) end
    end
  end

  if sources and sources.GameObject then
    for objectID,chance in pairs(sources.GameObject) do
      chance=tonumber(chance) or 0
      if PositiveDropChance(chance) then AddObject(entry,seenObject,objectID,chance) end
    end
  end

  if sources and sources.Reference then
    for refID,chance in pairs(sources.Reference) do
      chance=tonumber(chance) or 0
      if PositiveDropChance(chance) then
        local ref=QuestieOcto.DatabaseAPI:GetReferenceLootRaw(refID)
        if ref and ref["U"] then
          for creatureID in pairs(ref["U"]) do AddCreature(entry,seenCreature,creatureID,chance,false) end
        end
        if ref and ref["O"] then
          for objectID in pairs(ref["O"]) do AddObject(entry,seenObject,objectID,chance) end
        end
      end
    end
  end

  if sources and sources.Vendor then
    for creatureID in pairs(sources.Vendor) do AddCreature(entry,seenCreature,creatureID,nil,true) end
  end
end

function I:ResolveQuest(questID)
  local q=QuestieOcto.QuestModel:Get(questID)
  if not q or not q.starts.item then return nil end

  local result={ questID=questID, items={} }

  for _,itemID in pairs(q.starts.item) do
    local entry={
      itemID=itemID,
      name=QuestieOcto.DatabaseAPI:GetItemName(itemID),
      creatureSources={},
      objectSources={}
    }

    ResolveSources(entry,itemID)
    table.insert(result.items,entry)
  end

  return result
end

function I:Rebuild()
  if not QuestieOcto.AvailableQuests.ready then return end

  self.generation=self.generation+1
  local generation=self.generation
  self.running=true
  if not self.ready then self.ready=false end

  -- Transactional rebuild: keep the published item-start cache alive until the
  -- complete replacement is resolved. This prevents downstream consumers from
  -- seeing a temporary empty item-start set during filter changes.
  local replacement={}
  local ids={}
  for questID in pairs(QuestieOcto.AvailableQuests.available) do
    local q=QuestieOcto.QuestModel:Get(questID)
    if q and q.starts.item then table.insert(ids,questID) end
  end
  table.sort(ids)

  local pos=1
  local function step()
    if generation~=I.generation then return end
    local count=0
    while pos<=table.getn(ids) and count<64 do
      local questID=ids[pos]
      pos=pos+1
      local resolved=I:ResolveQuest(questID)
      if resolved then replacement[questID]=resolved end
      count=count+1
    end
    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"itemstart-resolve")
      return
    end

    I.byQuest=replacement
    I.stats=RecountStats(replacement)
    I.running=false
    I.ready=true
    QuestieOcto:SendMessage("ITEM_STARTS_READY")
  end
  QuestieOcto.Scheduler:Enqueue(step,"itemstart-resolve")
end

local function NormalizeChangedQuests(changedQuests)
  local changed={}
  for questID in pairs(changedQuests or {}) do
    questID=tonumber(questID)
    if questID and questID>0 then changed[questID]=true end
  end
  return changed
end

function I:RefreshAvailability(changedQuests)
  if not self.ready or self.running then
    self:Rebuild()
    return
  end

  local changed=NormalizeChangedQuests(changedQuests)
  if not next(changed) then
    QuestieOcto:SendMessage("ITEM_STARTS_CHANGED",changed)
    return
  end

  self.generation=self.generation+1
  local generation=self.generation
  self.running=true

  -- Shallow-copy the published quest cache and resolve only quests that crossed
  -- the availability boundary. Publish once at the end so Nodes never observes
  -- a half-updated item-start set.
  local replacement={}
  for questID,resolved in pairs(self.byQuest or {}) do replacement[questID]=resolved end

  local ids={}
  for questID in pairs(changed) do table.insert(ids,questID) end
  table.sort(ids)
  local pos=1

  local function step()
    if generation~=I.generation then return end
    local count=0
    while pos<=table.getn(ids) and count<32 do
      local questID=ids[pos]
      pos=pos+1
      replacement[questID]=nil

      if QuestieOcto.AvailableQuests.available[questID] then
        local q=QuestieOcto.QuestModel:Get(questID)
        if q and q.starts.item then
          local resolved=I:ResolveQuest(questID)
          if resolved then replacement[questID]=resolved end
        end
      end
      count=count+1
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"itemstart-availability-patch")
      return
    end

    I.byQuest=replacement
    I.stats=RecountStats(replacement)
    I.running=false
    I.ready=true
    QuestieOcto:SendMessage("ITEM_STARTS_CHANGED",changed)
  end

  QuestieOcto.Scheduler:Enqueue(step,"itemstart-availability-patch")
end

function I:OnAvailableReady(changedQuests)
  if self.ready and changedQuests then
    self:RefreshAvailability(changedQuests)
  else
    self:Rebuild()
  end
end

QuestieOcto:RegisterMessage("AVAILABLE_QUESTS_READY",I,"OnAvailableReady")
