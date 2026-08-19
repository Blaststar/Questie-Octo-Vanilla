-- The Questie Options entry now lives on the Quest Log frame (see
-- QuestLogEnhancements), so the Game Menu no longer installs its own button.
QuestieOcto.GameMenu = QuestieOcto.GameMenu or {}
local GM = QuestieOcto.GameMenu

GM.installed=false
GM.stats={ installs=0,clicks=0,anchor="none" }