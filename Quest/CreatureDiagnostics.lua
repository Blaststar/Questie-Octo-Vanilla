QuestieOcto.CreatureDiagnostics = QuestieOcto.CreatureDiagnostics or {}
local D = QuestieOcto.CreatureDiagnostics

local function RankText(rank)
  rank=tonumber(rank)
  if rank==4 then return "Rare" end
  if rank==2 then return "Rare Elite" end
  if rank==1 then return "Elite" end
  if rank==3 then return "Boss" end
  return rank and ("Rank "..tostring(rank)) or "Normal/unknown"
end

local function RespawnText(seconds)
  seconds=tonumber(seconds)
  if not seconds or seconds<=0 then return "unknown" end
  if math.mod(seconds,60)==0 then
    return "~"..tostring(math.floor(seconds/60)).." min"
  end
  return "~"..tostring(math.floor(seconds/60)).."m "..tostring(math.mod(seconds,60)).."s"
end

local function ArrayContains(t,value)
  for _,v in pairs(t or {}) do
    if tonumber(v)==tonumber(value) then return true end
  end
  return false
end

function D:Trace(creatureID)
  creatureID=tonumber(creatureID)
  if not creatureID then
    QuestieOcto:Print("usage: /qo creature <id>")
    return
  end

  if not QuestieOcto.DatabaseAPI:IsReady() then
    QuestieOcto:Print("creature diagnostic: database not ready")
    return
  end

  local raw=QuestieOcto.DatabaseAPI:GetCreatureRaw(creatureID)
  if not raw then
    QuestieOcto:Print("creature "..tostring(creatureID).." not found")
    return
  end

  local name=QuestieOcto.DatabaseAPI:GetCreatureName(creatureID)
  local rank=QuestieOcto.DatabaseAPI:GetCreatureRank(creatureID)
  local respawn=QuestieOcto.DatabaseAPI:GetCreatureRespawnSeconds(creatureID)
  local maps=QuestieOcto.DatabaseAPI:GetCreatureMapIDs(creatureID)

  QuestieOcto:Print("Creature "..tostring(creatureID).." "..tostring(name)..
    " ["..RankText(rank).."] level="..tostring(QuestieOcto.DatabaseAPI:GetCreatureLevel(creatureID)))
  QuestieOcto:Print("respawn="..RespawnText(respawn)..
    " rawSeconds="..tostring(respawn)..
    " maps="..table.concat(maps,",")..
    " staticDBOnly=true")

  QuestieOcto:Print("scanning quest-start relationships gently...")

  local ids=QuestieOcto.DatabaseAPI:GetQuestIDs()
  local pos=1
  local direct=0
  local itemStarts=0

  local function step()
    local count=0

    while pos<=table.getn(ids) and count<250 do
      local questID=ids[pos]
      pos=pos+1
      local q=QuestieOcto.QuestModel:Get(questID)

      if q then
        if ArrayContains(q.starts.creature,creatureID) then
          direct=direct+1
          local ok,reason=QuestieOcto.AvailableQuests:EvaluateQuest(questID,false)
          QuestieOcto:Print("direct start: ["..tostring(q.level).."] "..tostring(q.title)..
            " id="..tostring(questID).." playerAvailable="..tostring(ok)..
            " reason="..tostring(reason))
        end

        for _,itemID in pairs(q.starts.item or {}) do
          local sources=QuestieOcto.DatabaseAPI:GetItemSources(itemID)
          local chance=sources and sources.Creature and sources.Creature[creatureID]
          if chance then
            itemStarts=itemStarts+1
            local ok,reason=QuestieOcto.AvailableQuests:EvaluateQuest(questID,false)
            QuestieOcto:Print("item start: item="..tostring(itemID).." "..QuestieOcto.DatabaseAPI:GetItemName(itemID)..
              " chance="..tostring(chance).."% -> quest "..tostring(questID).." "..tostring(q.title))
            QuestieOcto:Print("playerAvailable="..tostring(ok).." reason="..tostring(reason)..
              " completed="..tostring(QuestieOcto.Completion:IsComplete(questID)))
          end
        end
      end

      count=count+1
    end

    if pos<=table.getn(ids) then
      QuestieOcto.Scheduler:Enqueue(step,"creature-diagnostic")
    else
      QuestieOcto:Print("creature diagnostic complete direct/itemStarts="..
        tostring(direct).."/"..tostring(itemStarts))
    end
  end

  QuestieOcto.Scheduler:Enqueue(step,"creature-diagnostic")
end
