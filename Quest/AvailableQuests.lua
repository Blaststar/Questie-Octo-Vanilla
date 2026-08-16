-- Questie-Octo AvailableQuests service.
-- pfQuest/Tortoise defines quest truth; Questie-Octo only presents the result.

QuestieOcto.AvailableQuests = QuestieOcto.AvailableQuests or {}
local A = QuestieOcto.AvailableQuests

A.ready=false
A.running=false
A.available={}
A.queue={}
A.pos=1
A.generation=0
A.stats={}
A.reputationCache={}
A.hardcoreCache=nil

local function NewStats()
  return {
    scanned=0,available=0,completed=0,active=0,disabled=0,
    level=0,prerequisite=0,exclusive=0,race=0,class=0,
    hardcore=0,skill=0,reputation=0,timed=0,event=0,repeatable=0,pvp=0,noStarter=0
  }
end

local function ResetStats()
  A.stats=NewStats()
end

local RACE_BITS={
  Human=1,Orc=2,Dwarf=4,NightElf=8,Scourge=16,
  Tauren=32,Gnome=64,Troll=128,Goblin=256,HighElf=512
}

local CLASS_BITS={
  WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,
  SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024
}

local function MaskContains(mask,flag)
  mask=tonumber(mask or 0) or 0
  flag=tonumber(flag or 0) or 0
  if mask==0 then return true end
  if flag==0 then return false end
  return math.mod(math.floor(mask/flag),2)==1
end

local function PlayerRaceBit()
  local _,token=UnitRace("player")
  if token=="BloodElf" then
    -- Turtle-derived clients can expose the High Elf slot through the old
    -- BloodElf token. On Octo that token means High Elf only on Alliance.
    return UnitFactionGroup("player")=="Alliance" and 512 or 0
  end
  return RACE_BITS[token] or 0
end

local function PlayerClassBit()
  local _,token=UnitClass("player")
  return CLASS_BITS[token] or 0
end

local function PlayerSkillRank(skillID)
  skillID=tonumber(skillID)
  if not skillID then return nil end

  if C_SpellBook and type(C_SpellBook.GetSkillLineRank)=="function" then
    local ok,rank=pcall(C_SpellBook.GetSkillLineRank,skillID)
    rank=ok and tonumber(rank) or nil
    if rank then return rank end
  end

  local skillName=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetProfessionName and QuestieOcto.DatabaseAPI:GetProfessionName(skillID)
  if not skillName or not GetNumSkillLines or not GetSkillLineInfo then return nil end

  for i=1,(GetNumSkillLines() or 0) do
    local name,_,_,rank=GetSkillLineInfo(i)
    if name==skillName then return tonumber(rank) or 1 end
  end
  return nil
end

function A:ClearReputationCache()
  for id in pairs(self.reputationCache) do self.reputationCache[id]=nil end
end

function A:GetPlayerReputation(factionID)
  factionID=tonumber(factionID)
  if not factionID then return nil end
  local cached=self.reputationCache[factionID]
  if cached~=nil then return cached end

  local value=nil
  if type(GetFactionInfoByID)=="function" then
    local ok,_,_,_,_,_,v=pcall(GetFactionInfoByID,factionID)
    if ok then value=tonumber(v) end
  end

  if value==nil and C_Reputation and type(C_Reputation.GetFactionDataByID)=="function" then
    local ok,data=pcall(C_Reputation.GetFactionDataByID,factionID)
    if ok and data and data.currentStanding~=nil then value=tonumber(data.currentStanding) end
  end

  if value==nil and GetNumFactions and GetFactionInfo then
    if ExpandFactionHeader then pcall(ExpandFactionHeader,0) end
    for i=1,(GetNumFactions() or 0) do
      local _,_,_,_,_,v,_,_,_,_,_,_,_,id=GetFactionInfo(i)
      if tonumber(id)==factionID then value=tonumber(v) break end
    end
  end

  if value~=nil then self.reputationCache[factionID]=value end
  return value
end

function A:ClearChallengeCache()
  self.hardcoreCache=nil
end

