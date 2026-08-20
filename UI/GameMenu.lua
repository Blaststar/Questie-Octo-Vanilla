-- The Questie Options entry now lives on the Quest Log frame (see
-- QuestLogEnhancements), so the Game Menu no longer installs its own button.
QuestieOcto.GameMenu = QuestieOcto.GameMenu or {}
local GM = QuestieOcto.GameMenu

function GM:SetButtonWidth(button, width)
  if not button then return nil end
  if (not button.GetTextWidth) or (not button.SetWidth) then return nil end
  if not width or type(width) ~= "number" then width = 20 end
  local buttonTextWidth = button:GetTextWidth()
  button:SetWidth(buttonTextWidth + width)
  return nil
end

GM.installed=false
GM.stats={ installs=0,clicks=0,anchor="none" }