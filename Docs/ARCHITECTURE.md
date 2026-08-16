# Questie-Octo architecture base

## Non-negotiable design

- ClassicAPI is the only required enhanced-client compatibility layer.
- SuperWoW and Nampower may be detected later, but no core feature may depend on them.
- Questie 5.2.3 is the main UI/behavior target.
- Questie 6.0.0 is the architecture bridge.
- Questie 7-9 are bug-fix references.
- Questie 10-11 are references for service separation and mature availability logic.
- Questie 11.34.1 is an edge-case reference, not a runtime base.
- pfQuest/pfQuest-turtle are transitional raw data/reference sources only.
- Tortoise/Turtle server data should become the authoritative offline-generated relationship layer.
- No heavy whole-world calculation may run in one frame.
- Login and zone changes must remain responsive.
- Map nodes will use persistent diff/reuse, never continuous clear/recreate.

## Runtime service order

ClassicAPI contract
  -> Scheduler
  -> raw-data provider merge (incremental)
  -> QuestLog cache (ClassicAPI IDs)
  -> Turtle completion history
  -> canonical Quest model
  -> AvailableQuests
  -> Objectives / ItemStarts
  -> persistent Map + Minimap
  -> Tracker / Tooltips / Options

## 0.1.0 scope

0.1.0 intentionally stops after:
- ClassicAPI verification
- gentle scheduler
- isolated raw DB provider
- ClassicAPI quest-ID quest log cache
- Turtle .queststatus / TWQUEST completion service
- diagnostics

No map, minimap, tracker, availability engine, or tooltip UI yet.


## 0.1.1 milestone

Introduces the public database boundary and canonical quest services:

Legacy/raw data provider
  -> DatabaseAPI
  -> QuestModel
  -> Completion + QuestLog
  -> AvailableQuests

No module outside Database/ should add new direct pfDB dependencies.


## 0.1.3 milestone

Adds the canonical node-generation boundary:

QuestModel
  -> Objectives
  -> ItemStarts
  -> Nodes
  -> future persistent Map/Minimap

Map/Minimap must consume Nodes and must not rediscover quest/item/source
relationships itself.

## Quest-truth publication rules

The runtime quest system is intentionally layered:

pfQuest/Turtle raw DB truth
  -> QuestModel semantic normalization
  -> Completion / EventAvailability / QuestLog runtime truth
  -> AvailableQuests transactional snapshot
  -> Objectives / ItemStarts
  -> Nodes transactional snapshot
  -> PreparedMap
  -> World Map / Minimap / Tracker / Quests browser

Important invariants:

- `lvl` is presentation/difficulty; `min` is the minimum-level availability gate.
- A quest DB `event` value is event membership only. It never means the event is active now.
- Repeatability and event membership are independent flags; rendering must use an explicit precedence instead of assuming one classification excludes the other.
- Completion data must be queried authoritatively before it is published. When `QueryQuestsCompleted` exists, request the cache and wait for `QUEST_QUERY_COMPLETE` before reading `GetQuestsCompleted`; otherwise use the Turtle `.queststatus` / `TWQUEST` fallback.
- Async services never clear a published live snapshot while rebuilding it. Build into a private buffer and atomically swap at the publication boundary. This prevents map/minimap blinking during settings or quest-state refreshes.
- Prepared/map presentation stays valid until a complete replacement node snapshot exists.
