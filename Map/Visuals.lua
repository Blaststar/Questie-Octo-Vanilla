QuestieOcto.Visuals = QuestieOcto.Visuals or {}
local V = QuestieOcto.Visuals

local ICON_ROOT="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\"
local TEX_GLOW=ICON_ROOT.."glow"

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function NextRandom(seed)
  seed=math.mod(seed*214013+2531011,4294967296)
  local value=math.mod(math.floor(seed/65536),32768)/32767
  return seed,value
end

local function SeedColor(seed)
  seed=tonumber(seed) or 0
  local r,g,b
  seed,r=NextRandom(seed)
  seed,g=NextRandom(seed)
  seed,b=NextRandom(seed)
  return 0.45+r/2,0.45+g/2,0.45+b/2
end

function V:GetQuestColor(questID)
  return SeedColor(tonumber(questID) or 0)
end

function V:GetObjectiveColor(questID,objectiveIndex)
  return SeedColor((tonumber(questID) or 0)+32768*(tonumber(objectiveIndex) or 0))
end

function V:IsObjectiveRole(role)
  return role=="objectiveCreature" or role=="objectiveObject" or role=="objectiveItemSource"
end

function V:EnsureGlow(pin)
  if not pin or pin.glowTexture then return end

  -- Questie 3.3.5 compatibility bridge:
  -- glow = same icon frame, ARTWORK sublevel -1
  -- icon = same icon frame, OVERLAY
  local tex=pin:CreateTexture(nil,"ARTWORK")
  if tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK",-1) end
  tex:SetTexture(TEX_GLOW)
  tex:SetWidth(18)
  tex:SetHeight(18)
  tex:SetPoint("CENTER",pin,"CENTER",0,0)
  tex:Hide()
  pin.glowTexture=tex
end

function V:ResizeGlow(pin)
  if not pin or not pin.glowTexture then return end
  local width=pin:GetWidth() or 16
  local height=pin:GetHeight() or 16
  pin.glowTexture:SetWidth(width*1.13)
  pin.glowTexture:SetHeight(height*1.13)
  pin.glowTexture:ClearAllPoints()
  pin.glowTexture:SetPoint("CENTER",pin,"CENTER",0,0)
end

function V:ClearPin(pin,alpha)
  if not pin then return end
  alpha=tonumber(alpha) or 1
  pin.iconR,pin.iconG,pin.iconB=1,1,1
  pin.glowR,pin.glowG,pin.glowB=1,1,1
  if pin.texture then pin.texture:SetVertexColor(1,1,1,alpha) end
  if pin.glowTexture then pin.glowTexture:Hide() end
end

function V:ApplyPin(pin,node,isMinimap,alpha)
  if not pin or not node then return end
  alpha=tonumber(alpha) or 1

  self:EnsureGlow(pin)

  local objective=self:IsObjectiveRole(node.role)
  local colorEnabled
  local glowEnabled

  if isMinimap then
    colorEnabled=Settings():Get("questMinimapObjectiveColors") and true or false
    glowEnabled=Settings():Get("alwaysGlowMinimap") and true or false
  else
    colorEnabled=Settings():Get("questObjectiveColors") and true or false
    glowEnabled=Settings():Get("alwaysGlowMap") and true or false
  end

  local r,g,b=1,1,1
  -- Quest pickup/turn-in presentation priority is PvP > Repeatable > Event >
  -- Normal. PvP and repeatable use dedicated artwork and keep its native color.
  if (node.pvp or node.repeatable) and (node.role=="available" or node.role=="itemStart" or node.role=="turnin") then
    r,g,b=1,1,1
  elseif objective and colorEnabled then
    r,g,b=self:GetQuestColor(node.questID)
  end
  pin.iconR,pin.iconG,pin.iconB=r,g,b
  if pin.texture then pin.texture:SetVertexColor(r,g,b,alpha) end

  if objective and glowEnabled and pin.glowTexture then
    local gr,gg,gb=self:GetObjectiveColor(node.questID,node.objectiveIndex)
    pin.glowR,pin.glowG,pin.glowB=gr,gg,gb
    pin.glowTexture:SetVertexColor(gr,gg,gb,alpha)
    self:ResizeGlow(pin)
    pin.glowTexture:Show()
  elseif pin.glowTexture then
    pin.glowTexture:Hide()
  end
end


function V:ApplyFullNode(pin,node,isMinimap,alpha)
  if not pin or not node or not pin.texture then return end
  -- pfQuest's ordinary spawn nodes are deliberately compact and subdued.
  -- Full Nodes use pfQuest's native 14px baseline and 15% transparency;
  -- the user's only size control is the global map/minimap scale.
  alpha=(tonumber(alpha) or 1)*0.85
  local r,g,b=self:GetQuestColor(node.questID)
  r,g,b=r*0.72,g*0.72,b*0.72
  pin.iconR,pin.iconG,pin.iconB=r,g,b
  pin.texture:SetTexture("Interface\\AddOns\\Questie-Octo\\UI\\Icons\\pfquest_node")
  pin.texture:SetVertexColor(r,g,b,alpha)
  if pin.glowTexture then pin.glowTexture:Hide() end
  pin.fullNode=true
  pin.fullNodeNode=node
end

function V:SetAlpha(pin,alpha)
  if not pin then return end
  alpha=tonumber(alpha) or 1
  if pin.fullNode then alpha=alpha*0.85 end
  if alpha<0 then alpha=0 end
  if alpha>1 then alpha=1 end

  if pin.texture then
    pin.texture:SetVertexColor(pin.iconR or 1,pin.iconG or 1,pin.iconB or 1,alpha)
  end
  if pin.glowTexture and pin.glowTexture:IsShown() then
    pin.glowTexture:SetVertexColor(pin.glowR or 1,pin.glowG or 1,pin.glowB or 1,alpha)
  end
end
