## 1.0.1 first patch release

- Turtle quest `42045` (Tainted Rune) now carries `class = 256` in `Data/pfDB/quests-turtle.lua`, matching Tortoise WoW's Warlock-only requirement while preserving its Dwarf race mask and prerequisite 179.
- First-time quest acceptance keeps the native quest-log priming/fast-poll path validated during post-1.0 testing.
- World-map objective glow defaults OFF with the existing one-time migration from the former default ON state.
- World Map density refresh prioritizes the currently displayed map zone, then the player's minimap zone, before background prepared-map work.
- Official release metadata is version `1.0.1`; future patch releases follow `1.0.2`, `1.0.3`, and so on.

## 1.0 final quest-option and branding pass

- Added character option `showPvPRelatedQuests` (default ON), matching Questie 6's PvP quest visibility semantics for map/minimap markers. OFF hides available PvP starts, active PvP objectives, and PvP turn-ins.
- Reordered Quest Options so Event follows Repeatable and added the requested `Show PVP Related Quests` toggle.
- Final release metadata is version 1.0 and the startup chat message no longer includes a Beta suffix.

## Beta 1.6 world-map visibility scope correction

- `showAllQuestsWorldMap` and `showSpecialQuestsWorldMap` are continent/world-overview filters only.
- Selected zone and city maps no longer apply those overview filters to available/item-start/turn-in quest markers.
- Zone/city quest marker visibility remains governed by the ordinary available/completed/item-start controls.
- `showSpecialQuestsWorldMap` remains default OFF.

## Beta 1.3 world-map special markers / tracker defaults / scrollable rewards

- `showSpecialQuestsWorldMap` defaults OFF and controls special blue/red/green quest pickup/turn-in markers independently from ordinary yellow quest markers.
- Tracker defaults are font size 11, 30 visible rows, background opacity 0.
- Rewards are children of the quest-detail scroll content and scroll naturally after Turn In.

- Internal addon folder is permanently `Questie-Octo` and the TOC is permanently `Questie-Octo.toc`; ZIP filenames carry the version instead.
- Version metadata: `Beta 1.3`.
- Quest 7946 (`Spawn of Jubjub`) is a conditional world-interaction offer and is not advertised as a static Morja pickup.
- Unavailable-reason strings were shortened for player readability.
- Rewards are rendered inside the scrollable quest-detail content with money and native item hyperlink buttons.

## Beta 1.1 post-package corrections

- Darkmoon event IDs 4 and 5 are treated as one logical active Faire for quest
  eligibility/presentation during the six active days. The DB assigns shared
  Faire quests to both IDs even though those NPCs exist at both locations.
- Auctioneer, Banker, and Mailbox markers use a hidden 0.90 intrinsic multiplier; global scale 1 remains
  the user-facing default.
- General options expose direct World Map Visibility controls for
  Show Quests on the World Map, Show Special Quests on the World Map, and Show Flight Master on the World Map.

# Quest system infrastructure audit — Beta 1.1

## Full Beta 1.1 regression audit (2026-08-14)

- 100 Lua files syntax-load cleanly under the supplied Lua compatibility checker.
- TOC/XML/file references resolve; addon identity is `Questie-Octo`, author `Questie-Octo`, version `Beta 1.1`.
- No unrelated generated data, code or assets are present in the addon package.
- pfDB access remains confined to the Database/Data boundary.
- `pfquest_node.tga` and Questie 6 `repeatable.blp` still match the supplied authoritative assets byte-for-byte.
- PvP Type-41 enrichment and the verified Blood Ring Type-0 corrections are present; marker priority remains PvP > Repeatable > Event > Normal.
- Quests browser search no longer depends on the shared scheduler. It performs a bounded direct scan of the already-cached lowercase title index and caps visible results at 100.
- General-tab World Map controls are flat AceConfig entries rather than an inline nested group for Ace3v/Vanilla compatibility.
- Seasonal event presentation is emitted only for a currently scheduled/active seasonal quest; repeatable and PvP presentation still take priority.

## Reference sources used

This pass was checked against the user-supplied reference archives rather than
an online mirror:

- current `pfQuest.zip` base source/database;
- current `pfQuest-turtle.zip` Turtle overlay/database;
- `Questie-v6.0.0.zip` for Questie presentation behavior/artwork;
- the supplied Turtle server source/database snapshot for quest requirements,
  rewards and game-event scheduling.

