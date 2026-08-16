Questie-Octo 1.0.2


1.0.2 release notes
-------------------
- Active, non-failed quests with zero native quest-log objectives are now
  treated as ready for turn-in, matching pfQuest and original Questie behavior
  for breadcrumb/talk quests such as Professor Papucho (50003).
- Failed timed quests remain failed and do not receive a completed turn-in
  marker; abandoning them returns them to normal availability handling.
- A first-accept safety check prevents a temporary empty Vanilla leaderboard
  from falsely completing quests that the database already knows have normal
  objectives or IR item requirements.

1.0.1 release notes
-------------------
- Corrected Turtle WoW quest 42045, Tainted Rune, to include its Warlock-only
  class restriction (class mask 256). Dwarf characters of other classes no
  longer see the quest as available.
- First-time quest acceptance primes the native Vanilla quest log and briefly
  fast-polls while ClassicAPI publishes a never-before-seen quest ID, avoiding
  the several-second tracker delay seen on fresh characters.
- Enable Map Icon Glow defaults to OFF, including the one-time migration from
  the former default ON value.
- Objective Node Density and Item-Start Node Density now rebuild the open World
  Map zone and current minimap zone first, so Clustered/Full Nodes changes are
  reflected immediately on both map views.

1.0 release notes

- Final release branding: in-game startup text now says Questie-Octo without a Beta suffix.
- Quest Options order is now Show Quest Levels, Show Low-Level Quests, Show Repeatable Quests, Show Event Quests, then Show PVP Related Quests.
- Added Show PVP Related Quests (default ON). Turning it OFF hides all PvP quest markers on the World Map and Minimap, including available quests, active objectives, and turn-ins.
- Show Event Quests now appears below Show Repeatable Quests.

Beta 1.6 notes
--------------
- Corrected World Map Visibility scope: Show Quests on the World Map and Show Special Quests on the World Map now filter only continent/world overview quest pickup/turn-in markers.
- Selected zone and city maps are unaffected by those overview toggles, so repeatable/PvP/event quest markers remain visible there when their normal quest-type visibility is enabled.
- Show Special Quests on the World Map remains default OFF.


Beta 1.4 notes
--------------
- Fixed Quest-browser Rewards disappearing after being moved into the shared
  scrollable quest-detail pane. The reward panel is now anchored directly below
  the quest text and uses Vanilla/Turtle-compatible text height measurement.

Beta 1.3 notes
--------------
- General > World Map Visibility adds Show Special Quests on the World Map (default OFF).
  It independently controls repeatable blue, PvP red, and verified event green quest
  pickup/turn-in markers. Show Quests on the World Map now controls ordinary quest
  pickup/turn-in markers.
- Tracker defaults: font size 11, visible rows 30, background opacity 0.
- Quest-browser Rewards now live inside the same scrollable detail pane as the quest
  description/objectives/turn-in text.

=======================

CURRENT BETA 1.0 NOTES
----------------------
The historical alpha notes below are retained as development history and do not
override current Beta behavior. Current Beta removes distance fading, uses one
global World Map scale and one global Minimap scale, and keeps unknown event IDs
on standby unless they have a verified classification/schedule.

The Quests browser uses a direct bounded search over the cached pfQuest quest
title index (maximum 100 visible results); it does not run its search through the
shared frame scheduler.

The General tab exposes Show Quests on the World Map and Show Flight Master on
the World Map as direct controls, both enabled by default.

BACKPORT SOURCES
----------------
Only the approved Questie chain was inspected:
  Questie 5.2.3 -> 6.0.0 -> Questie 3.3.5 -> 7.0.0 -> 8.0.0

Questie 9/10/11 were not inspected or used.

STABLE QUESTIE DEFAULTS
-----------------------
The supplied allowed versions agree on the mature minimap defaults:

  enableMiniMapIcons       = true
  globalMiniMapScale       = 0.7
  fadeLevel                = 20
  fadeOverPlayer           = true
  fadeOverPlayerDistance   = 5
  fadeOverPlayerLevel      = 0.5
  iconFadeLevel            = 0.3
  alwaysGlowMinimap        = false
  questMinimapObjectiveColors = false

0.1.29 BACKPORT
---------------
A Questie-style global minimap settings model now lives in QuestieOctoGlobalDB.

Implemented behavior:
  * enable/disable all minimap quest icons
  * live global minimap icon scaling
  * Questie's far-distance fade curve:
      full opacity until fadeLevel
      then fade from 1.0 -> 0.0 over the next 10 Questie distance units
  * Questie's fade-over-player behavior:
      at distance 0 use fadeOverPlayerLevel
      linearly return to full opacity at fadeOverPlayerDistance
  * settings persist globally across characters

Questie 3.3.5/7/8 normally calculate distance through HereBeDragons world
coordinates. On Turtle 1.12 the already-approved pfQuest compatibility
projection plus bundled minimap dimensions is used only to reconstruct that
world distance before applying Questie's fade formula.

DEFERRED ON PURPOSE
-------------------
alwaysGlowMinimap and questMinimapObjectiveColors are stored with Questie's
defaults but are not activated yet.

Those settings depend on Questie's shared quest-color/glow frame subsystem.
Implementing a minimap-only substitute would violate the Questie Backport Rule.
They will become functional when that shared subsystem is ported.

TEST COMMANDS
-------------
Temporary commands are provided to validate the behavior before the full
Questie options UI is backported:

  /qo minimap
  /qo minimap on
  /qo minimap off
  /qo minimap scale 0.7
  /qo minimap fade 20
  /qo minimap near on
  /qo minimap near off
  /qo minimap neardistance 5
  /qo minimap nearalpha 0.5
  /qo minimap reset

The mature Questie option ranges are enforced:
  scale        0.01 - 4
  fade         10 - 100
  nearDistance 0 - 20
  nearAlpha    0.1 - 1

PRESERVED FROM 0.1.28 HOTFIX 3
-------------------------------
* synchronized quest-wide world-map/minimap unload
* accepted quest ID normalization
* abandoned quest immediate unload/redraw
* prepared-cache quest purge
* Questie slay/loot/interact icons
* item-start grouping
* rare/static respawn tooltips
* 0.1.27 fast scheduler/lifecycle behavior