function A:IsHardcorePlayer()
  if self.hardcoreCache~=nil then return self.hardcoreCache end
  if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellName) then return nil end

  local tabs=GetNumSpellTabs()
  if not tabs or tabs<1 then return nil end
  local bookType=BOOKTYPE_SPELL or "spell"

  for tab=1,tabs do
    local _,_,offset,numSpells=GetSpellTabInfo(tab)
    if offset and numSpells then
      for slot=offset+1,offset+numSpells do
        local name=GetSpellName(slot,bookType)
        if name=="Hardcore" then
          self.hardcoreCache=true
          return true
        end
      end
    end
  end

  self.hardcoreCache=false
  return false
end

local function HasStarter(q)
  return
    (q.starts.creature and next(q.starts.creature)) or
    (q.starts.gameObject and next(q.starts.gameObject)) or
    (q.starts.item and next(q.starts.item))
end

local function PrerequisitesSatisfied(q)
  if not q.preQuestSingle and not q.preQuestActive and not q.preQuestAll then return true end

  local satisfied=false
  local activeSet=nil
  local allSet=nil

  if q.preQuestActive then
    activeSet={}
    for _,id in pairs(q.preQuestActive) do
      activeSet[id]=true
      if QuestieOcto.QuestLog:IsOnQuest(id) then satisfied=true end
    end
  end

  if q.preQuestAll then
    allSet={}
    for _,group in pairs(q.preQuestAll) do
      local groupComplete=true
      for _,id in pairs(group) do
        allSet[id]=true
        if not QuestieOcto.Completion:IsRewardedForPrerequisite(id) then
          groupComplete=false
        end
      end
      if groupComplete then satisfied=true end
    end
  end

  if q.preQuestSingle then
    for _,id in pairs(q.preQuestSingle) do
      if (not activeSet or not activeSet[id]) and (not allSet or not allSet[id]) then
        if QuestieOcto.Completion:IsRewardedForPrerequisite(id) then satisfied=true end
      end
    end
  end

  return satisfied
end

local function BlockedByExclusive(q)
  if not q.exclusive or not q.exclusiveTo then return false end
  for _,id in pairs(q.exclusiveTo) do
    if id~=q.id and QuestieOcto.Completion:HasBlockingStatus(id) then return true end
  end
  return false
end

local function HasOtherTimedQuest(questID)
  for activeID in pairs(QuestieOcto.QuestLog.active or {}) do
    if activeID~=questID then
      local active=QuestieOcto.QuestModel:Get(activeID)
      if active and active.timed then return true end
    end
  end
  return false
end

local function Track(self,name,enabled)
  if not enabled then return end
  local stats=self.scanStats or self.stats
  stats[name]=(stats[name] or 0)+1
end

