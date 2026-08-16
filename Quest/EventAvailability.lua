-- Questie-Octo runtime event availability resolver.
--
-- The pfQuest/Turtle quest `event` field is membership metadata, but Turtle
-- also uses game_event rows as permanent release/content gates. Questie-Octo
-- therefore classifies event availability explicitly. Beta 1.1 keeps verified
-- schedules/content gates and puts every unknown event association on standby.

QuestieOcto.EventAvailability = QuestieOcto.EventAvailability or {}
local E=QuestieOcto.EventAvailability

E.activeEvents=E.activeEvents or {}
E.observationsLoaded=E.observationsLoaded or false
E.lastPolicySignature=E.lastPolicySignature
E.policyElapsed=0
E.timestampCache=E.timestampCache or {}

local function CalendarRule(eventID)
  return QuestieOcto.CalendarEventRules and QuestieOcto.CalendarEventRules[tonumber(eventID)] or nil
end

local DARKMOON_EVENTS={ [4]=true,[5]=true,[23]=true,[24]=true }

-- Logical runtime event identity. Event 4 and event 5 are location-flavoured
-- Darkmoon database tags, not separate quest-availability universes. Normalize
-- both to event 4 everywhere availability/presentation is evaluated; callers
-- that need the authoritative value can use q.rawEventID.
local function LogicalEventID(eventID)
  eventID=tonumber(eventID)
  if eventID==5 then return 4 end
  return eventID
end

function E:GetLogicalEventID(eventID)
  return LogicalEventID(eventID)
end

-- Live-verified Darkmoon quest-giver set.  Turtle reuses these same NPCs at
-- both Elwynn (map 12) and Mulgore (map 215), while the pfQuest quest rows
-- inconsistently split their shared quests between event IDs 4 and 5.
-- Treat quests started by these NPCs as one logical Darkmoon offer set.
local VERIFIED_DARKMOON_STARTERS={
  [14823]=true, -- Silas Darkmoon
  [14828]=true, -- Gelvas Grimegate
  [14829]=true, -- Yebb Neblegear
  [14832]=true, -- Kerri Hicks
  [14833]=true, -- Chronos
  [14841]=true, -- Rinling
}

-- Beta 1.1 event policy:
--   * verified non-seasonal/content gates stay ordinary quest metadata;
--   * verified seasonal events use an explicit schedule;
--   * everything else is on standby and cannot publish an available marker.
--
-- These non-seasonal IDs were positively identified from the supplied Turtle
-- server data as release/patch/content gates rather than festivals. In
-- particular event 159 is the cloth-turn-in release gate, so the normal cloth
-- quests remain yellow and Additional Runecloth remains independently blue when
-- its repeatable flag is set.
local VERIFIED_NONSEASONAL_EVENTS={
  [156]=true, -- DM release: recipes/misc item
  [158]=true, -- 1.10 patch: recipes
  [159]=true, -- DM release: cloth turning NPC
  [160]=true, -- 1.10 patch: t0.5 quest chain
  [163]=true, -- 1.6 patch: BWL attunement
  [164]=true, -- 1.9 patch: quests
  [172]=true, -- Molten Core attunement compatibility event
}

-- Narrow, independently scheduled events that are known well enough to keep.
-- They are separate from the manually curated annual festival calendar.
local VERIFIED_TIMED_EVENTS={ [14]=true,[15]=true,[21]=true }

local function EventData(eventID)
  return QuestieOcto.EventScheduleData and QuestieOcto.EventScheduleData[tonumber(eventID)] or nil
end

local function ObservationDB()
  QuestieOctoGlobalDB=QuestieOctoGlobalDB or {}
  QuestieOctoGlobalDB.eventObservations=QuestieOctoGlobalDB.eventObservations or {}
  return QuestieOctoGlobalDB.eventObservations
end

local function RealmNow()
  if type(time)~="function" or type(date)~="function" then return nil end
  local now=time()
  if type(GetGameTime)~="function" then return now end

  local localDate=date("*t",now)
  local realmHour,realmMinute=GetGameTime()
  realmHour=tonumber(realmHour); realmMinute=tonumber(realmMinute)
  if not localDate or not realmHour or not realmMinute then return now end

  local localMinutes=(tonumber(localDate.hour) or 0)*60+(tonumber(localDate.min) or 0)
  local realmMinutes=realmHour*60+realmMinute
  local delta=realmMinutes-localMinutes
  if delta>720 then delta=delta-1440 end
  if delta<-720 then delta=delta+1440 end
  return now+delta*60
end

local function RealmDate()
  local now=RealmNow()
  if not now or type(date)~="function" then return nil end
  return date("*t",now)
end

