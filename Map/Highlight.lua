-- Tracker-hover map highlight, modeled on pfQuest's pfMap.highlight: hovering a
-- quest in the tracker dims every map/minimap icon except that quest's
-- objectives, which stay bright and glow so they stand out.
QuestieOcto.MapHighlight = QuestieOcto.MapHighlight or {}
local H = QuestieOcto.MapHighlight

H.questID=nil

function H:Apply()
  if QuestieOcto.Map and QuestieOcto.Map.ApplyHighlight then QuestieOcto.Map:ApplyHighlight() end
  if QuestieOcto.Minimap and QuestieOcto.Minimap.ApplyHighlight then QuestieOcto.Minimap:ApplyHighlight() end
end

function H:Set(questID)
  questID=tonumber(questID)
  if not questID then return self:Clear() end
  if self.questID==questID then return end
  self.questID=questID
  self:Apply()
end

function H:Clear()
  if not self.questID then return end
  self.questID=nil
  self:Apply()
end