function A:EvaluateQuest(questID,trackStats)
  local q=QuestieOcto.QuestModel:Get(questID)
  if not q then return false,"noModel" end

  if q.disabled then
    Track(self,"disabled",trackStats)
    return false,"disabled"
  end

  -- Darkmoon is a verified live exception to several stale pfQuest/Turtle
  -- quest-row details.  The same quest-givers and hand-in quests are reused in
  -- Elwynn and Mulgore even though raw rows are split between event 4 and 5.
  -- The player's live Elwynn screenshots also confirm these NPCs offer every
  -- level-eligible tier regardless of the old DMF repMax metadata.  Keep the
  -- ordinary safety gates (completion, race/class, level, repeatable setting)
  -- but do not let stale Darkmoon reputation/chain metadata suppress them.
  local eventService=QuestieOcto.EventAvailability
  local verifiedDarkmoon=eventService and eventService:IsVerifiedDarkmoonQuest(q)
      and eventService:IsDarkmoonFaireActive() and true or false

  if QuestieOcto.QuestLog:IsOnQuest(questID) then
    Track(self,"active",trackStats)
    return false,"active"
  end

  if QuestieOcto.Completion:IsQuestBlockedByCompletion(questID,q) then
    Track(self,"completed",trackStats)
    return false,"completed"
  end

  if not verifiedDarkmoon and q.nextChain and QuestieOcto.Completion:HasBlockingStatus(q.nextChain) then
    Track(self,"prerequisite",trackStats)
    return false,"nextChain"
  end

  if not verifiedDarkmoon and BlockedByExclusive(q) then
    Track(self,"exclusive",trackStats)
    return false,"exclusive"
  end

  if not verifiedDarkmoon and not PrerequisitesSatisfied(q) then
    Track(self,"prerequisite",trackStats)
    return false,"prerequisite"
  end

  if q.raceMask and not MaskContains(q.raceMask,PlayerRaceBit()) then
    Track(self,"race",trackStats)
    return false,"race"
  end

  if q.classMask and not MaskContains(q.classMask,PlayerClassBit()) then
    Track(self,"class",trackStats)
    return false,"class"
  end

  if q.hardcore then
    local hardcore=self:IsHardcorePlayer()
    if not hardcore then
      Track(self,"hardcore",trackStats)
      return false,"hardcore"
    end
  end

  if q.requiredSkill then
    local rank=PlayerSkillRank(q.requiredSkill)
    if not rank or rank<(q.requiredSkillValue or 1) then
      Track(self,"skill",trackStats)
      return false,"skill"
    end
  end

  if q.repMinFaction and not verifiedDarkmoon then
    local rep=self:GetPlayerReputation(q.repMinFaction)
    if rep==nil or rep<(q.repMinValue or 0) then
      Track(self,"reputation",trackStats)
      return false,"repMin"
    end
  end

  if q.repMaxFaction and not verifiedDarkmoon then
    local rep=self:GetPlayerReputation(q.repMaxFaction)
    if rep==nil or rep>=(q.repMaxValue or 0) then
      Track(self,"reputation",trackStats)
      return false,"repMax"
    end
  end

  -- Some quests are conditionally exposed by scripted world interactions rather
  -- than normal NPC availability. Do not advertise them as static pickups. If
  -- the player actually accepts one, the Quest Log path still handles it.
  if q.conditionalOffer then
    return false,"conditional"
  end

  local settings=QuestieOcto.MinimapSettings

  -- Conservative beta event policy. The pfQuest/Turtle `event` field mixes
  -- true festivals with permanent release/content gates, so presentation
  -- classification and runtime availability must stay separate. Ordinary
  -- content-gate events (for example event 159 cloth turn-ins) pass through
  -- normal quest eligibility. Festival-style events require BOTH the user's
  -- Show Event Quests toggle and positive evidence that the event is active.
  -- Active quests are handled by the Quest Log path before this function, so
  -- accepted objectives/turn-ins remain visible even when this gate is closed.
  if q.eventID then
    eventService=eventService or QuestieOcto.EventAvailability
    local gated=eventService and eventService:ShouldGateQuest(q.eventID) or true
    if gated then
      if not settings:Get("showEventQuests") then
        Track(self,"event",trackStats)
        return false,"eventHidden"
      end
      if eventService and eventService:IsStandbyEvent(q.eventID) then
        Track(self,"event",trackStats)
        return false,"eventStandby"
      end
      if not (eventService and eventService:IsActiveForQuest(q)) then
        Track(self,"event",trackStats)
        return false,"eventInactive"
      end
    end
  end

  local level=UnitLevel("player") or 1
  local showLowLevel=settings:Get("showLowLevelQuests") and true or false

  -- lvl is presentation/triviality; it is NOT the high-level acceptance gate.
  -- When low-level quests are enabled, players may optionally bound how far
  -- below their current level Questie-Octo exposes them. The value 35 is the
  -- options UI's "All" sentinel and preserves the historical unrestricted
  -- Show Low-Level Quests behavior.
  if q.level and q.level>0 then
    if not showLowLevel and q.level<level-4 then
      Track(self,"level",trackStats)
      return false,"lowLevel"
    elseif showLowLevel then
      local below=tonumber(settings:Get("lowLevelQuestRange")) or 35
      if below<35 and q.level<level-below then
        Track(self,"level",trackStats)
        return false,"lowLevel"
      end
    end
  end

  -- Actual upper eligibility uses the minimum required level. Future quests are
  -- not exposed through a separate Level Above Player setting.
  if q.requiredLevel and q.requiredLevel>level then
    Track(self,"level",trackStats)
    return false,"minLevel"
  end

  if q.pvp and not settings:Get("showPvPRelatedQuests") then
    Track(self,"pvp",trackStats)
    return false,"pvpHidden"
  end

  if q.repeatable and not settings:Get("showRepeatableQuests") then
    Track(self,"repeatable",trackStats)
    return false,"repeatable"
  end

  -- MaxLevel is a separate hard server acceptance cap.
  if q.maximumLevel and q.maximumLevel>0 and level>q.maximumLevel then
    Track(self,"level",trackStats)
    return false,"maxLevel"
  end

  if q.timed and HasOtherTimedQuest(questID) then
    Track(self,"timed",trackStats)
    return false,"timed"
  end

  if not HasStarter(q) then
    Track(self,"noStarter",trackStats)
    return false,"noStarter"
  end

  return true,"available"
