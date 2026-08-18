-- Right-click quest menu, rendered with the native Vanilla UIDropDownMenu so it
-- matches Blizzard/Titan context menus (submenu arrows, checks, highlight).
QuestieOcto.QuestMenu = QuestieOcto.QuestMenu or {}
local QM = QuestieOcto.QuestMenu

local function DB()
  QuestieOctoDB=QuestieOctoDB or {}
  QuestieOctoDB.questMenu=QuestieOctoDB.questMenu or {}
  local d=QuestieOctoDB.questMenu
  d.hiddenObjectives=d.hiddenObjectives or {}
  d.hiddenQuests=d.hiddenQuests or {}
  return d
end

local function ObjectiveKey(questID,objIndex)
  return tostring(questID).." "..tostring(objIndex)
end

local function IsObjectiveRole(role)
  return role=="objectiveCreature" or role=="objectiveObject" or role=="objectiveItemSource"
end

-- State queries -------------------------------------------------------------

function QM:IsQuestHidden(questID)
  return DB().hiddenQuests[tonumber(questID)] and true or false
end

function QM:IsObjectiveHidden(questID,objIndex)
  return DB().hiddenObjectives[ObjectiveKey(questID,objIndex)] and true or false
end

function QM:GetFocus()
  local f=DB().focus
  if type(f)~="string" then return nil,nil end
  local _,_,qid,oi=string.find(f,"^(%d+) (%d+)$")
  return tonumber(qid),tonumber(oi)
end

function QM:IsFocused(questID,objIndex)
  local fq,fo=self:GetFocus()
  return fq==tonumber(questID) and fo==tonumber(objIndex)
end

-- A node is hidden when its whole quest is hidden (objective nodes only) or when
-- its specific objective is hidden.
function QM:IsNodeHidden(node)
  if not node then return false end
  local qid=tonumber(node.questID)
  if not qid or qid<=0 then return false end
  if IsObjectiveRole(node.role) then
    if self:IsQuestHidden(qid) then return true end
    local oi=tonumber(node.objectiveIndex)
    if oi and self:IsObjectiveHidden(qid,oi) then return true end
  end
  return false
end

-- Toggles -------------------------------------------------------------------

function QM:RefreshMaps()
  if QuestieOcto.Minimap and QuestieOcto.Minimap.RefreshVisualSettings then
    QuestieOcto.Minimap:RefreshVisualSettings()
  end
  if QuestieOcto.Map and QuestieOcto.Map.RequestSync then
    QuestieOcto.Map:RequestSync(true)
  end
end

function QM:ToggleFocus(questID,objIndex)
  local d=DB()
  if self:IsFocused(questID,objIndex) then
    d.focus=nil
  else
    d.focus=ObjectiveKey(questID,objIndex)
  end
end

function QM:ToggleObjectiveHidden(questID,objIndex)
  local d=DB()
  local key=ObjectiveKey(questID,objIndex)
  d.hiddenObjectives[key]=(not d.hiddenObjectives[key]) or nil
  self:RefreshMaps()
end

function QM:ToggleQuestHidden(questID)
  local d=DB()
  questID=tonumber(questID)
  d.hiddenQuests[questID]=(not d.hiddenQuests[questID]) or nil
  self:RefreshMaps()
end

-- Menu data -----------------------------------------------------------------

local function ObjectiveName(q,row)
  local defs=q and q.objectiveData or nil
  local def=defs and row.dataIndex and defs[tonumber(row.dataIndex)] or nil
  if def and def.id then
    if def.kind=="creature" then return QuestieOcto.DatabaseAPI:GetCreatureName(def.id) end
    if def.kind=="gameObject" then return QuestieOcto.DatabaseAPI:GetObjectName(def.id) end
    if def.kind=="item" then return QuestieOcto.DatabaseAPI:GetItemName(def.id) end
  end
  local text=row.rawText or row.text or ""
  local stripped=string.gsub(text,"%s*:?%s*%d+%s*/%s*%d+%s*$","")
  -- Drop a trailing objective verb (e.g. "... slain") so only the name remains.
  local nameOnly=string.gsub(stripped,"%s+%l+$","")
  if nameOnly~="" then return nameOnly end
  if stripped~="" then return stripped end
  return text
end

local function ActiveState(questID)
  return QuestieOcto.QuestLog and QuestieOcto.QuestLog.active and QuestieOcto.QuestLog.active[tonumber(questID)] or nil
end

local function HasIncompleteObjectives(state)
  local objectives=state and state.objectives or {}
  local i=1
  while i<=table.getn(objectives) do
    if not objectives[i].complete then return true end
    i=i+1
  end
  return false
end

-- Native UIDropDownMenu rendering -------------------------------------------

local function AddTitle(text)
  local info={}
  info.text=text
  info.isTitle=1
  info.notClickable=1
  info.notCheckable=1
  UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL)
end

local function AddArrow(text,value)
  local info={}
  info.text=text
  info.value=value
  info.hasArrow=1
  info.notCheckable=1
  UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL)
end

local function AddToggle(text,isChecked,onToggle)
  local info={}
  info.text=text
  info.checked=isChecked and 1 or nil
  info.keepShownOnClick=1
  info.func=onToggle
  UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL)
end

local function Initialize()
  local questID=QM.currentQuestID
  if not questID then return end
  local state=ActiveState(questID)
  local q=QuestieOcto.QuestModel and QuestieOcto.QuestModel:Get(questID) or nil
  local level=UIDROPDOWNMENU_MENU_LEVEL or 1

  if level==1 then
    local title=(q and q.title) or (state and state.title) or ("Quest "..tostring(questID))
    local qlevel=q and tonumber(q.level)
    if qlevel and qlevel>0 then title="["..tostring(qlevel).."] "..title end
    AddTitle(title)
    if HasIncompleteObjectives(state) then
      AddArrow("Objectives","objectives")
    end
    AddToggle("Hide icons",QM:IsQuestHidden(questID),function()
      QM:ToggleQuestHidden(questID)
    end)
    return
  end

  if level==2 and UIDROPDOWNMENU_MENU_VALUE=="objectives" then
    local objectives=state and state.objectives or {}
    local oi=1
    while oi<=table.getn(objectives) do
      local row=objectives[oi]
      local objIndex=tonumber(row.index)
      if objIndex and not row.complete then
        AddArrow(ObjectiveName(q,row),"obj:"..objIndex)
      end
      oi=oi+1
    end
    return
  end

  if level==3 then
    local _,_,idx=string.find(tostring(UIDROPDOWNMENU_MENU_VALUE),"^obj:(%d+)$")
    local objIndex=tonumber(idx)
    if objIndex then
      AddToggle("Focus Objective",QM:IsFocused(questID,objIndex),function()
        QM:ToggleFocus(questID,objIndex)
      end)
      AddToggle("Hide icons",QM:IsObjectiveHidden(questID,objIndex),function()
        QM:ToggleObjectiveHidden(questID,objIndex)
      end)
    end
    return
  end
end

function QM:Open(questID,row)
  questID=tonumber(questID)
  -- No menu for a quest that is already complete/ready to turn in.
  local state=ActiveState(questID)
  if state and state.complete then return end

  if not self.dropdown then
    self.dropdown=CreateFrame("Frame","QuestieOctoQuestMenuDropDown",UIParent,"UIDropDownMenuTemplate")
  end
  self.currentQuestID=questID
  UIDropDownMenu_Initialize(self.dropdown,Initialize,"MENU")
  ToggleDropDownMenu(1,nil,self.dropdown,"cursor",0,0)
end