The normal pfQuest/Turtle entity and coordinate database remains the primary
static data source. Questie-Octo layers its own normalization/enrichment after
that data instead of maintaining a second independent quest database.

`UI/Icons/pfquest_node.tga` is byte-for-byte identical to pfQuest's `img/node.tga`.
`UI/Icons/repeatable.blp` is byte-for-byte identical to Questie 6.0.0's
`Icons/repeatable.blp`.

## Authority chain

1. pfQuest + Turtle + Octo static data — quest/entity/source truth.
2. `DatabaseAPI` — raw-data boundary for the rest of the addon.
3. `QuestModel` — normalized quest semantics (`lvl`, `min`, restrictions,
   prerequisites, repeatability and event membership).
4. Runtime truth:
   - `QuestLog` — active/objective/failure state;
   - `Completion` — rewarded/completed history;
   - `EventAvailability` — current server event state.
5. `AvailableQuests` — transactional availability snapshot.
6. `Objectives` / `ItemStarts` — source relationships.
7. `Nodes` — normalized map-node snapshot.
8. `PreparedMap` — shared immutable render plan.
9. World Map / Minimap / Tracker / Quests — presentation only.

No first-party runtime module outside `Database/` reads raw `pfDB` directly.

## Availability invariants

- `lvl` is display/difficulty information only.
- `min` is the minimum-level acceptance gate.
- The old user-facing Level Above Player option is gone.
- Active/completed state, chain prerequisites, exclusivity, race, class,
  Hardcore, skill/profession, reputation, event activity, level bounds,
  repeatability and valid starters are evaluated before publication.
- `Show Low-Level Quests`, `Show Event Quests` and `Show Repeatable Quests` are
  display/availability preferences, not replacements for server truth.
- Repeatability and event membership are independent properties.

`AvailableQuests:GetUnavailableReason()` exposes the first authoritative failing
condition to the Quests browser. It can identify disabled/not-currently-
obtainable quests, active/completed state, chain/exclusive prerequisites, race,
class, Hardcore, skill, reputation, inactive event, level bounds, hidden
repeatables, timed-quest conflicts and quests with no valid starter/source.
Unknown server-only conditions are reported as unknown instead of guessed.

## Completion and repeatables

Completion initialization runs the server completed-quest query protocol before
reading completed history, with the Turtle quest-status path retained as a
fallback.

Repeatable flags come from the server-derived enrichment or trustworthy live
observation. One-and-done repeatables can opt into `hideAfterFirstCompletion`;
`CLUCK!` uses that rule.

`CLUCK!` (3861) is also a scripted/conditional offer rather than a normal static
Chicken pickup: `/chicken` temporarily exposes the quest. To keep the quest
discoverable without covering every Chicken spawn, Questie-Octo deliberately uses
one representative Westfall Chicken at 55.6,30.9 as the static pickup/turn-in map
marker. The tooltip explains that `/chicken` is required. This does not change
server truth: other Chickens can still trigger/complete the scripted interaction.
The server repeatable flag remains intact for completion logic, but the representative
marker uses ordinary yellow quest presentation instead of blue repeatable artwork.
After the first completion, `hideAfterFirstCompletion` removes the discovery marker.

The cloth donation chain is intentionally not flattened into one repeatable
category: Wool/Silk/Mageweave/Runecloth donation steps are one-time quests, while
the `Additional Runecloth` follow-ups carry the repeatable flag.

Questie 6 presentation is used for repeatables: available repeatable starters
use the authentic blue `repeatable.blp`; repeatable turn-ins use Questie's
ordinary completion question-mark artwork. If a quest is both repeatable and an
event quest, PvP presentation wins first; otherwise repeatable presentation wins instead of turning the marker green.

## Event activity and presentation

The pfQuest quest `event` field means membership in a server game-event group.
It does **not** by itself mean either “active now” or “draw this quest green.”
Questie-Octo now resolves those concepts separately.

`Data/EventSchedule.lua` is a compact projection of the supplied Turtle
`game_event` table. Ordinary scheduled events are evaluated against realm wall
clock. Continuous release/content gates (`length >= occurrence`) remain usable
for availability but do not receive seasonal-event presentation. This prevents
permanent content such as event 159 (`DM Release : Cloth turning NPC`) from
making normal cloth donation quests green.