0.1.29 MAP-CONTEXT HOTFIX
-------------------------
Questie remains the authority for minimap refresh behavior and settings.

The supplied allowed Questie versions rely on HereBeDragons for minimap
projection. Turtle/Vanilla 1.12 does not provide HBD, so pfQuest is consulted
ONLY for the compatibility layer.

The first 0.1.29 build called SetMapToCurrentZone() inside PlayerPosition(),
which runs every ~0.05s. That was too aggressive and did not faithfully match
pfQuest's compatibility pattern.

Now SetMapToCurrentZone() is used only when map context actually needs
restoration:
  * startup
  * zone/minimap-zone change
  * world map closes after browsing

Normal minimap movement updates now call only GetPlayerMapPosition() and never
force map context.

No Questie quest-state, lifecycle, fading, scaling, icon, or availability
behavior was changed.


0.1.30 ALPHA - QUESTIE-STYLE OPTIONS MENU
-----------------------------------------
QUESTIE-FIRST AUDIT
-------------------
Inspected only the approved chain:
  Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Questie 9/10/11 were not inspected.

All approved Questie generations describe their options through AceConfig /
AceGUI. Their Blizzard-options integration depends on the post-1.12
InterfaceOptionsFrame system, so that presentation host cannot be transferred
directly to Turtle/Vanilla 1.12.

PFQUEST COMPATIBILITY USE
-------------------------
Only after establishing the Questie UI-host incompatibility, pfQuest was
consulted for Vanilla UI compatibility. pfQuest confirms that native 1.12
CreateFrame controls such as UICheckButtonTemplate, Slider, and
UIPanelButtonTemplate are the safe compatibility layer.

Questie remains authoritative for:
  * option labels
  * defaults
  * ranges / steps
  * dependency behavior
  * live application of settings
  * bare slash command toggling the config window

IMPLEMENTED OPTIONS
-------------------
Only already-working Questie-Octo features are exposed:
  Enable Minimap Icons
  Global Scale for Minimap Icons       0.01 - 4, step 0.01
  Fade objective distance              10 - 100, step 1
  Fade Icons over Player
  Fade over Player Distance            0 - 20, step 0.5
  Fade over Player Amount              0.1 - 1, step 0.1

Fade-over-player distance/amount controls disable when the parent toggle is
off, as in Questie.

Commands:
  /qo            toggles options, matching old Questie's bare /questie behavior
  /qo options    toggles options
  /qo help       command help

The existing /qo minimap testing commands remain available.

NOT EXPOSED YET
---------------
Glow, objective colors, tracker, and unsupported world-map settings remain
absent from the menu. They will only appear after their Questie subsystems have
actually been backported.


0.1.31 ALPHA - VANILLA OPTIONS PRESENTATION
-------------------------------------------
QUESTIE SEMANTICS
-----------------
Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0 remain authoritative
for option names, defaults, ranges, dependency rules, and live setters.

SHAGUTWEAKS COMPATIBILITY LAYER
-------------------------------
The user-supplied ShaguTweaks source was inspected only after Questie's Ace3
UI host was established as non-transferable to Vanilla 1.12.

ShaguTweaks config.lua confirms mature 1.12-native presentation mechanics:
  UIPanelScrollFrameTemplate
  OptionsCheckButtonTemplate
  OptionsSliderTemplate
  collapsible category frames
  movable DialogFrame shell
  standard GameMenuButtonTemplate controls
  GameTooltip help

Questie-Octo 0.1.31 uses those presentation mechanics, but DOES NOT copy
ShaguTweaks' delayed Okay/Cancel/ReloadUI semantics.

Questie AceConfig settings apply live, so Questie-Octo settings still apply
immediately when toggles/sliders change.

The panel is now category/scroll based and ready to grow as real Questie
subsystems are backported. Only the implemented Minimap category is present.


0.1.32 ALPHA - QUESTIE ACECONFIG / ACEGUI PROOF OF CONCEPT
-----------------------------------------------------------
QUESTIE BACKPORT RULE AUDIT
---------------------------
Inspected only:
  Questie 5.2.3 -> 6.0.0 -> Questie 3.3.5 -> 7.0.0 -> 8.0.0

Questie 9/10/11 were not inspected or used.
pfQuest was not needed for this options-framework pass.

CHOSEN QUESTIE DESIGN
---------------------
Questie 5.2.3 and 6.0.0:
  * build an AceConfig options table
  * register it
  * AceGUI:Create("Frame")
  * AceConfigDialog:Open("Questie", configFrame)
  * keep the standalone frame hidden until toggled

Questie 3.3.5 preserves this design and refreshes the existing standalone
frame with AceConfigDialog:Open() when opening it. 7/8 retain the same mature
standalone options architecture with sizing/init refinements.

That is the architecture used here.

VANILLA COMPATIBILITY
---------------------
Questie's bundled Ace3 runtime itself targets later WoW APIs and cannot be
dropped directly into Vanilla 1.12.

The user-supplied Ace3v package targets Interface 11200 and contains Vanilla
adaptations for AceCore/AceGUI/AceConfig. It is used only as the compatibility
runtime for Questie's own AceConfig/AceGUI design.

LibStub and CallbackHandler are taken from the supplied Questie 5.2.3 archive.

No Blizzard InterfaceOptions panel is registered.

OPTIONS TABLE
-------------
To keep this proof of concept limited to implemented features:
  General:
    Enable Minimap Icons

  Minimap:
    Global Scale for Minimap Icons       0.01 - 4
    Fade objective distance              10 - 100
    Fade Icons over Player
    Fade over Player Distance            0 - 20
    Fade over Player Amount              0.1 - 1

Labels, ranges, dependencies and live setting behavior are taken from the
supplied Questie option definitions.

The legacy 0.1.31 hand-rendered Vanilla options fallback was removed after
the AceConfig/AceGUI options path became the stable runtime implementation.