end

local RACE_LABELS={
  {1,"Human"},{2,"Orc"},{4,"Dwarf"},{8,"Night Elf"},{16,"Undead"},
  {32,"Tauren"},{64,"Gnome"},{128,"Troll"},{256,"Goblin"},{512,"High Elf"}
}
local CLASS_LABELS={
  {1,"Warrior"},{2,"Paladin"},{4,"Hunter"},{8,"Rogue"},{16,"Priest"},
  {64,"Shaman"},{128,"Mage"},{256,"Warlock"},{1024,"Druid"}
}

local function MaskLabels(mask,labels)
  local out={}
  for i=1,table.getn(labels) do
    if MaskContains(mask,labels[i][1]) then table.insert(out,labels[i][2]) end
  end
  return table.concat(out,", ")
end

local function QuestLabel(id)
  id=tonumber(id)
  local title=id and QuestieOcto.DatabaseAPI:GetQuestTitle(id) or nil
  if title then return "["..tostring(id).."] "..title end
  return "Quest "..tostring(id or "?")
end

local function FactionLabel(id)
  id=tonumber(id)
  if id and type(GetFactionInfoByID)=="function" then
    local ok,name=pcall(GetFactionInfoByID,id)
    if ok and name then return name end
  end
  return "faction "..tostring(id or "?")
end

local function PrerequisiteSummary(q)
  local alternatives={}
  local activeAlternatives={}

  local activeSet={}
  for _,id in pairs(q.preQuestActive or {}) do
    activeSet[id]=true
    if not QuestieOcto.QuestLog:IsOnQuest(id) then
      table.insert(activeAlternatives,QuestLabel(id))
    end
  end

  local allSet={}
  for _,group in pairs(q.preQuestAll or {}) do
    local missing={}
    for _,id in pairs(group or {}) do
      allSet[id]=true
      if not QuestieOcto.Completion:IsRewardedForPrerequisite(id) then
        table.insert(missing,QuestLabel(id))
      end
    end
    if table.getn(missing)>0 then
      table.insert(alternatives,table.concat(missing," + "))
    end
  end

  for _,id in pairs(q.preQuestSingle or {}) do
    if not activeSet[id] and not allSet[id] and not QuestieOcto.Completion:IsRewardedForPrerequisite(id) then
      table.insert(alternatives,QuestLabel(id))
    end
  end

  -- pfQuest pre is OR semantics: any listed single quest, active predecessor,
  -- or complete all-of group can satisfy the prerequisite. Keep that meaning
  -- while using concise player-facing wording.
  local combined={}
  for i=1,table.getn(alternatives) do table.insert(combined,alternatives[i]) end
  for i=1,table.getn(activeAlternatives) do table.insert(combined,activeAlternatives[i].." (active)") end

  if table.getn(combined)==0 then return "Prerequisite not met." end
  if table.getn(combined)==1 then return "Requires: "..combined[1].."." end
  return "Requires one of: "..table.concat(combined,"; ").."."
end

local function ReputationStanding(value)
  value=tonumber(value) or 0
  if value>=42000 then return "Exalted" end
  if value>=21000 then return "Revered" end
  if value>=9000 then return "Honored" end
  if value>=3000 then return "Friendly" end
  if value>=0 then return "Neutral" end
  if value>=-3000 then return "Unfriendly" end
  if value>=-6000 then return "Hostile" end
  return "Hated"
end

