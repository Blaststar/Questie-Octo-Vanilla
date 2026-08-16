QuestieOcto.Scheduler = QuestieOcto.Scheduler or {}
local S = QuestieOcto.Scheduler

S.queue = {}
S.delayed = {}
S.elapsed = 0
S.interval = 0
S.executed = 0

function S:Enqueue(fn, label)
  if not fn then return end
  table.insert(self.queue, { fn=fn, label=label })
end

function S:After(delay, fn, key)
  if not fn then return end
  if key then
    self.delayed[key] = { remaining=delay or 0, fn=fn }
  else
    table.insert(self.delayed, { remaining=delay or 0, fn=fn })
  end
end

local function RunDelayed(self, delta)
  local remove = {}
  for k,v in pairs(self.delayed) do
    v.remaining = v.remaining - delta
    if v.remaining <= 0 then table.insert(remove, k) end
  end
  for _,k in pairs(remove) do
    local entry = self.delayed[k]
    self.delayed[k] = nil
    if entry and entry.fn then entry.fn() end
  end
end

function S:Tick()
  -- Questie 3.3.5 ThreadLib resumes every active delay-0 thread once per frame.
  -- Snapshot the queue length so a continuation re-enqueued by its own slice
  -- cannot run twice in the same frame.
  local count=table.getn(self.queue)

  for i=1,count do
    local entry=table.remove(self.queue,1)
    if entry and entry.fn then
      entry.fn()
      self.executed=self.executed+1
    end
  end
end

local f=CreateFrame("Frame","QuestieOctoSchedulerFrame",UIParent)
f:SetScript("OnUpdate",function()
  local delta=arg1 or 0
  RunDelayed(S,delta)
  -- Questie ThreadLib delay < 0.05 means "every frame".
  S.elapsed=0
  S:Tick()
end)