0.1.32 ACE3V HOTFIX 1 - CALLBACKHANDLER LUA 5.0
------------------------------------------------
The first POC failed at parse time in Questie 5.2.3 CallbackHandler-1.0.

Audit of Questie 5.2.3, 6.0.0, 3.3.5, 7.0.0 and 8.0.0 confirmed that all
supplied CallbackHandler copies use Lua 5.1-style '...' expressions.

The Questie CallbackHandler API and behavior are retained. Only the incompatible
vararg implementation is translated to Vanilla Lua 5.0's implicit 'arg' table
and unpack(), including the generated fixed-arity dispatcher.

Questie's standalone AceConfig/AceGUI options architecture is unchanged.


0.1.33 ALPHA - QUESTIE WORLD-MAP DISPLAY OPTIONS
-------------------------------------------------
BACKPORT TRACE
--------------
Inspected only:
  Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Questie 9/10/11 were not used.
pfQuest and ShaguTweaks were not needed for this pass.
Ace3v remains only the validated Vanilla runtime for Questie's AceConfig/AceGUI.

QUESTIE BEHAVIOR BACKPORTED
---------------------------
General:
  Enable Map Icons
  Enable Minimap Icons
  Enable Objective Icons
  Enable Completed Quest Icons
  Enable Available Quest Icons

The Objective / Completed / Available switches are shared between world map
and minimap, matching Questie's global presentation filters.

Map:
  Global Scale for Map Icons
    range 0.01 - 4
    step 0.01
    old/mature Questie default used here: 0.7

Display toggles filter presentation only. They do not alter quest availability,
objective resolution, completion state, or prepared quest data.

Item-start quest markers follow Enable Available Quest Icons because they are
Questie-Octo's available-quest presentation for item-start quests.

NOT YET EXPOSED
---------------
Per-icon-type scales, objective colors, and glow remain deferred. Questie ties
those to frame metadata/color/glow systems that have not yet been backported.


0.1.34 ALPHA - ESC MENU "QUESTIE OPTIONS"
-----------------------------------------
QUESTIE-FIRST AUDIT
-------------------
Questie 5.2.3, 6.0.0, 3.3.5, 7.0.0 and 8.0.0 were checked for GameMenuFrame /
GameMenuButton integration. None of the supplied versions adds its own ESC-menu
button.

Therefore the Questie options architecture remains unchanged:
  Questie AceConfig table -> AceConfigDialog -> standalone AceGUI frame.

SHAGUTWEAKS COMPATIBILITY
-------------------------
Only the missing Vanilla presentation integration is adapted from the supplied
ShaguTweaks config.lua:

  GameMenuButtonTemplate
  anchor below GameMenuButtonUIOptions
  move GameMenuButtonKeybindings below the inserted button
  hide GameMenuFrame when opening addon options
  return to GameMenuFrame when the options window closes

COEXISTENCE
-----------
When ShaguTweaks' GameMenuButtonAdvancedOptions exists, Questie Options anchors
below Advanced Options instead of competing for the same slot:

  Options
  Advanced Options
  Questie Options
  Key Bindings

Without ShaguTweaks:

  Options
  Questie Options
  Key Bindings

The button text is exactly:
  Questie Options

Opening via /qo still behaves normally and does not reopen the Game Menu when
the options window closes.


0.1.34 TITLE HOTFIX
-------------------
The validated AceConfig/AceGUI window title now matches the ESC-menu button:

  Questie Options

No option behavior, settings, map/minimap logic, or compatibility code changed.


0.1.35 ALPHA - QUESTIE PER-ICON-TYPE SCALES
--------------------------------------------
BACKPORT TRACE
--------------
Inspected:
  Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Questie 9/10/11 were not used.
Ace3v remains only the Vanilla runtime for Questie's AceConfig/AceGUI.
ShaguTweaks and pfQuest were not needed for this feature.

QUESTIE SCALE MODEL
-------------------
Final icon size is:
  16 * presentation global scale * icon-type scale

Map uses globalScale.
Minimap uses globalMiniMapScale.

Old Questie 5.2.3/6.0.0 defaults are retained:
  availableScale = 1.3
  monsterScale   = 1
  objectScale    = 1
  lootScale      = 1

Role mapping:
  available / complete / item-start = availableScale
  creature/slay objective           = monsterScale
  direct object objective           = objectScale
  item source from object           = objectScale
  item source from creature         = lootScale

This matches Questie's objective-source scale behavior rather than scaling all
item objectives identically.

The settings affect BOTH world map and minimap, as in Questie.

Event objective scaling is not exposed yet because Questie-Octo does not yet
have an event-objective presentation path to scale.

COLORS / GLOW
-------------
Not changed in this build. Those remain the next separate Questie frame-layer
backport so scale behavior can be validated independently first.


0.1.35 SCALE HOTFIX
-------------------
User test showed the new type-scale controls rendered but did not visibly
affect markers.

The Questie audit was revisited. Questie assigns GetIconScale/IconScale to the
semantic quest/objective data before frame rendering. The first 0.1.35 build
incorrectly reconstructed scale type later from merged presentation pins.

Questie-Octo now mirrors Questie's semantic model:
  semantic node -> iconScaleKey -> prepared/world/minimap presentation

Mapping:
  available/turnin/itemStart -> availableScale
  objectiveCreature          -> monsterScale
  objectiveObject            -> objectScale
  item from creature         -> lootScale
  item from gameObject       -> objectScale

