-- Questie-Octo curated Turtle WoW calendar rules.
--
-- These windows were transcribed from the in-game Turtle calendar for 2026.
-- The calendar is treated as a recurring annual schedule: only visible event
-- text counts. Raid Reset, roadmap/release announcements and graphic-only
-- calendar cells are intentionally ignored.
--
-- Darkmoon Faire is not part of this table. It follows its own anchored
-- 14-day Elwynn/Mulgore cycle in Quest/EventAvailability.lua.

QuestieOcto.CalendarEventRules = {
  -- Canonical seasonal/gameplay festivals.
  [1]  = { name="Midsummer Fire Festival", startMonth=6,  startDay=21, endMonth=7,  endDay=12 },
  [2]  = { name="Feast of Winter Veil",     startMonth=12, startDay=3,  endMonth=1,  endDay=14 },
  [7]  = { name="Lunar Festival",           startMonth=2,  startDay=16, endMonth=3,  endDay=4  },
  [8]  = { name="Love is in the Air",       startMonth=2,  startDay=1,  endMonth=2,  endDay=16 },

  -- Turtle currently has no quest rows tied to the Noblegarden game_event,
  -- but keep both known IDs here so future DB revisions inherit the calendar
  -- without another code change.
  [9]  = { name="Noblegarden",              startMonth=4,  startDay=17, endMonth=5,  endDay=8  },
  [28] = { name="Noblegarden",              startMonth=4,  startDay=17, endMonth=5,  endDay=8  },

  [11] = { name="Harvest Festival",          startMonth=10, startDay=1,  endMonth=10, endDay=8  },
  [12] = { name="Hallow's End",              startMonth=10, startDay=20, endMonth=11, endDay=2  },

  -- Brewfest is a Turtle custom event ID present in quest data but absent
  -- from the bundled tw_world_game_event snapshot.
  [26] = { name="Brewfest",                  startMonth=9,  startDay=20, endMonth=10, endDay=6  },
}

-- Calendar entries intentionally NOT used for quest availability:
-- Raid Reset; Phase 1/Phase 2; Festival; War; Frostmane Hollow;
-- Windhorn Canyon; Dragonmaw Retreat; Northwind; Stormwrought Ruins;
-- Moonwhisper Coast; and similar roadmap/release announcements.