local function ParseWallTimestamp(value)
  if type(value)~="string" or value=="" or string.sub(value,1,4)=="0000" then return nil end
  local matchStart,matchEnd,y,mo,d,h,mi,s=string.find(value,"^(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)$")
  y=tonumber(y); mo=tonumber(mo); d=tonumber(d); h=tonumber(h); mi=tonumber(mi); s=tonumber(s)
  if not y or y<1 or not mo or not d then return nil end
  if type(time)~="function" then return nil end
  return time({year=y,month=mo,day=d,hour=h or 0,min=mi or 0,sec=s or 0})
end

local function EventEpochs(eventID,data)
  local cached=E.timestampCache[eventID]
  if cached then return cached[1],cached[2] end
  local a=ParseWallTimestamp(data and data.start)
  local b=ParseWallTimestamp(data and data.finish)
  E.timestampCache[eventID]={a,b}
  return a,b
end

local function ObservationExpiry()
  if type(time)~="function" then return nil end
  if type(GetGameTime)=="function" then
    local hour,minute=GetGameTime()
    hour=tonumber(hour); minute=tonumber(minute)
    if hour and minute then
      local remaining=1440-(hour*60+minute)
      if remaining<=0 then remaining=1440 end
      return time()+(remaining*60)+300
    end
  end
  return time()+(12*60*60)
end

function E:LoadObservations()
  if self.observationsLoaded then return end
  self.observationsLoaded=true
  if type(time)~="function" then return end
  local now=time()
  local db=ObservationDB()
  for eventID,expiry in pairs(db) do
    eventID=tonumber(eventID) or eventID
    expiry=tonumber(expiry)
    if expiry and expiry>now then self.activeEvents[eventID]=true else db[eventID]=nil end
  end
end

-- Turtle Darkmoon Faire schedule verified in-game and anchored permanently:
--   2026-08-13 .. 2026-08-18 = Elwynn (event 4)
--   2026-08-19               = Mulgore construction (event 24)
--   2026-08-20 .. 2026-08-25 = Mulgore (event 5)
--   2026-08-26               = Elwynn construction (event 23)
-- then the 14-day cycle repeats indefinitely.
local function CivilDayNumber(y,m,d)
  y=tonumber(y); m=tonumber(m); d=tonumber(d)
  if not y or not m or not d then return nil end
  if m<=2 then y=y-1; m=m+12 end
  local era=math.floor(y/400)
  local yoe=y-era*400
  local doy=math.floor((153*(m-3)+2)/5)+d-1
  local doe=yoe*365+math.floor(yoe/4)-math.floor(yoe/100)+doy
  return era*146097+doe
end

function E:GetDarkmoonState()
  local d=RealmDate()
  if not d or not d.year or not d.month or not d.day then return nil end
  local today=CivilDayNumber(d.year,d.month,d.day)
  local anchor=CivilDayNumber(2026,8,13)
  if not today or not anchor then return nil end
  local cycle=math.mod(today-anchor,14)
  if cycle<0 then cycle=cycle+14 end
  if cycle<=5 then return 4 end       -- Elwynn active, Thu-Tue
  if cycle==6 then return 24 end      -- Mulgore construction, Wednesday
  if cycle<=12 then return 5 end      -- Mulgore active, Thu-Tue
  return 23                           -- Elwynn construction, Wednesday
end

function E:IsDarkmoonFaireActive()
  local state=self:GetDarkmoonState()
  return state==4 or state==5
end

function E:IsVerifiedDarkmoonQuest(q)
  if not q then return false end
  local rawEventID=tonumber(q.rawEventID or q.eventID)
  if rawEventID~=4 and rawEventID~=5 then return false end
  for _,npcID in pairs((q.starts and q.starts.creature) or {}) do
    if VERIFIED_DARKMOON_STARTERS[tonumber(npcID)] then return true end
  end
  return false
end

function E:GetCalendarState(eventID)
  local rule=CalendarRule(eventID)
  if not rule then return nil end
  local d=RealmDate()
  if not d or not d.month or not d.day then return nil end
  local current=(tonumber(d.month) or 0)*100+(tonumber(d.day) or 0)
  local first=(tonumber(rule.startMonth) or 0)*100+(tonumber(rule.startDay) or 0)
  local last=(tonumber(rule.endMonth) or 0)*100+(tonumber(rule.endDay) or 0)
  if first<=0 or last<=0 then return nil end
  if first<=last then return current>=first and current<=last end
  return current>=first or current<=last
end

function E:GetEventName(eventID)
  local rule=CalendarRule(eventID)
  if rule and rule.name then return rule.name end
  local data=EventData(eventID)
  return data and data.name or ("Event "..tostring(eventID))
