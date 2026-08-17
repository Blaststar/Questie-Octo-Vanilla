-- Questie-Octo
QuestieOcto = QuestieOcto or {}
local QO = QuestieOcto

QO.version = "1.0.79"
QO.enabled = false
QO.ready = false
QO.messages = {}
QO.startedAt = 0

-- Turtle/Vanilla is authoritative for quest difficulty colors.  Questie-Octo
-- deliberately does not reproduce Questie level-band thresholds here.
local function RGBFromDifficultyFunction(level)
  local fn=GetDifficultyColor or GetQuestDifficultyColor
  if type(fn)~="function" then return nil,nil,nil end
  local ok,a,b,c=pcall(fn,tonumber(level) or 0)
  if not ok then return nil,nil,nil end
  if type(a)=="table" then
    return tonumber(a.r),tonumber(a.g),tonumber(a.b)
  end
  if tonumber(a) and tonumber(b) and tonumber(c) then
    return tonumber(a),tonumber(b),tonumber(c)
  end
  return nil,nil,nil
end

function QO:GetNativeQuestDifficultyColor(level,questID)
  -- First authority: the actual color Turtle's native QuestLog_Update
  local qle=self.QuestLogEnhancements
  if qle and qle.GetCachedQuestColor and questID then
    local r,g,b=qle:GetCachedQuestColor(questID)
    if r then return r,g,b end
  end

  -- Fallback until the native Quest Log color has been observed and cached
  local r,g,b=RGBFromDifficultyFunction(level)
  if not r then return nil,nil,nil end
  return r,g,b
end

function QO:Print(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd700Questie-Octo|r: "..tostring(text))
  end
end

function QO:Error(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Questie-Octo ERROR|r: "..tostring(text))
  end
end

function QO:RegisterMessage(name, owner, method)
  if not name or not owner or not method then return end
  self.messages[name] = self.messages[name] or {}
  table.insert(self.messages[name], { owner=owner, method=method })
end

function QO:SendMessage(name, ...)
  local list = self.messages[name]
  if not list then return end

  -- Lua 5.0 exposes varargs through the implicit 'arg' table.
  for _,entry in pairs(list) do
    local fn = entry.owner[entry.method]
    if fn then
      fn(entry.owner, unpack(arg))
    end
  end
end
