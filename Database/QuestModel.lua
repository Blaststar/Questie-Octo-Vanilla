-- Questie-Octo canonical quest model.
-- Questie-facing semantic model over pfQuest/Tortoise quest truth.

QuestieOcto.QuestModel = QuestieOcto.QuestModel or {}
local QM = QuestieOcto.QuestModel

QM.cache = {}

local function CopyArray(src)
  if not src then return nil end
  local out={}
  for _,v in pairs(src) do table.insert(out,v) end
  return out
end

local function CopyGroups(src)
  if not src then return nil end
  local out={}
  for _,group in pairs(src) do
    table.insert(out,CopyArray(group) or {})
  end
  return out
end

-- Supplied Questie 3.3.5 classic corrections:
-- these quests have their item objective before the normal category order.
local ITEM_OBJECTIVE_FIRST={
  [503]=true,
  [5088]=true,
}

-- Quests that are not normal static NPC offers. Questie 6 blacklists 7946
-- because Morja only exposes it after the Dark Iron Ale/Jubjub interaction.
local CONDITIONAL_OFFERS={
  [7946]="Requires Jubjub to be lured back with Dark Iron Ale.",
}

local function AddObjectiveData(list,kind,id)
  if not id then return end

  local typ=nil
  if kind=="creature" then typ="monster"
  elseif kind=="gameObject" then typ="object"
  elseif kind=="item" then typ="item"
  end

  table.insert(list,{
    kind=kind,
    type=typ,
    id=id
  })
end

local function BuildObjectiveData(questID,objectives)
  local result={}
  local itemFirst=ITEM_OBJECTIVE_FIRST[questID] and true or false

  if itemFirst then
    for i=1,table.getn(objectives.item or {}) do
      AddObjectiveData(result,"item",objectives.item[i])
    end
  end

  -- Questie 3.3.5/7/8 DB compiler category order.
  for i=1,table.getn(objectives.creature or {}) do
    AddObjectiveData(result,"creature",objectives.creature[i])
  end

  for i=1,table.getn(objectives.gameObject or {}) do
    AddObjectiveData(result,"gameObject",objectives.gameObject[i])
  end

  if not itemFirst then
    for i=1,table.getn(objectives.item or {}) do
      AddObjectiveData(result,"item",objectives.item[i])
    end
  end

  return result
end

function QM:Clear()
  self.cache={}
end


local function ObservedRepeatables()
  QuestieOctoGlobalDB=QuestieOctoGlobalDB or {}
  QuestieOctoGlobalDB.observedRepeatableQuests=QuestieOctoGlobalDB.observedRepeatableQuests or {}
  return QuestieOctoGlobalDB.observedRepeatableQuests
end

function QM:MarkObservedRepeatable(questID)
  questID=tonumber(questID)
  if not questID then return false end
  local db=ObservedRepeatables()
  if db[questID] then return false end
  db[questID]=true
  if self.cache[questID] then self.cache[questID].repeatable=true end
  if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.Schedule then
    QuestieOcto.AvailableQuests:Schedule(true,0.02)
  end
  return true
end