Darkmoon Faire uses the manually verified Turtle 14-day cycle, anchored at
2026-08-13:

- six days Elwynn (Thursday through Tuesday);
- one Wednesday construction day;
- six days Mulgore (Thursday through Tuesday);
- one Wednesday construction day;
- repeat indefinitely.

Major annual festivals use `Data/CalendarEventRules.lua`, transcribed from the
2026 in-game Turtle calendar. Only visible event text counts. Raid Reset,
roadmap/release announcements and graphic-only calendar cells are ignored.
Known calendar windows are authoritative for quest visibility; clicking a
festival NPC outside its verified window cannot reactivate that festival.
Unknown/custom event IDs still require runtime evidence.

A few quest event IDs exist in the current pfQuest/Turtle quest data without a
matching row in the supplied `game_event` table. Event 172 is explicitly
handled as a persistent compatibility gate because the authoritative quest data
uses it for Molten Core attunement. Missing true-event IDs 26, 99, 166 and 171
retain event presentation but require runtime observation rather than being
assumed active globally.

## Map/node invariants

- Availability, node and prepared-map rebuilds publish transactionally; the
  previous complete snapshot remains visible until its replacement is ready.
- Full Nodes use pfQuest's exact `node.tga` and **native 14 px pfQuest baseline
  at global scale 1.0**.
- Full Nodes keep the requested additional 15% transparency and subdued color.
- There is no separate Full Node or category scale setting. Only global World
  Map and global Minimap scale remain.
- Global scaling changes frame dimensions only; it cannot replace Full Node
  artwork with Questie objective artwork.
- Full-node semantic state survives visual refreshes/rescaling.
- World map and minimap retain a hidden 1000-node emergency cap.
- General -> Show All Quests on World Map defaults enabled. It controls available pickup/item-start presentation on the World Map only; active objectives/turn-ins, minimap, and tracker are unaffected.
- Distance fading is absent.
- Object-ID display is absent; Quest, NPC and Item IDs remain optional.

## Quests browser

The browser remains a fixed native frame rather than a large AceGUI result tree:

- 18 recycled result rows;
- no full-database scan merely for opening the browser;
- Options-to-Quests handoff is deferred until after AceConfig's execute refresh,
  then Questie Options and the Game Menu are explicitly hidden;
- searches only run on Enter/Search;
- search titles are lowercased/cached during the existing incremental database
  index build;
- full text/ID searches run in 33-quest scheduler slices (about 32% more work per
  frame than the previous 25-row search while remaining frame-sliced);
- visible results remain capped at 100;
- Available/Active/Completed no-query views use their state tables directly;
- closing the browser invalidates an outstanding search generation.

Unavailable rows explain *why* the quest cannot currently be taken in the right
pane.

`Data/QuestRewards.lua` is a compact projection of the supplied authoritative
Turtle `quest_template` reward fields. The right pane shows positive money
rewards in gold/silver/copper text, guaranteed reward items as native clickable
item hyperlinks, and choice rewards under `Choose one:`. No reward icons are
created. Item links use the same Vanilla `SetItemRef` / `GameTooltip:SetHyperlink`
pattern as pfQuest's item browser.

## Static audit completed for Beta 1.1

- 99 bundled Lua files pass a Lua parser syntax-load check.
- Every TOC file reference exists.
- Every XML Include/Script reference exists.
- All literal settings reads/writes resolve to defined defaults.
- No first-party runtime module outside `Database/` directly reads `pfDB`.
- No runtime distance-fading option/path remains.
- No user-facing Level Above Player setting/path remains.
- No Completion tracker-sort mode remains.
- No Object-ID option/render path remains (only stale SavedVariable cleanup).
- Only global Map and Minimap scale sliders remain.
- Full-node 1000-pin safety caps remain in both renderers.
- pfQuest Full Node and Questie repeatable assets match their supplied reference
  files byte-for-byte.
- 33 of the 34 raw loaded pfQuest/Turtle DB files are byte-identical to their
  supplied source files; the remaining Turtle `patchtable.lua` is the existing
  Questie-Octo compatibility adaptation that applies the overlay without
  loading pfQuest's addon UI/runtime.

## Recommended in-game regression pass

1. Open **Quests** from Questie Options and confirm Options/Game Menu disappear.
2. Search `defias`; compare response time and inspect several Unavailable rows.
3. Select quests with money, fixed-item and choice-item rewards; hover/click the
   hyperlink text.
