QuestieOcto.GameMenu = QuestieOcto.GameMenu or {}
local GM = QuestieOcto.GameMenu

GM.button=nil
GM.installed=false
GM.stats={ installs=0,clicks=0,anchor="none" }

local function FindDragonflightButton(menu,text)
  if not menu or not menu.GetChildren then return nil end
  local children={menu:GetChildren()}
  for _,child in pairs(children) do
    if child then
      local value=nil
      if child.text and child.text.GetText then value=child.text:GetText() end
      if not value and child.GetText then value=child:GetText() end
      if value==text then return child end
    end
  end
  return nil
end

local function OpenQuestieOptions(origin)
  GM.stats.clicks=GM.stats.clicks+1

  if QuestieOcto.Options and QuestieOcto.Options.ShowFromGameMenu then
    QuestieOcto.Options:ShowFromGameMenu(origin)
  elseif QuestieOcto.Options then
    QuestieOcto.Options:Show()
  end
end

local function InstallDragonflightMenu()
  if not DFRL or not DFRL.menuframe then return false end
  local menu=DFRL.menuframe

  -- DragonflightUI-Reforged kills Blizzard's GameMenuFrame and exposes its
  -- replacement as DFRL.menuframe. Insert Questie directly into that live
  -- menu instead of attaching a button to the now-hidden Blizzard frame.
  local optionsButton=FindDragonflightButton(menu,"Options")
  local keyButton=FindDragonflightButton(menu,"Key Bindings")
  if not optionsButton or not keyButton then return false end

  local button=nil
  if DFRL.tools and DFRL.tools.CreateButton then
    button=DFRL.tools.CreateButton(menu,"Questie Options",120,30)
  else
    button=CreateFrame("Button","GameMenuButtonQuestieOctoOptionsDragonflight",menu,"GameMenuButtonTemplate")
    button:SetWidth(120)
    button:SetHeight(30)
    button:SetText("Questie Options")
  end
  if not button then return false end

  button:ClearAllPoints()
  -- Keep Questie with the options-related controls. DragonflightUI normally
  -- leaves a 15 px section gap between Options and Key Bindings; preserve
  -- that same gap below Questie while inserting the new button in between.
  button:SetPoint("TOP",optionsButton,"BOTTOM",0,0)
  keyButton:ClearAllPoints()
  keyButton:SetPoint("TOP",button,"BOTTOM",0,-15)
  menu:SetHeight(menu:GetHeight()+30)

  button:SetScript("OnClick",function()
    if DFRL and DFRL.menuframe then DFRL.menuframe:Hide() end
    OpenQuestieOptions("dragonflight")
  end)

  GM.button=button
  GM.installed=true
  GM.stats.installs=GM.stats.installs+1
  GM.stats.anchor="DragonflightUI Menu"
  return true
end

local function SkinPfUIGameMenuButton(button)
  if not button or not pfUI or not pfUI.api or not pfUI.api.SkinButton then return end
  if not pfUI.skin or not pfUI.skin["Game Menu"] then return end

  local disabled=pfUI_config and pfUI_config["disabled"]
  if disabled and disabled["skin_Game Menu"]=="1" then return end

  -- pfUI skins Turtle WoW buttons that are added after its initial Game Menu
  -- skin pass the same way: normalize the label, then use pfUI's own button
  -- skin helper instead of imitating pfUI's appearance inside Questie-Octo.
  local font=button.GetFontString and button:GetFontString()
  if font and font.SetTextColor then font:SetTextColor(1,1,1,1) end
  pfUI.api.SkinButton(button)
end

local function InstallBlizzardMenu()
  if not GameMenuFrame or not GameMenuButtonUIOptions or not GameMenuButtonKeybindings then
    return false
  end

  -- ShaguTweaks uses GameMenuButtonTemplate and inserts its Advanced Options
  -- button between Blizzard Options and Key Bindings. Preserve that exact
  -- Vanilla-safe presentation mechanic while coexisting with ShaguTweaks.
  local anchor=GameMenuButtonAdvancedOptions or GameMenuButtonUIOptions

  local button=CreateFrame(
    "Button",
    "GameMenuButtonQuestieOctoOptions",
    GameMenuFrame,
    "GameMenuButtonTemplate"
  )
  GM.button=button

  button:SetPoint("TOP",anchor,"BOTTOM",0,-1)
  button:SetText("Questie Options")
  SkinPfUIGameMenuButton(button)
  button:SetScript("OnClick",function()
    if HideUIPanel then
      HideUIPanel(GameMenuFrame)
    else
      GameMenuFrame:Hide()
    end
    OpenQuestieOptions("blizzard")
  end)

  -- Make room for one additional standard GameMenu button.
  GameMenuFrame:SetHeight(GameMenuFrame:GetHeight()+32)

  GameMenuButtonKeybindings:ClearAllPoints()
  GameMenuButtonKeybindings:SetPoint("TOP",button,"BOTTOM",0,-1)

  GM.installed=true
  GM.stats.installs=GM.stats.installs+1
  GM.stats.anchor=(anchor==GameMenuButtonAdvancedOptions) and "Shagu Advanced Options" or "Blizzard Options"
  return true
end

local function Install()
  if GM.installed then return end

  -- DragonflightUI's replacement menu is already created during its
  -- ADDON_LOADED initialization. Prefer it whenever present; if its Menu
  -- module is disabled, fall back to the normal Blizzard/Shagu path.
  if InstallDragonflightMenu() then return end
  InstallBlizzardMenu()
end

-- Install after all addons have loaded so ShaguTweaks, when present, has
-- already inserted GameMenuButtonAdvancedOptions and DragonflightUI-Reforged
-- has already exposed DFRL.menuframe.
local events=CreateFrame("Frame","QuestieOctoGameMenuInstaller",UIParent)
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
  QuestieOcto.Scheduler:After(0.10,Install,"questie-gamemenu-install")
end)
