QuestieOcto.API = QuestieOcto.API or {}
local A = QuestieOcto.API

A.valid = false
A.missing = {}
A.optional = {}

local function Has(tableValue, functionName)
  return tableValue and type(tableValue[functionName])=="function"
end

function A:Validate()
  self.missing = {}

  local required = {
    { "C_QuestLog.GetQuestIDForLogIndex", C_QuestLog, "GetQuestIDForLogIndex" },
    { "C_QuestLog.GetLogIndexForQuestID", C_QuestLog, "GetLogIndexForQuestID" },
    { "C_QuestLog.IsOnQuest", C_QuestLog, "IsOnQuest" },
    { "C_Map.GetBestMapForUnit", C_Map, "GetBestMapForUnit" },
    { "C_GossipInfo.GetAvailableQuests", C_GossipInfo, "GetAvailableQuests" },
    { "C_CreatureInfo.GetCreatureID", C_CreatureInfo, "GetCreatureID" },
    { "C_GameObjectInfo.GetGameObjectInfoByID", C_GameObjectInfo, "GetGameObjectInfoByID" },
    { "C_Item.GetItemNameByID", C_Item, "GetItemNameByID" },
  }

  for _,req in pairs(required) do
    if not Has(req[2],req[3]) then table.insert(self.missing,req[1]) end
  end

  self.valid = table.getn(self.missing)==0

  self.optional = {
    coroutines = coroutine and type(coroutine.create)=="function",
    hooksecurefunc = type(hooksecurefunc)=="function",
    tooltipUnit = GameTooltip and type(GameTooltip.GetUnitGUID)=="function",
    tooltipObject = GameTooltip and type(GameTooltip.GetGameObject)=="function",
    tooltipItem = GameTooltip and type(GameTooltip.GetItem)=="function",
    gossipActive = Has(C_GossipInfo,"GetActiveQuests"),
    questDetails = Has(C_QuestLog,"GetQuestDetails"),
    questObjectives = Has(C_QuestLog,"GetQuestObjectives"),
    questsCompleted = type(GetQuestsCompleted)=="function" or Has(C_QuestLog,"GetQuestsCompleted"),
    queryQuestsCompleted = type(QueryQuestsCompleted)=="function",
    questFlaggedCompleted = type(IsQuestFlaggedCompleted)=="function" or Has(C_QuestLog,"IsQuestFlaggedCompleted"),
    mapWorldSize = Has(C_Map,"GetMapWorldSize"),
  }

  return self.valid
end

function A:GetQuestIDForLogIndex(index)
  if not self.valid then return nil end
  return C_QuestLog.GetQuestIDForLogIndex(index)
end

-- Questie-facing normalized quest-log info.
--
-- Questie 5.2.3/6.0.0 and Questie 3.3.5 all consume the normalized fields
--   title, level, tag, isHeader, isCollapsed, isComplete, frequency, questID.
--
-- The raw client signature differs by expansion. For our actual target
-- Interface 11200, the supplied pfQuest Vanilla compatibility layer confirms:
--   title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(index)
-- There is NO suggestedGroup return on Vanilla 1.12.
--
-- Questie 3.3.5's raw suggestedGroup handling is a WotLK-era compatibility
-- detail, so applying it directly to Turtle 11200 shifts completion by one
-- field and makes completed quests look incomplete.
function A:GetQuestLogInfo(index)
  if not GetQuestLogTitle then return nil end

  local _,_,_,client=GetBuildInfo()
  client=tonumber(client) or 11200

  local title,level,tag,isHeader,isCollapsed,isComplete,isDaily,rawQuestID

  if client<=11200 then
    title,level,tag,isHeader,isCollapsed,isComplete=GetQuestLogTitle(index)
  else
    local suggestedGroup
    title,level,tag,suggestedGroup,isHeader,isCollapsed,isComplete,isDaily,rawQuestID=GetQuestLogTitle(index)
  end

  local questID=self:GetQuestIDForLogIndex(index) or tonumber(rawQuestID)

  return {
    title=title,
    level=level,
    tag=tag,
    isHeader=isHeader and true or false,
    isCollapsed=isCollapsed and true or false,
    isComplete=isComplete,
    isDaily=isDaily,
    questID=questID
  }
end

function A:GetLogIndexForQuestID(questID)
  if not self.valid then return nil end
  return C_QuestLog.GetLogIndexForQuestID(questID)
end

function A:IsOnQuest(questID)
  if not self.valid then return false end
  return C_QuestLog.IsOnQuest(questID) and true or false
end

function A:GetBestMapForPlayer()
  if not self.valid then return nil end
  return C_Map.GetBestMapForUnit("player")
end


function A:GetQuestObjectives(questID,questLogIndex)
  if C_QuestLog and type(C_QuestLog.GetQuestObjectives)=="function" then
    -- Questie 3.3.5's Vanilla compatibility implementation accepts the log
    -- index as a second argument; modern-style implementations ignore extras.
    return C_QuestLog.GetQuestObjectives(questID,questLogIndex)
  end
  return nil
end


function A:QueryQuestsCompleted()
  if type(QueryQuestsCompleted)~="function" then return false end
  local ok=pcall(QueryQuestsCompleted)
  return ok and true or false
end

function A:GetQuestsCompleted()
  if type(GetQuestsCompleted)=="function" then
    local ok,result=pcall(GetQuestsCompleted)
    if ok and type(result)=="table" then return result end

    -- Some compatibility layers use the older "fill table" form.
    local target={}
    ok=pcall(GetQuestsCompleted,target)
    if ok and next(target) then return target end
  end

  if C_QuestLog and type(C_QuestLog.GetQuestsCompleted)=="function" then
    local ok,result=pcall(C_QuestLog.GetQuestsCompleted)
    if ok and type(result)=="table" then return result end
  end

  return nil
end

function A:IsQuestFlaggedCompleted(questID)
  if type(IsQuestFlaggedCompleted)=="function" then
    local ok,result=pcall(IsQuestFlaggedCompleted,questID)
    if ok then return result and true or false end
  end

  if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted)=="function" then
    local ok,result=pcall(C_QuestLog.IsQuestFlaggedCompleted,questID)
    if ok then return result and true or false end
  end

  return nil
end