function A:GetUnavailableReason(questID)
  questID=tonumber(questID)
  local q=questID and QuestieOcto.QuestModel:Get(questID) or nil
  if not q then return "Not present in the current quest database." end

  local ok,code=self:EvaluateQuest(questID,false)
  if ok then return nil end
  if code=="disabled" then return "Not available in game." end
  if code=="active" then return "Already active." end
  if code=="completed" then return "Already completed." end
  if code=="nextChain" then return "Already progressed past this quest." end
  if code=="exclusive" then
    local blocked={}
    for _,id in pairs(q.exclusiveTo or {}) do
      if id~=q.id and QuestieOcto.Completion:HasBlockingStatus(id) then table.insert(blocked,QuestLabel(id)) end
    end
    if table.getn(blocked)>0 then return "Blocked by: "..table.concat(blocked,", ").."." end
    return "Blocked by another quest choice."
  end
  if code=="prerequisite" then return PrerequisiteSummary(q) end
  if code=="race" then
    local allowed=MaskLabels(q.raceMask,RACE_LABELS)
    return allowed~="" and ("Requires race: "..allowed..".") or "Race requirement not met."
  end
  if code=="class" then
    local allowed=MaskLabels(q.classMask,CLASS_LABELS)
    return allowed~="" and ("Requires class: "..allowed..".") or "Class requirement not met."
  end
  if code=="hardcore" then return "Requires Hardcore." end
  if code=="skill" then
    local name=QuestieOcto.DatabaseAPI.GetProfessionName and QuestieOcto.DatabaseAPI:GetProfessionName(q.requiredSkill) or nil
    return "Requires "..tostring(name or ("skill "..tostring(q.requiredSkill))).." "..tostring(q.requiredSkillValue or 1).."."
  end
  if code=="repMin" then
    return "Requires "..ReputationStanding(q.repMinValue).." with "..FactionLabel(q.repMinFaction).."."
  end
  if code=="repMax" then
    return "Requires below "..ReputationStanding(q.repMaxValue).." with "..FactionLabel(q.repMaxFaction).."."
  end
  if code=="conditional" then return tostring(q.conditionalOffer or "Requires a world interaction.") end
  if code=="eventHidden" then
    local name=QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:GetEventName(q.eventID) or ("event "..tostring(q.eventID))
    return "Event quests are hidden."
  end
  if code=="eventStandby" then
    local name=QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:GetEventName(q.eventID) or ("event "..tostring(q.eventID))
    return "Event availability is not verified."
  end
  if code=="eventInactive" then
    local name=QuestieOcto.EventAvailability and QuestieOcto.EventAvailability:GetEventName(q.eventID) or ("event "..tostring(q.eventID))
    return tostring(name).." is not active."
  end
  if code=="lowLevel" then return "Hidden as a low-level quest." end
  if code=="minLevel" then return "Requires level "..tostring(q.requiredLevel or 0).."." end
  if code=="maxLevel" then return "Maximum level "..tostring(q.maximumLevel or 0).."." end
  if code=="repeatable" then return "Repeatable quests are hidden." end
  if code=="pvpHidden" then return "PVP related quests are hidden." end
  if code=="timed" then return "Another timed quest is active." end
  if code=="noStarter" then return "No quest starter is known." end
  if code=="noModel" then return "Not present in the current quest database." end
  return "Unavailable — exact server-side requirement unknown ("..tostring(code or "unknown")..")."
end

function A:IsQuestAvailable(questID)
  local ok=self:EvaluateQuest(questID,true)
  return ok
end