end

function E:GetClassification(eventID)
  eventID=LogicalEventID(eventID)
  if not eventID then return "none" end
  if VERIFIED_NONSEASONAL_EVENTS[eventID] then return "nonseasonal" end
  if eventID==4 or eventID==5 then return "seasonal" end
  if CalendarRule(eventID) then return "seasonal" end
  if VERIFIED_TIMED_EVENTS[eventID] then return "seasonal" end
  return "standby"
end

function E:IsVerifiedNonSeasonal(eventID)
  return self:GetClassification(eventID)=="nonseasonal"
end

function E:IsStandbyEvent(eventID)
  return self:GetClassification(eventID)=="standby"
end

function E:ShouldGateQuest(eventID)
  local classification=self:GetClassification(eventID)
  return classification=="seasonal" or classification=="standby"
end

function E:IsPresentationEvent(eventID)
  -- Only positively identified seasonal events get green event presentation.
  -- Unknown event IDs are deliberately on standby rather than being guessed.
  return self:GetClassification(eventID)=="seasonal"
end

function E:IsPresentationEventForQuest(q)
  if not q or not q.eventID then return false end
  if self:GetClassification(q.eventID)~="seasonal" then return false end
  if QuestieOcto.QuestLog and QuestieOcto.QuestLog:IsOnQuest(q.id) then return true end
  local state=self:GetScheduledState(q.eventID)
  return state and true or false
end

function E:GetScheduledState(eventID)
  eventID=LogicalEventID(eventID)
  if not eventID then return nil end

  if VERIFIED_NONSEASONAL_EVENTS[eventID] then return true end

  if eventID==4 or eventID==5 then
    -- The authoritative pfQuest DB assigns many shared Darkmoon quests to one
    -- of the two location event IDs even though the same Faire NPC offers them
    -- at both Elwynn and Mulgore. Treat 4/5 as one logical active festival for
    -- quest eligibility/presentation; GetDarkmoonState still decides which
    -- physical Faire location is current. Wednesday construction (23/24) is off.
    local state=self:GetDarkmoonState()
    if not state then return nil end
    return state==4 or state==5
  end

  if eventID==23 or eventID==24 then
    local state=self:GetDarkmoonState()
    if not state then return nil end
    return state==eventID
  end

  local calendarState=self:GetCalendarState(eventID)
  if calendarState~=nil then return calendarState end

  -- All unclassified events are on standby for Beta 1.1. Runtime NPC/gossip
  -- observation is retained for diagnostics, but is intentionally not enough
  -- to promote an unknown event into the available-quest set.
  if not VERIFIED_TIMED_EVENTS[eventID] then return nil end

  local data=EventData(eventID)
  if not data or data.disabled then return false end
  if data.hardcoded then return nil end

  local now=RealmNow()
  if not now then return nil end
  local startAt,endAt=EventEpochs(eventID,data)
  if startAt and now<startAt then return false end
  if endAt and now>endAt then return false end

  local occurrence=tonumber(data.occurrence) or 0
  local length=tonumber(data.length) or 0
  if occurrence<=0 or length<=0 or not startAt then return nil end
  if length>=occurrence then return true end

  local elapsed=math.floor((now-startAt)/60)
  if elapsed<0 then return false end
  return math.mod(elapsed,occurrence)<length
end

function E:GetPolicyState(eventID)
  return self:GetScheduledState(eventID)
end

function E:GetPolicySignature()
  local chunks={"dm="..tostring(self:GetDarkmoonState()),"beta1-standby=true"}
  for eventID in pairs(QuestieOcto.CalendarEventRules or {}) do
    table.insert(chunks,tostring(eventID).."="..tostring(self:GetCalendarState(eventID)))
  end
  for _,eventID in ipairs({14,15,21}) do
    table.insert(chunks,tostring(eventID).."="..tostring(self:GetScheduledState(eventID)))
  end
  table.sort(chunks)
  return table.concat(chunks,";")
end

function E:RefreshPolicyState()
  -- Festival schedule changes affect available markers under the conservative
  -- beta policy. Publish only when the signature actually changes so the
  -- minute-level watchdog cannot churn maps/tracker state.
  local signature=self:GetPolicySignature()
  if signature==self.lastPolicySignature then return false end
  self.lastPolicySignature=signature
  if QuestieOcto.AvailableQuests and QuestieOcto.AvailableQuests.Schedule then
    QuestieOcto.AvailableQuests:Schedule(true,0.02)
  end
  return true
end