function QM:Get(questID)
  if self.cache[questID] then return self.cache[questID] end
  if not QuestieOcto.DatabaseAPI:IsReady() then return nil end

  local raw=QuestieOcto.DatabaseAPI:GetQuestRaw(questID)
  if not raw then return nil end

  local q={
    id=questID,
    title=QuestieOcto.DatabaseAPI:GetQuestTitle(questID),
    descriptionText=QuestieOcto.DatabaseAPI.GetQuestDescriptionText and QuestieOcto.DatabaseAPI:GetQuestDescriptionText(questID) or nil,
    objectiveText=QuestieOcto.DatabaseAPI.GetQuestObjectiveText and QuestieOcto.DatabaseAPI:GetQuestObjectiveText(questID) or nil,

    -- lvl is the displayed quest level. min/max are the actual server
    -- acceptance bounds and are deliberately kept separate.
    level=tonumber(raw["lvl"] or 0) or 0,
    requiredLevel=tonumber(raw["min"] or 0) or 0,
    maximumLevel=tonumber(raw["max"] or 0) or 0,

    -- Questie 6 uses quest Type 41 as the canonical PvP classification.
    -- This comes from the authoritative Turtle enrichment, including only
    -- verified local corrections for misclassified custom PvP quests.
    questType=tonumber(raw["type"] or 0) or 0,
    pvp=(tonumber(raw["type"] or 0) or 0)==41,

    raceMask=raw["race"],
    classMask=raw["class"],
    requiredSkill=raw["skill"],
    requiredSkillValue=tonumber(raw["skillValue"] or 1) or 1,
    repMinFaction=tonumber(raw["repMinFaction"]),
    repMinValue=tonumber(raw["repMinValue"] or 0) or 0,
    repMaxFaction=tonumber(raw["repMaxFaction"]),
    repMaxValue=tonumber(raw["repMaxValue"] or 0) or 0,

    -- Preserve the authoritative raw event association, but normalize the two
    -- Darkmoon Faire location IDs into one logical event for every runtime
    -- consumer. Turtle/pfQuest reuse the same Faire NPCs and quest offers at
    -- both Elwynn and Mulgore while many shared quest rows are inconsistently
    -- tagged as event 4 or event 5. Keeping rawEventID makes diagnostics lossless;
    -- eventID is the logical availability/presentation identity.
    rawEventID=tonumber(raw["event"]),
    eventID=(tonumber(raw["event"])==5 and 4 or tonumber(raw["event"])),
    event=raw["event"],
    repeatable=(raw["repeatable"] or ObservedRepeatables()[tonumber(questID)]) and true or false,
    hideAfterFirstCompletion=raw["hideAfterFirstCompletion"] and true or false,
    daily=raw["daily"] and true or false,
    yearly=raw["yearly"] and true or false,
    hardcore=raw["hardcore"] and true or false,
    timed=raw["timed"] and true or false,
    disabled=raw["disabled"] and true or false,
    conditionalOffer=CONDITIONAL_OFFERS[tonumber(questID)],
    exclusive=raw["exclusive"] and true or false,
    nextChain=tonumber(raw["nextChain"]),

    -- pfQuest's ordinary pre remains OR semantics. The enrichment restores
    -- signed active predecessors and negative ExclusiveGroup all-of groups
    -- separately so their server meaning is not flattened again.
    preQuestSingle=CopyArray(raw["pre"]),
    preQuestActive=CopyArray(raw["preActive"]),
    preQuestAll=CopyGroups(raw["preAll"]),

    -- close is only authoritative when the migrated server still marks the
    -- quest as a positive ExclusiveGroup member (q.exclusive=true).
    exclusiveTo=CopyArray(raw["close"]),

    starts={
      creature=raw["start"] and CopyArray(raw["start"]["U"]) or nil,
      gameObject=raw["start"] and CopyArray(raw["start"]["O"]) or nil,
      item=raw["start"] and CopyArray(raw["start"]["I"]) or nil,
    },

    finishes={
      creature=raw["end"] and CopyArray(raw["end"]["U"]) or nil,
      gameObject=raw["end"] and CopyArray(raw["end"]["O"]) or nil,
    },

    objectives={
      creature=raw["obj"] and CopyArray(raw["obj"]["U"]) or nil,
      gameObject=raw["obj"] and CopyArray(raw["obj"]["O"]) or nil,
      item=raw["obj"] and CopyArray(raw["obj"]["I"]) or nil,
      irItems=raw["obj"] and CopyArray(raw["obj"]["IR"]) or nil,
    },
  }

  -- IR items are intentionally NOT added to objectiveData. They are a
  -- pfQuest-special interaction relationship that becomes target guidance
  -- only while the player actually possesses the required item.
  q.objectiveData=BuildObjectiveData(questID,q.objectives)

  self.cache[questID]=q
  return q
end
