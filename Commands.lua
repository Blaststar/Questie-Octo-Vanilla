SLASH_QUESTIEOCTO1="/qo"
SLASH_QUESTIEOCTO2="/questieocto"

local function Bool(v)
  return v and "true" or "false"
end

SlashCmdList["QUESTIEOCTO"]=function(msg)
  msg=string.lower(msg or "")
  local creatureStart,creatureEnd,creatureID=string.find(msg,"^creature%s+(%d+)$")
  local minimapStart,minimapEnd,minimapArg=string.find(msg,"^minimap%s+(.+)$")

  if msg=="visualdiag" then
    local mm=QuestieOcto.Minimap
    local shown=0
    local objective=0
    local colored=0
    local glowing=0

    if mm and mm.frames then
      for key,pin in pairs(mm.frames) do
        if pin:IsShown() then
          shown=shown+1
          local isObjective=pin.role=="objectiveCreature" or
                            pin.role=="objectiveObject" or
                            pin.role=="objectiveItemSource"
          if isObjective then
            objective=objective+1
            local r=pin.iconR or 1
            local g=pin.iconG or 1
            local b=pin.iconB or 1
            local glowShown=pin.glowTexture and pin.glowTexture:IsShown()
            if r~=1 or g~=1 or b~=1 then colored=colored+1 end
            if glowShown then glowing=glowing+1 end

            QuestieOcto:Print("VIS pin role/q/obj/rgb/glow="..
              tostring(pin.role).."/"..
              tostring(pin.questID or 0).."/"..
              tostring((pin.entries and next(pin.entries)) and "yes" or "no").."/"..
              string.format("%.2f,%.2f,%.2f",r,g,b).."/"..
              tostring(glowShown and true or false))
          end
        end
      end
    end

    QuestieOcto:Print("VIS summary shown/objective/colored/glowing="..
      tostring(shown).."/"..tostring(objective).."/"..
      tostring(colored).."/"..tostring(glowing))

  elseif msg=="" or msg=="options" or msg=="config" then
    QuestieOcto.Options:Toggle()

  elseif msg=="quests" then
    if QuestieOcto.QuestResearch then QuestieOcto.QuestResearch:OpenWindow() end

  elseif msg=="help" then
    QuestieOcto:Print("/qo -- toggle Questie-Octo options")
    QuestieOcto:Print("/qo quests -- open the Quests browser")
    QuestieOcto:Print("/qo options, /qo info, /qo minimap, /qo api, /qo resync, /qo questlog, /qo map")

  elseif msg=="info" then
    QuestieOcto:Print(tostring(QuestieOcto.version).." infrastructure diagnostic")
    QuestieOcto:Print("enabled="..Bool(QuestieOcto.enabled).." ready="..Bool(QuestieOcto.ready)..
      " ClassicAPI="..Bool(QuestieOcto.API.valid))

    local q=QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI:GetQuestCount() or 0
    QuestieOcto:Print("DB ready="..Bool(QuestieOcto.Database.ready)..
      " mergeJob="..tostring(QuestieOcto.Database.jobIndex).."/"..tostring(QuestieOcto.Database.stats.jobs)..
      " merged="..tostring(QuestieOcto.Database.stats.merged)..
      " quests="..tostring(q))

    local ql=QuestieOcto.QuestLog
    local activeComplete=0
    local activeObjectives=0
    for _,state in pairs(ql.active or {}) do
      if state.complete then activeComplete=activeComplete+1 end
      activeObjectives=activeObjectives+table.getn(state.objectives or {})
    end
    QuestieOcto:Print("QuestLog running="..Bool(QuestieOcto.QuestLog.running)..
      " entries="..tostring(QuestieOcto.QuestLog.stats.entries)..
      " quests="..tostring(QuestieOcto.QuestLog.stats.quests)..
      " resolvedIDs="..tostring(QuestieOcto.QuestLog.stats.resolved)..
      " activeComplete/objectives="..tostring(activeComplete).."/"..tostring(activeObjectives)..
      " refreshes="..tostring(QuestieOcto.QuestLog.stats.refreshes)..
      " acceptedFast="..tostring(QuestieOcto.QuestLog.stats.acceptedFastRefreshes or 0)..
      " acceptedEvt/resolved/fromIndex/last="..
      tostring(QuestieOcto.QuestLog.stats.acceptedEvents or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.acceptedResolved or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.acceptedFromIndex or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.lastAcceptedQuestID or 0)..
      " acceptedHint/prime/poll="..
      tostring(QuestieOcto.QuestLog.stats.acceptedHintsUsed or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.acceptedPrimes or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.acceptedPolls or 0)..
      " removedEvt/resolved/fromIndex/last="..
      tostring(QuestieOcto.QuestLog.stats.removedEvents or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.removedResolved or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.removedFromIndex or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.lastRemovedQuestID or 0))
    QuestieOcto:Print("QuestLog complete raw/objectives/money="..tostring(ql.completeRaw or 0).."/"..tostring(ql.completeObjectives or 0).."/"..tostring(ql.completeMoney or 0))

    local cp=QuestieOcto.Completion
    local completeIDs={}
    for questID,state in pairs(ql.active or {}) do
      if state.complete then table.insert(completeIDs,tostring(questID)) end
    end
    table.sort(completeIDs)
    QuestieOcto:Print("QuestLog complete IDs="..table.concat(completeIDs,","))
    QuestieOcto:Print("QuestLog complete raw/objectives/noObjectives/money="..
      tostring(QuestieOcto.QuestLog.stats.completeRaw or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.completeObjectives or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.completeNoObjectives or 0).."/"..
      tostring(QuestieOcto.QuestLog.stats.completeMoney or 0))

    QuestieOcto:Print("Completion ready="..Bool(cp.ready)..
      " packets="..tostring(cp.receivedPackets)..
      " completed="..tostring(cp:Count())..
      " turnIns="..tostring(cp.stats.turnIns or 0))

    local av=QuestieOcto.AvailableQuests
    local st=av.stats or {}
    QuestieOcto:Print("AvailableQuests ready="..Bool(av.ready)..
      " running="..Bool(av.running)..
      " scan="..tostring(math.min(av.pos or 0,table.getn(av.queue or {}))).."/"..tostring(table.getn(av.queue or {}))..
      " available="..tostring(st.available or 0))

    QuestieOcto:Print("Availability rejected completed/active/level/pre/exclusive/race/class/event/noStarter="..
      tostring(st.completed or 0).."/"..tostring(st.active or 0).."/"..tostring(st.level or 0).."/"..
      tostring(st.prerequisite or 0).."/"..tostring(st.exclusive or 0).."/"..
      tostring(st.race or 0).."/"..tostring(st.class or 0).."/"..tostring(st.noStarter or 0))

    local ob=QuestieOcto.Objectives
    local objectiveQuestModels=0
    for _ in pairs(ob.byQuest or {}) do objectiveQuestModels=objectiveQuestModels+1 end
    QuestieOcto:Print("Objectives ready/running="..Bool(ob.ready).."/"..Bool(ob.running)..
      " questModels="..tostring(objectiveQuestModels)..
      " scanned="..tostring(ob.stats.quests or 0)..
      " creature/object/item/itemSources="..
      tostring(ob.stats.creature or 0).."/"..tostring(ob.stats.object or 0).."/"..
      tostring(ob.stats.item or 0).."/"..tostring(ob.stats.itemSources or 0)..
      " mapped/unmapped="..tostring(ob.stats.mapped or 0).."/"..tostring(ob.stats.unmapped or 0)..
      " direct/fallback/typeMismatch="..tostring(ob.stats.direct or 0).."/"..
      tostring(ob.stats.fallback or 0).."/"..tostring(ob.stats.typeMismatch or 0)..
      " fuzzy/single="..tostring(ob.stats.fuzzy or 0).."/"..tostring(ob.stats.single or 0)..
      " rebuilds/waits="..tostring(ob.stats.rebuilds or 0).."/"..tostring(ob.stats.dependencyWaits or 0))

    local it=QuestieOcto.ItemStarts
    QuestieOcto:Print("ItemStarts ready="..Bool(it.ready)..
      " quests/items/creatureSources/objectSources="..
      tostring(it.stats.quests or 0).."/"..tostring(it.stats.starterItems or 0).."/"..
      tostring(it.stats.creatureSources or 0).."/"..tostring(it.stats.objectSources or 0))

    local nd=QuestieOcto.Nodes
    QuestieOcto:Print("Nodes ready="..Bool(nd.ready)..
      " total="..tostring(nd.stats.total or 0)..
      " availCreature/object/itemStart="..
      tostring(nd.stats.availableCreature or 0).."/"..tostring(nd.stats.availableObject or 0).."/"..
      tostring(nd.stats.itemStart or 0))
    QuestieOcto:Print("Nodes active creature/object/itemSource/turnin="..
      tostring(nd.stats.objectiveCreature or 0).."/"..tostring(nd.stats.objectiveObject or 0).."/"..
      tostring(nd.stats.objectiveItemSource or 0).."/"..tostring(nd.stats.turnin or 0))

    local mp=QuestieOcto.Map
    QuestieOcto:Print("Map active/created/reused/hidden="..
      tostring(mp.stats.active or 0).."/"..tostring(mp.stats.created or 0).."/"..
      tostring(mp.stats.reused or 0).."/"..tostring(mp.stats.hidden or 0)..
      " syncs="..tostring(mp.stats.syncs or 0))
    QuestieOcto:Print("Map visible available/itemStart/objective/turnin="..
      tostring(mp.stats.visibleAvailable or 0).."/"..tostring(mp.stats.visibleItemStart or 0).."/"..
      tostring(mp.stats.visibleObjective or 0).."/"..tostring(mp.stats.visibleTurnin or 0)..
      " mapID="..tostring(mp.mapID)..
      " inputNodes="..tostring(mp.stats.inputNodes or 0)..
      " mergedPins="..tostring(mp.stats.multiEntryPins or 0))
    QuestieOcto:Print("ItemStart rawNodes/areaPins="..
      tostring(mp.stats.itemStartRawNodes or 0).."/"..tostring(mp.stats.itemStartAreaPins or 0))

    local pm=QuestieOcto.PreparedMap
    QuestieOcto:Print("Prepared maps/descriptors/running/currentReady="..
      tostring(pm.stats.preparedMaps or 0).."/"..tostring(pm.stats.descriptors or 0).."/"..
      Bool(pm.running).."/"..Bool(pm.stats.currentReady)..
      " revision/bumps="..tostring(pm.stateRevision or 0).."/"..tostring(pm.stats.revisionBumps or 0))
    QuestieOcto:Print("Map prepared hits/misses/descriptors="..
      tostring(mp.stats.preparedHits or 0).."/"..tostring(mp.stats.preparedMisses or 0).."/"..
      tostring(mp.stats.preparedDescriptors or 0))

    local ci=QuestieOcto.MapCandidateIndex
    QuestieOcto:Print("CandidateIndex ready/running/scanned/maps/links/currentReady="..
      Bool(ci.ready).."/"..Bool(ci.running).."/"..tostring(ci.stats.scanned or 0).."/"..
      tostring(ci.stats.maps or 0).."/"..tostring(ci.stats.links or 0).."/"..Bool(ci.stats.currentReady))

    local zb=QuestieOcto.ZoneBootstrap
    QuestieOcto:Print("ZoneBootstrap ready/running/indexed/map/requested/scanned/candidates/available/nodes/itemSources="..
      Bool(zb.ready).."/"..Bool(zb.running).."/"..Bool(zb.stats.indexed).."/"..tostring(zb.mapID).."/"..tostring(zb.requestedMapID).."/"..
      tostring(zb.stats.scanned or 0).."/"..tostring(zb.stats.candidates or 0).."/"..
      tostring(zb.stats.available or 0).."/"..tostring(zb.stats.nodes or 0).."/"..
      tostring(zb.stats.itemSources or 0))
    QuestieOcto:Print("ZoneBootstrap requests/cancelled mapPriorityRequests="..
      tostring(zb.stats.requests or 0).."/"..tostring(zb.stats.cancelled or 0).."/"..
      tostring(mp.stats.mapPriorityRequests or 0))

    QuestieOcto:Print("Quest visibility policy=low-level quests shown")
    QuestieOcto:Print("Quest refresh policy=Questie immediate unload + 335 fast refresh")
    QuestieOcto:Print("Scheduler policy=Questie-335 every-frame thread slices")
    QuestieOcto:Print("Startup policy=immediate completion/log + 335 fast initial availability")
    QuestieOcto:Print("Quest accept policy=immediate unload + fast objective-cache retry")

    local mm=QuestieOcto.Minimap
    QuestieOcto:Print("Minimap enabled/active/map/refreshes/updates="..
      Bool(mm and mm.enabled).."/"..tostring(mm and mm.stats.active or 0).."/"..
      tostring(mm and mm.mapID or "nil").."/"..
      tostring(mm and mm.stats.refreshes or 0).."/"..
      tostring(mm and mm.stats.positionUpdates or 0))
    local ms=QuestieOcto.MinimapSettings
    QuestieOcto:Print("Minimap mapContext restores/reason="..
      tostring(mm and mm.stats.mapContextRestores or 0).."/"..
      tostring(mm and mm.stats.lastMapContextReason or "none"))
    QuestieOcto:Print("Scale rescalePasses map/minimap="..
      tostring(QuestieOcto.Map.stats.rescalePasses or 0).."/"..
      tostring(QuestieOcto.Minimap.stats.rescalePasses or 0))
    QuestieOcto:Print("Scale resize map count/last="..
      tostring(QuestieOcto.Map.stats.scaleResizes or 0).."/"..
      tostring(QuestieOcto.Map.stats.lastScaleSize or 0)..
      " minimap count/last="..
      tostring(QuestieOcto.Minimap.stats.scaleResizes or 0).."/"..
      tostring(QuestieOcto.Minimap.stats.lastScaleSize or 0))
    QuestieOcto:Print("Map settings enabled/scale/objectives/turnins/available="..
      Bool(ms:Get("enableMapIcons")).."/"..
      tostring(ms:Get("globalScale")).."/"..
      Bool(ms:Get("enableObjectives")).."/"..
      Bool(ms:Get("enableTurnins")).."/"..
      Bool(ms:Get("enableAvailable")))
    QuestieOcto:Print("Minimap settings enabled/scale="..
      Bool(ms:Get("enableMiniMapIcons")).."/"..tostring(ms:Get("globalMiniMapScale")))
    QuestieOcto:Print("Minimap unload policy=Questie quest-wide world+minimap + prepared-cache purge")
    QuestieOcto:Print("Minimap visibility policy=all marker centers visible to minimap edge")
    QuestieOcto:Print("Objective icon policy=Questie slay/loot/interact by objective kind")
    QuestieOcto:Print("Turnin icon policy=Questie separate exact frame + complete overlay 6 above available 5")
    QuestieOcto:Print("Quest remove policy=Questie immediate quest-wide unload before redraw")
    QuestieOcto:Print("Minimap visible available/itemStart/objective/turnin="..
      tostring(mm and mm.stats.visibleAvailable or 0).."/"..
      tostring(mm and mm.stats.visibleItemStart or 0).."/"..
      tostring(mm and mm.stats.visibleObjective or 0).."/"..
      tostring(mm and mm.stats.visibleTurnin or 0))
    local op=QuestieOcto.Options
    QuestieOcto:Print("Options Ace initialized/shown/opens/closes/changes="..
      Bool(op and op.initialized).."/"..
      Bool(op and op.configFrame and op.configFrame:IsShown()).."/"..
      tostring(op and op.stats.opens or 0).."/"..tostring(op and op.stats.closes or 0).."/"..
      tostring(op and op.stats.changes or 0))
    QuestieOcto:Print("Options tabs=General/Map/Minimap/Tooltips/Advanced/Quests")
    QuestieOcto:Print("Options visuals glowMap/glowMini/colorMap/colorMini="..
      tostring(QuestieOcto.MinimapSettings:Get("alwaysGlowMap")).."/"..
      tostring(QuestieOcto.MinimapSettings:Get("alwaysGlowMinimap")).."/"..
      tostring(QuestieOcto.MinimapSettings:Get("questObjectiveColors")).."/"..
      tostring(QuestieOcto.MinimapSettings:Get("questMinimapObjectiveColors")))

    local miniGlow=0
    local miniColor=0
    if QuestieOcto.Minimap and QuestieOcto.Minimap.frames then
      for _,pin in pairs(QuestieOcto.Minimap.frames) do
        if pin.glowTexture and pin.glowTexture:IsShown() then miniGlow=miniGlow+1 end
        if (pin.iconR and pin.iconR~=1) or (pin.iconG and pin.iconG~=1) or (pin.iconB and pin.iconB~=1) then
          miniColor=miniColor+1
        end
      end
    end
    QuestieOcto:Print("Minimap visual applied glow/colored="..tostring(miniGlow).."/"..tostring(miniColor))
    QuestieOcto:Print("Options availability lowLevel/repeatable/event/pvp="..
      tostring(QuestieOcto.MinimapSettings:Get("showLowLevelQuests")).."/"..
      tostring(QuestieOcto.MinimapSettings:Get("showRepeatableQuests")).."/"..
      tostring(QuestieOcto.MinimapSettings:Get("showEventQuests")).."/"..
      tostring(QuestieOcto.MinimapSettings:Get("showPvPRelatedQuests")))
    QuestieOcto:Print("Options AceGUI/registry/dialog="..
      Bool(op and op.stats.aceGUI).."/"..Bool(op and op.stats.aceRegistry).."/"..Bool(op and op.stats.aceDialog))
    QuestieOcto:Print("Options lastSet key/value="..
      tostring(op and op.stats.lastSetKey or "none").."/"..
      tostring(op and op.stats.lastSetValue or "none"))
    local gm=QuestieOcto.GameMenu
    QuestieOcto:Print("GameMenu installed/clicks/anchor="..
      Bool(gm and gm.installed).."/"..tostring(gm and gm.stats.clicks or 0).."/"..
      tostring(gm and gm.stats.anchor or "none"))
    QuestieOcto:Print("Rare tooltip policy=static DB respawn only; no kill tracking")
    QuestieOcto:Print("Scheduler queued="..tostring(table.getn(QuestieOcto.Scheduler.queue))..
      " executed="..tostring(QuestieOcto.Scheduler.executed))

  elseif msg=="minimap" then
    local ms=QuestieOcto.MinimapSettings
    QuestieOcto:Print("minimap enabled="..Bool(ms:Get("enableMiniMapIcons"))..
      " scale="..tostring(ms:Get("globalMiniMapScale")))
    QuestieOcto:Print("/qo minimap on|off, scale <0.01-4>, reset")

  elseif minimapArg then
    local ms=QuestieOcto.MinimapSettings
    local actionStart,actionEnd,action,value=string.find(minimapArg,"^(%S+)%s*(.*)$")
    local changed=false

    if action=="on" then
      changed=ms:Set("enableMiniMapIcons",true)
    elseif action=="off" then
      changed=ms:Set("enableMiniMapIcons",false)
    elseif action=="scale" then
      changed=ms:Set("globalMiniMapScale",tonumber(value))
    elseif action=="reset" then
      ms:Reset()
      changed=true
    end

    if changed then
      QuestieOcto:Print("minimap setting updated")
    else
      QuestieOcto:Print("invalid minimap setting; use /qo minimap")
    end

  elseif msg=="api" then
    local ok=QuestieOcto.API:Validate()
    QuestieOcto:Print("ClassicAPI contract valid="..Bool(ok))

    if not ok then
      for _,name in pairs(QuestieOcto.API.missing) do
        QuestieOcto:Error("missing "..name)
      end
    else
      local o=QuestieOcto.API.optional
      QuestieOcto:Print("optional: coroutines="..Bool(o.coroutines)..
        " hooksecurefunc="..Bool(o.hooksecurefunc)..
        " questDetails="..Bool(o.questDetails)..
        " mapWorldSize="..Bool(o.mapWorldSize))
    end

  elseif msg=="resync" then
    QuestieOcto.Completion:Start()
    QuestieOcto:Print("requested Turtle completion history")

  elseif msg=="questlog" then
    QuestieOcto.QuestLog:Schedule(0)
    QuestieOcto:Print("scheduled quest-log refresh")

  elseif msg=="map" then
    QuestieOcto.Map:RequestSync(true)
    QuestieOcto:Print("scheduled world-map sync")

  elseif creatureID then
    QuestieOcto.CreatureDiagnostics:Trace(tonumber(creatureID))

  elseif msg=="quest178" then
    local q=QuestieOcto.QuestModel:Get(178)
    if not q then
      QuestieOcto:Print("quest 178 model unavailable")
    else
      QuestieOcto:Print("quest178 title="..tostring(q.title)..
        " level="..tostring(q.level)..
        " required="..tostring(q.requiredLevel))
      QuestieOcto:Print("quest178 startItem="..tostring(q.starts.item and q.starts.item[1])..
        " completed="..Bool(QuestieOcto.Completion:IsComplete(178))..
        " available="..Bool(QuestieOcto.AvailableQuests:IsQuestAvailable(178)))

      local resolved=QuestieOcto.ItemStarts.byQuest[178]
      local creatures=0
      local objects=0
      if resolved then
        for _,item in pairs(resolved.items) do
          creatures=creatures+table.getn(item.creatureSources or {})
          objects=objects+table.getn(item.objectSources or {})
        end
      end
      QuestieOcto:Print("quest178 resolved item-start sources creature/object="..
        tostring(creatures).."/"..tostring(objects))
    end

  else
    QuestieOcto:Print("/qo -- options; /qo help for commands")
  end
end
