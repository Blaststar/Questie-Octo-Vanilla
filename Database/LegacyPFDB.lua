QuestieOcto.Database = QuestieOcto.Database or {}
local D = QuestieOcto.Database

D.ready = false
D.running = false
D.jobs = {}
D.jobIndex = 1
D.stats = { merged=0, jobs=0 }

local DATASETS = {
  "items", "quests", "quests-itemreq", "objects", "units",
  "zones", "professions", "areatrigger", "refloot", "minimap", "meta"
}

local TEXT_DATASETS = {
  "items", "quests", "objects", "units", "zones", "professions"
}

local FIELD_MERGE_DATASETS = { items=true, quests=true, objects=true, units=true }

local function AddMergeJob(target,patch,name,mode)
  if target and patch then
    table.insert(D.jobs,{ target=target, patch=patch, name=name, mode=mode or "replace" })
  end
end

local function BuildMergeJobs()
  D.jobs = {}
  D.jobIndex = 1
  D.stats = { merged=0, jobs=0 }

  if not pfDB then return end

  -- Locale-independent Turtle patches always merge into the core data first.
  for _,name in pairs(DATASETS) do
    local bucket=pfDB[name]
    if bucket and bucket["data-turtle"] and bucket["data"] then
      AddMergeJob(bucket["data"],bucket["data-turtle"],name..".data",FIELD_MERGE_DATASETS[name] and "fields" or "replace")
    end
  end

  -- English is the only packaged presentation database.
  for _,name in pairs(TEXT_DATASETS) do
    local bucket=pfDB[name]
    if bucket then
      AddMergeJob(bucket["enUS"],bucket["enUS-turtle"],name..".enUS","locale")
    end
  end

  if pfDB["minimap-turtle"] and pfDB["minimap"] then
    AddMergeJob(pfDB["minimap"],pfDB["minimap-turtle"],"minimap")
  end
  if pfDB["meta-turtle"] and pfDB["meta"] then
    AddMergeJob(pfDB["meta"],pfDB["meta-turtle"],"meta")
  end

  D.stats.jobs=table.getn(D.jobs)
end

local function StartJob(job)
  if job.started then return end
  -- Never materialize every patch key in one frame. Some Turtle datasets are
  -- large enough that the old key-array construction caused a visible startup
  -- hitch before the incremental merge even began.
  job.started=true
  job.cursor=nil
end

local function ProcessJob(job)
  StartJob(job)
  local count=0

  while count<256 do
    local key,value=next(job.patch,job.cursor)
    if key==nil then return true end
    job.cursor=key

    if type(value)=="string" and value=="_" then
      job.target[key]=nil
    elseif (job.mode=="fields" or job.mode=="locale") and type(value)=="table" and type(job.target[key])=="table" then
      local base=job.target[key]
      for field,fieldValue in pairs(value) do
        if type(fieldValue)=="string" and fieldValue=="_" then
          base[field]=nil
        else
          base[field]=fieldValue
        end
      end
    else
      job.target[key]=value
    end

    D.stats.merged=D.stats.merged+1
    count=count+1
  end

  return false
end

local function Finalize()
  if pfDB.items then pfDB.items.loc=pfDB.items.enUS end
  if pfDB.units then pfDB.units.loc=pfDB.units.enUS end
  if pfDB.objects then pfDB.objects.loc=pfDB.objects.enUS end
  if pfDB.quests then pfDB.quests.loc=pfDB.quests.enUS end
  if pfDB.zones then pfDB.zones.loc=pfDB.zones.enUS end
  if pfDB.professions then pfDB.professions.loc=pfDB.professions.enUS end

  for _,name in pairs(TEXT_DATASETS) do
    local bucket=pfDB[name]
    if bucket then bucket["enUS-turtle"]=nil end
  end

  -- Apply the sparse Tortoise/Octo enrichment only after the base + Turtle
  -- field-by-field merge is final. This restores server fields the compact
  -- pfQuest runtime database intentionally discarded without replacing the
  -- working pfQuest quest records wholesale.
  if QuestieOcto.Enrichment then
    if not QuestieOcto.Enrichment:Apply() then
      D.running=false
      D.ready=false
      QuestieOcto:Error("quest-truth enrichment could not be applied")
      return
    end
  end

  if QuestieOcto.QuestModel and QuestieOcto.QuestModel.Clear then
    QuestieOcto.QuestModel:Clear()
  end

  D.running=false
  D.ready=true
  QuestieOcto:SendMessage("DATABASE_READY")
end

function D:Start()
  if self.ready or self.running then return end

  if not pfDB then
    QuestieOcto:Error("raw quest database did not load")
    return
  end

  BuildMergeJobs()
  self.running=true

  local function step()
    local job=D.jobs[D.jobIndex]
    if not job then
      Finalize()
      return
    end

    if ProcessJob(job) then D.jobIndex=D.jobIndex+1 end
    QuestieOcto.Scheduler:Enqueue(step,"database-merge")
  end

  QuestieOcto.Scheduler:Enqueue(step,"database-merge")
end

local function Count(t)
  local n=0
  if t then for _ in pairs(t) do n=n+1 end end
  return n
end

function D:GetActiveLocale()
  return "enUS"
end

function D:Counts()
  if not pfDB then return 0,0,0,0 end
  return
    Count(pfDB.quests and pfDB.quests.data),
    Count(pfDB.items and pfDB.items.data),
    Count(pfDB.units and pfDB.units.data),
    Count(pfDB.objects and pfDB.objects.data)
end

function D:GetRawQuest(id)
  if not self.ready then return nil end
  return pfDB.quests and pfDB.quests.data and pfDB.quests.data[id]
end

function D:GetQuestLocale(id)
  if not self.ready then return nil end
  return pfDB.quests and pfDB.quests.loc and pfDB.quests.loc[id]
end

function D:GetRawItem(id)
  if not self.ready then return nil end
  return pfDB.items and pfDB.items.data and pfDB.items.data[id]
end

function D:GetRawUnit(id)
  if not self.ready then return nil end
  return pfDB.units and pfDB.units.data and pfDB.units.data[id]
end

function D:GetRawObject(id)
  if not self.ready then return nil end
  return pfDB.objects and pfDB.objects.data and pfDB.objects.data[id]
end