4. Compare a normal cloth donation with an `Additional Runecloth` follow-up.
5. Verify `Give Gerard a Drink` uses the authentic blue repeatable pickup icon.
6. Verify Darkmoon immediately after `/reload` and again across its Wednesday
   installation transition.
7. Move global Map/Minimap scale repeatedly while Full Nodes are visible.
8. Recheck failed timed quests, reputation gates and multi-step prerequisites.


## 0.3.6 corrective notes

- Event availability now mirrors pfQuest: a quest's `event` membership does not
  locally gate availability. The Show Event Quests toggle is the display gate.
  The separate presentation classifier still prevents permanent Turtle content
  gates such as event 159 from being painted as festival quests.
- Quests search uses the database's already-cached lowercase titles in 768-ID
  bounded slices (roughly nine frames for the entire current DB) and exact numeric
  quest IDs bypass the scan entirely.
- Authoritative donation verification: 80374 (Additional Runecloth: Silvermoon
  Remnants) and 80379 (Additional Runecloth: Revantusk Tribe) are repeatable.
  80374 has server minimum level 50; it is correctly unavailable to a level-34
  character. Goblin donation quests 41115 (Cartel Gold Donations, min 30) and
  41123 (Donations to Vizlow, min 1) are repeatable and level-eligible at 34.


## 0.3.7 conservative event beta notes

- Fresh installs default `showEventQuests=false`; existing character choices are
  not overwritten.
- `IsPresentationEvent` separates true festival presentation from permanent
  game_event release/content gates.
- Available festival markers require both the user toggle and
  `EventAvailability:IsActiveForQuest()`. Scheduled/hardcoded event truth is
  preferred; unknown schedules require runtime observation.
- Runtime observation triggers a bounded availability refresh only on the first
  inactive-to-active transition.
- Active quests already in the quest log bypass available-quest filtering and
  therefore retain objectives/turn-ins even if event display is disabled.


## 0.3.8 curated Turtle calendar notes

The manually verified annual windows are:

- Love is in the Air: February 1-16
- Lunar Festival: February 16-March 4
- Noblegarden: April 17-May 8
- Midsummer Fire Festival: June 21-July 12
- Brewfest: September 20-October 6
- Harvest Festival: October 1-8
- Hallow's End: October 20-November 2
- Feast of Winter Veil: December 3-January 14

Darkmoon Faire is intentionally separate from the annual calendar and uses the
anchored alternating 14-day rule described above. Roadmap names such as
Frostmane Hollow, Windhorn Canyon, Dragonmaw Retreat, Northwind, Stormwrought
Ruins, Moonwhisper Coast, Phase 1/2 and similar release notices never affect
quest availability.

## Beta 1.1 event standby policy

Event membership is not itself proof of a seasonal event. Beta 1.1 uses an
explicit three-way classification:

- verified non-seasonal/content gates: ordinary quest availability/presentation;
- verified seasonal events: gated by the curated annual calendar, the anchored
  Darkmoon cycle, or a separately verified narrow timer;
- unknown/unverified event IDs: standby and therefore not published as available
  quest markers. Active quests already accepted by the player remain visible.

Event 159 is explicitly verified as the cloth-turn-in content/release gate and
is not seasonal. Repeatability remains independent of event classification.

## Beta 1.1 package identity

- Install folder: `Questie-Octo`
- TOC file: `Questie-Octo.toc`
- Display title: `Questie-Octo`
- Author: `Questie-Octo`
- Version: `Beta 1.1`

The versioned install folder is intentional for this beta package. First-party
texture paths were updated to the same folder name and validated before packaging.

## PvP quest classification

Questie-Octo preserves the authoritative Turtle quest `Type` for PvP quests.
`Type == 41` is the canonical PvP classification used by Questie 6.

Presentation priority for quest pickup/turn-in markers is:

1. PvP (red)
2. Repeatable (blue)
3. verified Event (green)
4. Normal (yellow)

The supplied Turtle source currently reports Blood Ring quests 41107-41110 as
Type 0 even though their objectives/rewards explicitly identify them as PvP.
Questie-Octo corrects only those verified rows locally to Type 41; Type 0 is
not broadly reinterpreted.

## Beta 1.1 Darkmoon live-offer correction