function A:Recalculate(fastRefresh)
  if not QuestieOcto.DatabaseAPI:IsReady()
     or not QuestieOcto.Completion.ready
     or not QuestieOcto.QuestLog.snapshot then
    return
  end

  self.generation=self.generation+1
  local generation=self.generation

  -- Transactional refresh: keep the currently published availability set
  -- visible while the replacement is scanned. The old implementation cleared
  -- the live table before the async scan completed, which made map pins blink
  -- off/on whenever a filtering option changed.
  self.pendingAvailable={}
  self.queue=QuestieOcto.DatabaseAPI:GetQuestIDs()
  self.pos=1
  self.running=true
  if not self.ready then self.ready=false end
  self.scanStats=NewStats()

  local function step()
    if generation~=A.generation then return end
    if not QuestieOcto.Completion.ready then
      A.running=false
      A.ready=false
      return
    end

    local count=0
    local batch=fastRefresh and 100 or 60
    while A.pos<=table.getn(A.queue) and count<batch do
      local id=A.queue[A.pos]
      A.pos=A.pos+1
      A.scanStats.scanned=A.scanStats.scanned+1

      if A:IsQuestAvailable(id) then
        A.pendingAvailable[id]=true
        A.scanStats.available=A.scanStats.available+1
      end

      count=count+1
    end

    if A.pos<=table.getn(A.queue) then
      QuestieOcto.Scheduler:Enqueue(step,"available-scan")
      return
    end

    -- Publish once, atomically, only after the complete scan is ready.
    -- Also publish the exact availability delta. Filter-only changes (such as
    -- Low-Level Quest range) can then patch only quests that actually crossed
    -- the visibility boundary instead of rebuilding/rebinding every map pin.
    local previous=A.available or {}
    local replacement=A.pendingAvailable or {}
    local changed={}
    local id
    for id in pairs(previous) do
      if not replacement[id] then changed[id]=true end
    end
    for id in pairs(replacement) do
      if not previous[id] then changed[id]=true end
    end

    A.available=replacement
    A.stats=A.scanStats or A.stats
    A.pendingAvailable=nil
    A.scanStats=nil
    A.running=false
    A.ready=true
    QuestieOcto:SendMessage("AVAILABLE_QUESTS_READY",changed)
  end

  QuestieOcto.Scheduler:Enqueue(step,"available-scan")
end

function A:RemoveQuest(questID)
  questID=tonumber(questID)
  if not questID then return end

  if self.available[questID] then
    self.available[questID]=nil
    if self.stats.available and self.stats.available>0 then
      self.stats.available=self.stats.available-1
    end
  end
  if self.pendingAvailable then self.pendingAvailable[questID]=nil end

  if QuestieOcto.ItemStarts and QuestieOcto.ItemStarts.byQuest then
    QuestieOcto.ItemStarts.byQuest[questID]=nil
  end

  if QuestieOcto.PreparedMap and QuestieOcto.PreparedMap.RemoveQuest then
    QuestieOcto.PreparedMap:RemoveQuest(questID)
  elseif QuestieOcto.PreparedMap then
    QuestieOcto.PreparedMap:BumpStateRevision("quest-remove")
  end

  if QuestieOcto.Map and QuestieOcto.Map.RemoveQuest then
    QuestieOcto.Map:RemoveQuest(questID)
  end
end

function A:FastRefresh()
  self:Recalculate(true)
end

function A:Schedule(fastRefresh,delay)
  QuestieOcto.Scheduler:After(delay or (fastRefresh and 0.01 or 0.10),function()
    A:Recalculate(fastRefresh and true or false)
  end,"available-recalc")
end

function A:GetAvailableSet()
  return self.available
end

function A:OnFoundationInputChanged()
  if not self.ready then self:Schedule(true,0.01) else self:Schedule(false,0.10) end
end

QuestieOcto:RegisterMessage("DATABASE_API_READY",A,"OnFoundationInputChanged")
QuestieOcto:RegisterMessage("COMPLETION_READY",A,"OnFoundationInputChanged")
QuestieOcto:RegisterMessage("QUEST_ELIGIBILITY_STATE_CHANGED",A,"OnFoundationInputChanged")

local stateFrame=CreateFrame("Frame","QuestieOctoQuestEligibilityEvents",UIParent)
stateFrame:RegisterEvent("PLAYER_LEVEL_UP")
stateFrame:RegisterEvent("SKILL_LINES_CHANGED")
stateFrame:RegisterEvent("UPDATE_FACTION")
stateFrame:RegisterEvent("SPELLS_CHANGED")
stateFrame:SetScript("OnEvent",function()
  if event=="UPDATE_FACTION" then A:ClearReputationCache() end
  if event=="SPELLS_CHANGED" then A:ClearChallengeCache() end

  if event=="PLAYER_LEVEL_UP" then
    A:FastRefresh()
    QuestieOcto.Scheduler:After(0.30,function() A:FastRefresh() end,"questie-level-stable-refresh")
  else
    A:Schedule(true,0.05)
  end
end)