function E:MarkEventActive(eventID)
  eventID=LogicalEventID(eventID)
  if not eventID then return false end
  self:LoadObservations()
  local wasActive=self.activeEvents[eventID] and true or false
  if eventID==4 then self.activeEvents[5]=nil; ObservationDB()[5]=nil end
  if eventID==5 then self.activeEvents[4]=nil; ObservationDB()[4]=nil end
  self.activeEvents[eventID]=true
  local expiry=ObservationExpiry()
  if expiry then ObservationDB()[eventID]=expiry end
  -- Observations are diagnostic/supporting evidence only in Beta 1.1. Verified
  -- calendar events use their schedule and unknown events stay on standby, so
  -- merely seeing an NPC must not change quest availability. Darkmoon is also
  -- anchored to its verified 14-day cycle.
  return not wasActive
end

function E:ObserveQuestID(questID)
  questID=tonumber(questID)
  if not questID or not QuestieOcto.QuestModel then return false end
  local q=QuestieOcto.QuestModel:Get(questID)
  if q and q.eventID then return self:MarkEventActive(q.eventID) end
  return false
end

function E:IsActiveForQuest(q)
  if not q or not q.eventID then return true end
  local eventID=LogicalEventID(q.eventID)
  local classification=self:GetClassification(eventID)

  -- Active quests already accepted by the player always remain visible.
  if QuestieOcto.QuestLog and QuestieOcto.QuestLog:IsOnQuest(q.id) then
    self:MarkEventActive(eventID)
    return true
  end

  -- Verified content/release gates are not seasonal availability gates.
  if classification=="nonseasonal" then return true end

  -- Verified seasonal events are controlled only by their explicit schedule.
  -- Darkmoon uses the anchored 14-day Elwynn/Mulgore rule; event IDs 4 and 5
  -- are treated as one logical Faire while either location is active because
  -- the pfQuest data assigns shared Faire quests to both IDs. Curated annual
  -- festivals use CalendarEventRules; narrow events use their server timer.
  if classification=="seasonal" then
    local state=self:GetScheduledState(eventID)
    return state and true or false
  end

  -- Unknown/unverified event IDs are intentionally on standby for Beta 1.1.
  -- Observation does not promote them; this avoids flooding the map with stale
  -- festival or server-internal event quests.
  return false
end

local function ObserveRepeatability(entry,questID)
  if type(entry)~="table" or not questID then return end
  local repeatable=entry.repeatable or entry.isRepeatable or entry.isDaily or entry.isWeekly
  local frequency=tonumber(entry.frequency or entry.questFrequency)
  if frequency and frequency>1 then repeatable=true end
  if repeatable and QuestieOcto.QuestModel and QuestieOcto.QuestModel.MarkObservedRepeatable then
    QuestieOcto.QuestModel:MarkObservedRepeatable(questID)
  end
end

local function ObserveEntry(entry)
  if type(entry)=="table" then
    local questID=tonumber(entry.questID or entry.id or entry.questId)
    if questID then ObserveRepeatability(entry,questID); E:ObserveQuestID(questID) end
  elseif type(entry)=="number" then
    E:ObserveQuestID(entry)
  end
end

function E:ObserveGossip()
  if not C_GossipInfo or type(C_GossipInfo.GetAvailableQuests)~="function" then return end
  local ok,a,b,c,d,e,f,g,h=pcall(C_GossipInfo.GetAvailableQuests)
  if not ok then return end
  if type(a)=="table" then
    if a.questID or a.id or a.questId then ObserveEntry(a) else for _,entry in pairs(a) do ObserveEntry(entry) end end
  else
    local values={a,b,c,d,e,f,g,h}
    for _,entry in pairs(values) do ObserveEntry(entry) end
  end
end

function E:OnQuestLogChanged()
  for questID in pairs((QuestieOcto.QuestLog and QuestieOcto.QuestLog.active) or {}) do self:ObserveQuestID(questID) end
end

local f=CreateFrame("Frame","QuestieOctoEventAvailabilityEvents",UIParent)
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:SetScript("OnEvent",function()
  QuestieOcto.Scheduler:After(0.01,function()
    E:ObserveGossip()
    E:RefreshPolicyState()
  end,"event-availability-observe")
end)
f:SetScript("OnUpdate",function()
  E.policyElapsed=(E.policyElapsed or 0)+(arg1 or 0)
  if E.policyElapsed<60 then return end
  E.policyElapsed=0
  E:RefreshPolicyState()
end)

function E:OnDatabaseReady()
  self:LoadObservations()
  self:OnQuestLogChanged()
  self:RefreshPolicyState()
end

QuestieOcto:RegisterMessage("DATABASE_API_READY",E,"OnDatabaseReady")
QuestieOcto:RegisterMessage("QUEST_ACTIVE_SET_CHANGED",E,"OnQuestLogChanged")