Live Elwynn Faire cross-checks on 2026-08-14 confirmed that Turtle reuses the
same Darkmoon hand-in NPCs/quests across Elwynn and Mulgore while pfQuest splits
those shared rows between event IDs 4 and 5. The verified starter set is Silas
Darkmoon (14823), Gelvas Grimegate (14828), Yebb Neblegear (14829), Kerri Hicks
(14832), Chronos (14833), and Rinling (14841).

For quests tagged event 4/5 and started by those NPCs, Questie-Octo treats the
Faire as one logical active event. During an active Faire it keeps completion,
race/class, level, max-level, timed and repeatable-option checks, but does not
let stale pfQuest Darkmoon reputation/chain metadata suppress an offer that the
live Turtle quest dialog exposes. Silas's one-time Torta's Egg remains hidden
once historical completion says it was rewarded.

### Darkmoon logical event alias

Turtle/pfQuest quest rows use both `event = 4` and `event = 5` for quest offers that are shared by the same Darkmoon Faire NPCs in both Elwynn and Mulgore. Questie-Octo preserves the authoritative value as `rawEventID`, but normalizes runtime `eventID` 5 to logical event 4. Availability and presentation therefore see one `DARKMOON_FAIRE` event; the anchored 14-day schedule and NPC coordinates determine the physical location. Construction events 23/24 remain distinct.

## Restless / custom Dun Morogh map note

`Restless` (41640) must be interpreted against Turtle/Octo's custom Dun Morogh, not
the stock Vanilla artwork/boundary assumptions. The current Dun Morogh map visibly
includes custom southeastern terrain such as Rugford's Mountain Rest. Durmir Rugford
(62199) has map representations in both Dun Morogh (1) and Grim Reaches (5602).
Hurl Cinderfist (62200), the 100% source for Durmir's Belongings (41686), now also
has both representations: Dun Morogh 83.2/70.8 and Grim Reaches 4.1/92.0. Both are
the same live world spawn transformed through the two overlapping WorldMapArea
bounds. Keep both so the active objective is visible on Turtle's expanded Dun
Morogh map as well as Grim Reaches; do not collapse these coordinates based on
stock Vanilla Dun Morogh assumptions.

## Turtle low-level gray available marker

Questie-Octo 1.0.77 adds a gray available `!` presentation for ordinary
available quests and ordinary item-start quests using the Turtle-specific
accepted boundary:

- player level <= quest level + 25: normal yellow available marker;
- player level >= quest level + 26: gray available marker.

The boundary is strict: exactly +25 remains yellow and +26 becomes gray.

The source basis is Turtle's custom quest XP rule in Tortoise
`src/game/QuestDef.cpp`, which retains full quest XP through `qLevel + 25`
before reducing it at +26 and beyond. That server function computes XP, not
client icon color directly, so the project does not claim it is itself the
native marker-color implementation. It was adopted because it matches the
observed Turtle native quest behavior and replaces the stock Questie
`GetQuestGreenRange()` assumption that was contradicted in-game.

Special presentation remains higher priority than gray: PvP stays red,
repeatable stays blue, and verified event/seasonal stays green. CLUCK! (3861)
is the deliberate exception already chosen by the project: its single
representative discovery marker stays ordinary yellow rather than repeatable
blue or low-level gray. Turn-in `?` markers are unchanged.

This gray classification is presentation-only and remains independent from the
`Levels Below` visibility slider. Level-up refreshes rebind visible Map and
Minimap marker textures without rebuilding quest data or map geometry.


## 1.0.78 zone-wide rare item-start tooltip compaction

The representative-marker rule for item-start sources below 0.50% must remain
representative in the tooltip as well as on the map. Previously the map correctly
collapsed those sources to one marker per quest/item/zone, but hovering that marker
still printed every represented creature type and spawn count. For large world-drop
items such as Pendant of Myzrael this could create a tooltip taller than the screen
and hide the actual quest/item information.

Zone-wide representative tooltips now show only a compact aggregate source count,
the quest, and the actual represented minimum/maximum drop-rate range. The underlying
source list remains unchanged. Ordinary non-zone-wide clustered item-start tooltips
still list their nearby source creatures normally.

## 1.0.79 representative-tooltip wording cleanup

Removed the redundant `One zone marker represents item-start sources below 0.50%.`
line from zone-wide rare item-start tooltips. The representative threshold and all
source/drop data remain unchanged; this is tooltip presentation only.