This also corrects the first build's object-source string mismatch
("object" versus Questie-Octo's actual "gameObject").

Both world-map and minimap visual winners carry the semantic scale key, and
live Rescale behavior reads that key directly.

Diagnostics now report scale resize counts and the last applied pixel size.


0.1.35 SCALE HOTFIX 2 - ACE3V RANGE RELEASE
---------------------------------------------
User diagnostics proved the semantic scale and frame resize path worked while
the slider was moving, but the stored value returned to the old/default value
after release.

Questie's supplied AceGUI/AceConfig range flow was compared again across
5.2.3, 6.0.0, 3.3.5, 7.0.0 and 8.0.0. Questie commits range changes through
OnValueChanged and refreshes the AceConfig dialog on OnMouseUp.

Ace3v adapts that callback ABI for Lua 5.0 with an explicit argc slot. On the
Turtle 1.12 native Slider, the release event can deliver the pre-drag widget
value, causing AceConfigDialog to invoke the setting setter a second time and
undo the already-correct OnValueChanged commit.

Compatibility fix:
  OnValueChanged -> validate + commit Questie option live
  OnMouseUp      -> refresh AceConfigDialog only; no second setting write

This is confined to the Ace3v compatibility runtime. Questie's options table,
setting names/defaults/ranges, scale model, and map/minimap frame behavior are
unchanged.

/qo info now also reports the last AceConfig setting key/value received.


0.1.35 SCALE HOTFIX 3 - SINGLE QUESTIE RESCALE PATH
---------------------------------------------------
User video proved that per-type scale values could become visible only after
touching Global Scale.

Questie version trace:
  5.2.3 / 6.0.0:
    several map scale setters call RescaleIcons before saving the new value.
  3.3.5:
    saves the new option first, then calls QuestieMap:RescaleIcons().
  7 / 8:
    retain the single QuestieMap:RescaleIcons frame-walk architecture.

Per the backport rule, 3.3.5 is used as the compatibility bridge and mature
ordering for this client.

Questie-Octo now has ONE scale path:
  save setting
    -> QuestieOcto.Map:RescaleIcons()
       -> refresh each world-map frame's semantic visual/scale data
       -> resize every world-map frame
       -> QuestieOcto.Minimap:RescaleIcons()
          -> refresh each minimap frame's semantic visual/scale data
          -> resize every minimap frame

Global and per-icon-type sliders no longer use separate presentation callbacks.
They all invoke this same path, matching Questie's frame architecture.

No quest state, objective resolution, projection, fade, icon texture, or
visibility behavior changed.


0.1.35 TURN-IN HOTFIX - QUESTIE COMPLETE '?' + ACE3V ONUPDATE
-------------------------------------------------------------
Questie trace (5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0) found:

1. Questie creates separate frames for available and completed quest icons.
   Questie-Octo incorrectly merged exact-role descriptors by source+coordinate,
   causing an available ! to hide a completed ?.

2. Questie deliberately renders available icons at OVERLAY sublevel 5 and
   completed icons at OVERLAY sublevel 6. Completed ? therefore stays visible
   above an overlapping available !.

3. Questie 6 falls back to IsQuestComplete(questId) when the quest-log
   isComplete field is unavailable. Questie-Octo now uses that legacy fallback
   and no longer treats numeric -1 (failed) as complete merely because Lua
   considers it truthy.

4. Ace3v AceConfigDialog RefreshOnUpdate used a modern self-argument style.
   Vanilla 1.12 supplies frame-script context through global `this`, causing
   line 1722 to index nil during refresh. The compatibility layer now consumes
   Vanilla's global this without changing Questie's AceConfig architecture.

No marker displacement was added. Exact Questie icons are allowed to overlap.


0.1.35 TURN-IN HOTFIX 2 - QUESTIE 3.3.5 QUEST-LOG COMPAT
----------------------------------------------------------
The previous turn-in visual fix removed exact-marker merging, but user testing
still showed no yellow completed-quest marker.

The Questie 3.3.5 compatibility bridge exposed the actual root cause:
raw old/Turtle GetQuestLogTitle has a legacy suggestedGroup return before
isHeader, so isHeader/isCollapsed/isComplete are shifted by one position.
Questie-Octo had been reading the later-client signature directly, meaning its
'isComplete' value was actually the legacy isCollapsed value.

Questie-Octo now normalizes GetQuestLogTitle at ClassicAPI, following Questie
3.3.5. It also passes questLogIndex into the legacy GetQuestObjectives bridge.

Map, minimap, turn-in texture, exact-marker layering, and scale behavior were
not redesigned in this hotfix.


0.1.36 ALPHA - FULL CURRENT-BUILD AUDIT
----------------------------------------
AUDIT SCOPE
-----------
Re-audited the current live build end-to-end under the Questie Backport Rule:
  Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Questie 9/10/11 were not inspected.
Ace3v remains only the Vanilla runtime for Questie's AceConfig/AceGUI.
ShaguTweaks remains only the Vanilla ESC-menu presentation reference.
pfQuest was consulted only after the Questie raw client API could not transfer
unchanged to Interface 11200.

PRIMARY FINDING: COMPLETED QUESTS
---------------------------------
The previous turn-in hotfix applied Questie 3.3.5's raw WotLK-era
GetQuestLogTitle signature directly to Turtle 11200:
  title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete, ...

That is NOT the Vanilla 1.12 raw signature.

The supplied pfQuest compatibility layer explicitly branches on client 11200:
  title, level, tag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(index)

Therefore Questie-Octo was reading Vanilla's completion field from the wrong
return position. This is the root cause of the missing yellow completed '?'.

0.1.36 now normalizes the actual Vanilla signature at API/ClassicAPI.lua and
continues to expose the Questie-facing normalized fields to the rest of the
addon.

TURN-IN PIPELINE RE-AUDIT
-------------------------
Quest log complete state
  -> QuestLog.active[questID].complete
  -> Nodes builds role='turnin'
  -> QuestModel finishers from raw end.U/end.O
  -> PreparedMap exact descriptor keyed by quest+role+source+coordinate
  -> Map/Minimap texture role='turnin'
  -> UI/Icons/complete.blp (Questie 3.3.5 asset)

The custom Turtle quest 41189 was checked explicitly:
  finisher NPC = 61851 Commander Anarileth
  QuestModel database contains the finisher correctly.

DISPLAY AUDIT
-------------
Completed and available exact markers remain separate Questie-style frames.
Completed '?' uses overlay sublevel 6; available '!' uses sublevel 5.
Canonical coordinates are retained. Dead displacement helper code was removed.

OPTIONS / SCALE AUDIT
---------------------
The validated Questie AceConfig/AceGUI architecture is retained.
Ace3v Lua 5.0 CallbackHandler and AceConfig refresh compatibility fixes remain.
All global and per-type scale controls route through one save-then-rescale path
following the mature Questie 3.3.5 ordering.

MINIMAP AUDIT
-------------
Questie remains authoritative for node state, icon behavior, scaling and fade.
pfQuest remains used only for the unavoidable Vanilla minimap projection/map-
context compatibility layer. The previous 0.05s SetMapToCurrentZone mistake
remains fixed.

LIFECYCLE AUDIT
---------------
Accept, abandon/remove, completion database, low-level visibility, item-start
sources, rare static-respawn metadata, objective direct-index mapping, and the
0.1.27 Questie-335 scheduler path remain unchanged from their validated state.

DIAGNOSTICS
-----------
/qo info now also prints:
  QuestLog complete IDs=...

For a visibly completed quest, its ID must appear there and Nodes turnin must
be greater than zero before any map rendering issue is considered.


0.1.36 TURN-IN AUDIT HOTFIX - OBJECTIVE-LESS QUESTS
----------------------------------------------------
Full Questie trace found the missing completion rule:

Questie 5.2.3:
  QuestieQuest:IsComplete() returns true when Objectives is nil or empty.

Questie 3.3.5:
  QuestieDB.IsComplete() returns complete for an active quest with no objective
  rows unless the special required-source-item case is missing its item.

Quest 41187 in the bundled Turtle DB has no obj/source-item requirement and
finishes at NPC 61851. Therefore it must be treated as complete immediately
after acceptance, which produces the turn-in semantic node and yellow ?.

No world-map/minimap rendering workaround was added. The fix is at QuestLog
completion semantics, where Questie puts this behavior.


0.1.37 ALPHA - MINIMAP PROJECTION FIX
--------------------------------------
FULL BACKPORT RECHECK
---------------------
Questie minimap architecture was rechecked through the approved chain:
  Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Those Questie versions use HereBeDragons/world-coordinate projection on newer
clients. Turtle/Vanilla 1.12 does not provide that library, so pfQuest remains
the permitted final compatibility reference for the projection itself.

ROOT CAUSE
----------
Questie-Octo's initial pfQuest MinimapIndoor() adaptation inverted pfQuest's
state mapping.

pfQuest behavior:
  state 0 -> MINIMAP_ZOOM[0] -> 300-yard family
  state 1 -> MINIMAP_ZOOM[1] -> 466.67-yard family

When current minimap zoom is NOT minimapInsideZoom, pfQuest returns state 1.
Questie-Octo incorrectly returned 0. That selected a 300-yard span where
pfQuest selected 466.67 yards, making projected quest-marker movement about
1.56x too large as the player moved away from the target.

0.1.37 copies pfQuest's Vanilla minimap indoor/zoom-state logic exactly,
including its temporary zoom probe and its original state mapping.

This build starts from the plain audited 0.1.36 turn-in build. None of the
experimental native-yellow-circle backing textures or minimap-frame scanners
are included.

Retained:
  * audited objective-less completion / yellow turn-in '?' state
  * Questie AceConfig/AceGUI options and Ace3v Lua 5.0 compatibility
  * map/minimap icon scaling
  * quest accept/remove lifecycle fixes
  * item-start markers / rare static respawn tooltips
  * canonical marker coordinates (no displacement)


0.1.43 ALPHA - MINIMAP RANGE + AVAILABLE/COMPLETE DEFAULT
----------------------------------------------------------
BASELINE
--------
Built from the validated 0.1.37 minimap-projection baseline.

None of the experimental native-yellow-circle work from 0.1.38-0.1.42 is
included: no nodecut mask, no native-frame hiding, no quest-watch manipulation.

BACKPORT TRACE
--------------
Rechecked Questie:
  5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Historical availableScale values in the supplied versions are around 1.2-1.3.
The new 1.5 value is an explicit Questie-Octo/Turtle presentation default
requested by the user, not claimed as a historical Questie default.

AVAILABLE / COMPLETE SCALE
--------------------------
  default availableScale = 1.5

Existing saved value 1.3 (the previous untouched default) is migrated once to
1.5. Other custom values are preserved.

MINIMAP RANGE
-------------
Questie proper delegates edge behavior to its pin library. On Vanilla,
Questie-Octo previously used pfQuest's conservative clipping:
  pixelDistance + halfIcon < radius

That delays a marker until its entire icon is inside the circular minimap.

For the requested behavior, every Questie-Octo minimap marker now becomes
visible as soon as its coordinate itself enters the visible minimap circle:
  pixelDistance < radius

This applies equally to:
  available quests
  completed quests
  creature/slay objectives
  loot/item-source objectives
  object objectives
  item-start markers

Projection, coordinates, minimap zoom-state logic, scale sliders, fades and
world-map rendering are unchanged.


0.1.44 ALPHA - QUESTIE OPTIONS BACKPORT
----------------------------------------
Built from validated 0.1.43.

Audited Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0.
AceConfig/AceGUI remains Questie's architecture; Ace3v is only the 1.12
compatibility layer.

Backported for currently implemented subsystems:
  General: map/minimap/type visibility, low-level quests, max levels above.
  Map: Questie glow, per-quest objective colors, all implemented scales.
  Minimap: Questie glow/colors, scale and fade settings.
  Tooltips: enable, quest levels, drop rates, Quest/NPC/Object/Item IDs.
  Advanced: reset implemented options.

Questie's glow.blp and deterministic 5.2.3 color generator are used:
  quest icon color seed = questId
  objective glow seed = questId + 32768 * objectiveIndex

Low-level quest display remains ON by default, preserving the user's validated
Questie-Octo behavior. When disabled, the lower bound returns to Questie's
playerLevel - GetQuestGreenRange() behavior. Higher-level default remains +7.

Tracker, Nameplates, Auto-accept, Social, DBM/HUD and waypoint settings are not
shown because those Questie subsystems are not yet backported.

Map/minimap coordinate options are intentionally omitted here because the
user's ShaguTweaks already owns the Vanilla world-map coordinate presentation;
duplicating it would create a known UI conflict.

No pfQuest compatibility code was needed for this options pass.


0.1.45 ALPHA - OPTIONS AUDIT FIXES
-----------------------------------
Built directly from 0.1.44, retaining the validated 0.1.43 minimap projection
and visibility range.

LEVEL FILTER
------------
Questie 5.2.3 uses:
  maxLevel = playerLevel + maxLevelFilter

0.1.44 incorrectly kept a separate requiredLevel > playerLevel rejection,
preventing the +60 setting from revealing future-level quests.

0.1.45 applies the Questie 5.2.3 semantics to both quest level and required
level. +60 therefore removes the practical Vanilla level ceiling while normal
prerequisite/race/class/completion/active eligibility still applies.

showLowLevelQuests and maxLevelFilter now live in QuestieOctoDB (per character),
matching the mature Questie 6/3.3.5 direction and guaranteeing reload
persistence independently of global presentation settings.

TOOLTIPS
--------
NPC IDs now work because sourceID is preserved on world-map/minimap pins.

Item drop rates no longer disappear when an objective already has quest-log
text. Formatting follows Questie 3.3.5:
  >=10%  whole number
  >=2%   1 decimal
  >=.01% 2 decimals
  lower  3 decimals

Quest ID remains Questie's title suffix format:
  [level] Quest Name (questID)

GLOW / COLOR
------------
Per-quest icon color is intentionally Questie behavior: the whole objective
icon is tinted with a deterministic pseudo-random color based on quest ID.

The minimap glow problem was a Vanilla frame-ordering issue in 0.1.44.
Glow is now Questie's glow.blp placed directly on the same pin's BACKGROUND
draw layer instead of a child frame.

DEFAULTS REQUESTED BY USER
--------------------------
Global Map Scale:              1
Available/Complete Icon Scale: 1

Exact previous defaults (0.7 / 1.3 / 1.5 respectively) migrate once.
Other custom values are preserved.

The user-facing "Backport Scope" explanation was removed from Advanced.


0.1.47 ALPHA - QUESTIE 3.3.5 GLOW FIX
--------------------------------------
Built from 0.1.45, not the broken 0.1.46 glow build.

Questie 3.3.5 QuestieFrame.lua is used as the compatibility bridge:
  glow = icon frame ARTWORK sublevel -1
  icon = icon frame OVERLAY
  glow size = 1.13x icon size

This is the mature pre-modern Questie solution and avoids the child-frame and
OVERLAY hacks that broke 0.1.45/0.1.46.

Questie 3.3.5/7/8 also immediately update already-used frames when glow/color
settings change. Questie-Octo now resets only the presentation winner state
before re-applying each existing pin, so current map/minimap pins take the new
visual setting immediately.

Rare respawn wording now reads:
  [Rare] Respawn: ~150 min
or:
  [Rare Elite] Respawn: ~X min

The validated 0.1.43 minimap projection/range and 0.1.45 option fixes remain.


0.1.48 ALPHA - OPTIONS RECENTER + MINIMAP VISUAL DIAGNOSTIC
------------------------------------------------------------
Built from 0.1.47. No minimap rendering/projection behavior changed.

OPTIONS WINDOW
--------------
Questie keeps one persistent AceGUI configuration frame. On Vanilla/Ace3v,
dragged anchors therefore persist while that frame exists.

Questie-Octo now recenters the OUTER AceGUI frame on every explicit open:
  ClearAllPoints()
  SetPoint("CENTER", UIParent, "CENTER", 0, 0)

Dragging still works while the window is open; closing and reopening returns it
to screen center.

MINIMAP VISUAL DIAGNOSTIC
-------------------------
Adds:
  /qo visualdiag

For each currently visible objective minimap pin it prints:
  role
  quest ID
  whether semantic entries exist
  applied RGB
  whether Questie's glow texture is shown

Summary:
  shown / objective / colored / glowing

This distinguishes a Questie data/state problem from a Vanilla rendering-layer
problem without changing the validated minimap projection/range.


0.1.49 ALPHA - MINIMAP VISUAL LUA 5.0 SCOPE FIX
------------------------------------------------
Built from 0.1.48.

The user's diagnostic proved:
  glowMini=true
  colorMini=true
  visible objective pins=2
  applied colored/glowing=0/0

Root cause:
  MM:RefreshVisualSettings() and MM:RescaleIcons() were defined before
  `local function RefreshPinVisual()` in Minimap.lua.

On Lua 5.0, those earlier functions do not capture a local declared later.
They therefore resolved RefreshPinVisual as a global rather than the intended
local helper.

Fix:
  local RefreshPinVisual
  ...
  RefreshPinVisual=function(pin)
      ...
  end

This preserves Questie's existing visual logic and simply makes the intended
local refresh function visible to all callers.

Retained from 0.1.48:
  * Questie 3.3.5 ARTWORK glow architecture
  * current minimap color/glow settings
  * /qo visualdiag
  * options window recenters on every open
  * [Rare] Respawn wording
  * validated 0.1.43 minimap projection/range


0.1.50 ALPHA - OPTIONS CENTERING FIX
------------------------------------
Built from validated 0.1.49.

AceGUI's Frame widget stores dragged position in the AceConfig status table:
  status.top
  status.left

AceConfigDialog:Open(customFrame) reapplies that status on every checkbox,
slider, tab or other refresh. 0.1.48/0.1.49 only moved the physical frame back
to center, leaving stale status coordinates behind.

0.1.50 clears only status.top/status.left when the window opens and before
setting-driven AceConfig refreshes. Width, height, selected tab and all other
AceConfig state remain intact.

Dragging still works while the panel is open. Closing/reopening returns to
center, and option changes no longer restore a stale dragged anchor.

The 0.1.49 minimap glow/color fix and validated minimap behavior are unchanged.


0.1.68 ALPHA - PRE-EVENT ROLLBACK + DISPLAY TOGGLE ONLY
--------------------------------------------------------
Rebuilt from validated 0.1.50.

All event-state work is removed:
  no generic 1.12 server-event calendar API
  no event schedules
  no active/inactive event inference
  no Darkmoon rules
  no event-state engine

The only event feature is:
  General -> Quest Options -> Show Event Quests

ON:
  Event quests follow ordinary Questie-Octo quest availability and use
  Questie's event quest artwork.

OFF:
  Available event quest starters, including item-start event quests, are hidden.
  Accepted objectives and turn-ins remain visible.

Questie-Octo makes no attempt to decide whether an event is active today.


0.1.69 ALPHA - QUESTIE NATIVE OBJECTIVE NODES
----------------------------------------------
Backport source order:
  Questie 5.2.3 -> 6.0.0 -> 3.3.5 -> 7.0.0 -> 8.0.0

Objective semantics follow Questie's mature spawn-list behavior:
  creature objective             -> Slay
  item objective / creature drop -> Loot
  direct game-object objective   -> Object
  item objective / object source -> Object

The BLP artwork is the Questie 8.0.0 objective icon set, which is identical to
the corresponding mature 3.3.5 BLP set and is safe for the Vanilla texture
loader. Interact/Event artwork is bundled for supported future objective data,
but Questie-Octo does not invent those semantics when the Turtle quest model
does not explicitly provide them.

Objective Nodes option:
  Clustered (default)
  Full Nodes

Full Nodes shows every known source spawn coordinate. Clustered keeps the
existing Questie-Octo geographic grouping.

Item-Start Quests now have an independent inline options group:
  Show Item-Start Quests
  Show on World Map
  Show on Minimap
  Node Density: Clustered / Full Nodes
  Item-Start Quest Scale

Item-start quest markers remain quest-starter markers so they cannot be
mistaken for accepted quest objectives; their source density and visibility
are now independently configurable.

No quest arrow/navigation, nameplate objectives, or extra map interaction
subsystems are added.


0.1.70 ALPHA - PROFESSION RESOURCE NODES
-----------------------------------------
Options layout:
  Advanced tab removed.
  Profession tab added.
  Reset Options moved to the bottom of General.

Profession tab (all resource types disabled by default):
  Fishing Pools
  Herbalism
  Mining
  Survival Trees
  Show on World Map
  Show on Minimap
  Node Density: Clustered / Full Nodes
  Profession Node Scale

Data:
  Fishing  -> pfDB meta.fish gameobjects
  Herbs    -> pfDB meta.herbs gameobjects
  Ore      -> pfDB meta.mines gameobjects
  Survival -> Turtle Simple Wood Tree objects 2020267-2020281, 2020301

Artwork:
  Fishing/Herb/Ore use Questie 11.0.0 node_fish/node_herb/node_ore BLP.
  Survival uses the live client icon returned by GetItemInfo(4470) for
  Simple Wood; question-mark only while the item is not cached.

Profession/resource nodes have lower visual priority than quest pins.


0.1.71 ALPHA - WOOD FAMILIES + PROXIMITY TOOLTIPS
---------------------------------------------------
Survival resource coverage now includes every wood-tree family in the bundled
Turtle pfDB snapshot:

  Simple Wood:
    2020267-2020281, 2020301
    icon item 4470 (Simple Wood)

  Bright Wood:
    2020282-2020287
    icon item 42007 (Bright Wood)

  Shade Wood:
    2020288-2020297, 2020309
    icon item 42008 (Shade Wood)

  Tropical Wood:
    2020298
    icon item 42009 (Tropical Wood)

  Star Wood:
    2020299
    icon item 11291 (Star Wood)

  Dead Wood:
    2020300
    the supplied DB has no item literally named Dead Wood; item 42148
    (Dead Leaves) is explicitly sourced from the Dead Wood Tree and is used as
    the source-backed fallback rather than inventing an icon.

No generated image assets are used. Survival markers use the client's real item
textures. Vanilla's ADD blend mode is applied so the dark item-icon square is
visually suppressed and the resource artwork reads more like a standalone node.

World-map tooltip proximity:
  When two or more QUEST pins render within 2 pixels of each other, hovering
  any one of them shows one combined tooltip containing all nearby quest
  sources/quests. The map markers are NOT merged, moved, displaced or resized.
  Profession/resource pins are excluded from this proximity merge.


0.1.72 ALPHA - QUEST-FOCUSED CLEANUP
-------------------------------------
Profession/resource-node subsystem removed completely:
  no Profession tab
  no Fishing/Herb/Ore/Survival resource nodes
  no profession resource settings
  no ProfessionNodes module
  no resource-only map preparation
  no resource tooltip/render paths

Reset Options remains at the bottom of General.

World-map quest tooltip proximity threshold increased:
  2 pixels -> 5 pixels

If two or more quest markers render within 5 pixels, hovering one shows a
combined tooltip for readability. Quest markers themselves remain separate and
are not moved, merged, nudged, resized, or redrawn.

0.1.75 ALPHA - OPTIONS REFRESH CENTERING FIX
---------------------------------------------
Built from 0.1.74.

Fixed the Questie Options window moving away from screen center after selecting
a tab, checkbox, dropdown, or other control that triggers an AceConfigDialog
refresh.

Questie 5.2.3/6.0.0/3.3.5 establish the persistent standalone AceGUI options
frame. Questie 7/8 refine that lifecycle by avoiding unnecessary outer-frame
reopens. On Vanilla/Ace3v, AceConfigDialog still reapplies the custom frame
status table during full control refreshes; stale status.top/status.left values
could therefore move the physical frame after it had been explicitly centered.

The Questie custom frame now filters only those two position fields whenever its
AceConfig status is applied. Width, height, selected tab, scrolling, and all
other AceConfig state remain unchanged. The Ace3 compatibility library is not
modified globally.



0.3.3 ALPHA - INFRASTRUCTURE / PERFORMANCE CORRECTIVE PASS
-----------------------------------------------------------
Full Nodes:
  * compact pfQuest-style dot presentation
  * hidden 0.70 size multiplier
  * 15% transparency and subdued colors
  * only global Map / Minimap scaling remains
  * global rescaling changes size only and cannot replace Full Node artwork

Repeatables:
  * dedicated blue ! / ? artwork
  * PvP presentation takes priority over repeatable, which takes priority over event presentation
  * server-derived repeatable flags remain authoritative

Events:
  * DB event membership remains separate from current activity
  * active quests, mouseover, target and quest/gossip NPC observation can
    activate an event
  * confirmed event observations survive /reload until next realm midnight

Quests browser:
  * fixed native recycled-row UI, no AceGUI TreeGroup
  * opening the browser does not scan the whole quest database
  * explicit searches run in 50-quest per-frame slices
  * retained results capped at 100
  * closing the browser cancels the current search generation

Audit:
  * 96 Lua files syntax-checked
  * every TOC path verified
  * no runtime direct pfDB access outside Database/
  * no fading path, Object-ID UI, Completion tracker sort, or active
    per-category scale controls remain

See Docs/QUEST_SYSTEM_AUDIT.md for the authority chain, runtime limitations and
recommended in-game regression cases.


0.3.5 ALPHA - CONSOLIDATED QUEST INFRASTRUCTURE TEST BUILD
----------------------------------------------------------
Quests browser:
  * cached lowercase quest-title search index
  * 33-quest/frame bounded searches (about 30% faster than the previous pass)
  * Unavailable quests explain the failing requirement in the details pane
  * money rewards display as gold/silver/copper text
  * guaranteed and choice reward items display as clickable WoW hyperlinks
  * no reward icons
  * opening Quests from Options closes the AceConfig frame after its callback
    refresh, preventing the Options/Game Menu from remaining underneath

Events:
  * event membership, current event activity and event presentation are separate
  * scheduled Turtle game events use the supplied server schedule
  * Darkmoon uses the supplied Turtle hardcoded odd/even-week + Wednesday rule
  * permanent content gates such as cloth-turn-in event 159 remain normal quests
  * event 172 remains continuously available for Molten Core attunement

Repeatables:
  * authentic Questie 6 repeatable.blp for blue repeatable pickups
  * normal Questie completion artwork for repeatable turn-ins
  * PvP presentation wins over repeatable/event presentation; repeatable still wins over event

Full Nodes:
  * exact pfQuest node.tga
  * native pfQuest 14px baseline restored at global scale 1
  * 15% additional transparency and subdued per-quest color retained
  * global scale never swaps Full Nodes back to ordinary objective artwork

See Docs/QUEST_SYSTEM_AUDIT.md for the complete authority and validation pass.


0.3.7 ALPHA - CONSERVATIVE EVENT BETA BUILD

- Event quest availability now follows pfQuest: event membership itself never
  locally blocks a quest while Show Event Quests is enabled.
- Permanent Turtle content gates remain normal-looking quests rather than
  festival-coloured quests.
- Event schedule changes/observations no longer force availability/map rebuilds.
- Quests browser searches cached titles in 768-ID bounded slices and exact
  numeric quest IDs bypass the database scan.
- Verified donation repeatables from authoritative Turtle data: Silvermoon
  Remnants 80374 and Revantusk 80379 are repeatable; Goblin donation quests
  41115 and 41123 are repeatable. Silvermoon 80374 has minimum level 50.


0.3.7 ALPHA - CONSERVATIVE EVENT BETA BUILD
--------------------------------------------
Events:
- Show Event Quests now defaults OFF for a fresh character/install. Existing
  SavedVariables are preserved; Reset Options adopts the new default.
- Permanent Turtle game_event content gates remain ordinary quest eligibility
  metadata and are not painted/filtered as festivals.
- Festival-style available quests require the toggle plus positive active-event
  evidence from the supplied schedule/hardcoded policy or runtime observation.
- Unknown/unscheduled festival events fail closed until observed. Active quests
  already accepted by the player remain visible through the Quest Log path.


0.3.8 ALPHA - CURATED TURTLE EVENT CALENDAR
--------------------------------------------
Events:
  * major festival availability uses the manually verified 2026 Turtle
    in-game calendar and repeats annually by month/day
  * only visible event text counts; Raid Reset, roadmap/release entries and
    graphic-only calendar cells are ignored
  * Darkmoon Faire uses the anchored 14-day rule: six Elwynn days, one
    construction Wednesday, six Mulgore days, one construction Wednesday
  * the anchor is 2026-08-13 = first Elwynn active day
  * known annual calendar windows are authoritative and cannot be re-enabled
    out of season merely by clicking a lingering event NPC
  * unknown/custom festival IDs remain conservative and require live evidence
  * Show Event Quests remains OFF by default on a fresh install

Verified recurring annual windows:
  Love is in the Air      Feb 1-Feb 16
  Lunar Festival          Feb 16-Mar 4
  Noblegarden             Apr 17-May 8
  Midsummer Fire Festival Jun 21-Jul 12
  Brewfest                Sep 20-Oct 6
  Harvest Festival        Oct 1-Oct 8
  Hallow's End            Oct 20-Nov 2
  Feast of Winter Veil    Dec 3-Jan 14


BETA 1.2 - STABLE ADDON IDENTITY / QUEST BROWSER CORRECTIONS
-----------------------------------------------------
- Display title: Questie-Octo
- Author: Questie-Octo
- Version: 1.2
- Internal addon folder is permanently `Questie-Octo`; only ZIP/version metadata increments.
- Spawn of Jubjub (7946) is treated as a conditional Dark Iron Ale/Jubjub offer, not a static available pickup.
- Quests browser requirement wording is concise and Rewards use native item hyperlink text inside the scrollable quest-detail pane.
- Show Event Quests remains OFF by default on a fresh install.
- Verified seasonal events use the curated calendar / Darkmoon schedule.
- Verified release/content gates remain ordinary quest metadata.
- Event 159 (cloth-turn-in release gate) stays ordinary; normal cloth donation
  quests remain one-time where the data says so, and Additional Runecloth
  remains independently repeatable/blue where the authoritative data says so.
- Unknown or unverified event IDs are on standby: they do not publish available
  quest markers even if an NPC is observed. Active quests already in the Quest
  Log remain visible.
