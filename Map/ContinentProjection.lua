QuestieOcto.ContinentProjection = QuestieOcto.ContinentProjection or {}
local C = QuestieOcto.ContinentProjection

-- Vanilla WorldMapArea bounds extracted by the authoritative pfQuest data toolchain.
-- They let zone-local quest coordinates be projected onto the continent map
-- without changing the canonical pfQuest coordinates stored on each node.
C.continents={
  [0]={name="Azeroth",xMin=-16000,yMin=-19199.90039,xMax=7466.600098,yMax=16000},
  [1]={name="Kalimdor",xMin=-11733.2998,yMin=-19733.21094,xMax=12799.90039,yMax=17066.59961},
}

C.zones={
  [1]={continent=0,name="DunMorogh",xMin=-7160.416504,yMin=-3122.916504,xMax=-3877.083252,yMax=1802.083252},
  [3]={continent=0,name="Badlands",xMin=-7547.916504,yMin=-4566.666504,xMax=-5889.583008,yMax=-2079.166504},
  [4]={continent=0,name="BlastedLands",xMin=-12800,yMin=-4591.666504,xMax=-10566.66602,yMax=-1241.666626},
  [8]={continent=0,name="SwampOfSorrows",xMin=-11150,yMin=-4516.666504,xMax=-9620.833008,yMax=-2222.916504},
  [10]={continent=0,name="Duskwood",xMin=-11516.66602,yMin=-1866.666626,xMax=-9716.666016,yMax=833.333313},
  [11]={continent=0,name="Wetlands",xMin=-4904.166504,yMin=-4525,xMax=-2147.916504,yMax=-389.583313},
  [12]={continent=0,name="Elwynn",xMin=-10254.16602,yMin=-1935.416626,xMax=-7939.583008,yMax=1535.416626},
  [14]={continent=1,name="Durotar",xMin=-1716.666626,yMin=-7249.999512,xMax=1808.333252,yMax=-1962.499878},
  [15]={continent=1,name="Dustwallow",xMin=-5533.333008,yMin=-6225,xMax=-2033.333252,yMax=-974.999939},
  [16]={continent=1,name="Aszhara",xMin=1960.416626,yMin=-8347.916016,xMax=5341.666504,yMax=-3277.083252},
  [17]={continent=1,name="Barrens",xMin=-5143.75,yMin=-7510.416504,xMax=1612.499878,yMax=2622.916504},
  [28]={continent=0,name="WesternPlaguelands",xMin=499.9999695,yMin=-3883.333252,xMax=3366.666504,yMax=416.6666565},
  [33]={continent=0,name="Stranglethorn",xMin=-15422.91602,yMin=-4160.416504,xMax=-11168.75,yMax=2220.833252},
  [36]={continent=0,name="Alterac",xMin=-366.6666565,yMin=-2016.666626,xMax=1500,yMax=783.333313},
  [38]={continent=0,name="LochModan",xMin=-6327.083008,yMin=-4752.083008,xMax=-4487.5,yMax=-1993.749878},
  [40]={continent=0,name="Westfall",xMin=-11733.33301,yMin=-483.333313,xMax=-9400,yMax=3016.666504},
  [41]={continent=0,name="DeadwindPass",xMin=-11533.33301,yMin=-3333.333252,xMax=-9866.666016,yMax=-833.333313},
  [44]={continent=0,name="Redridge",xMin=-10022.91602,yMin=-3741.666504,xMax=-8575,yMax=-1570.833252},
  [45]={continent=0,name="Arathi",xMin=-2533.333252,yMin=-4466.666504,xMax=-133.3333282,yMax=-866.666626},
  [46]={continent=0,name="BurningSteppes",xMin=-8983.333008,yMin=-3195.833252,xMax=-7031.249512,yMax=-266.6666565},
  [47]={continent=0,name="Hinterlands",xMin=-1100,yMin=-5425,xMax=1466.666626,yMax=-1575},
  [51]={continent=0,name="SearingGorge",xMin=-7587.499512,yMin=-2554.166504,xMax=-6100,yMax=-322.9166565},
  [85]={continent=0,name="Tirisfal",xMin=824.999939,yMin=-1485.416626,xMax=3837.499756,yMax=3033.333252},
  [130]={continent=0,name="Silverpine",xMin=-1133.333252,yMin=-750,xMax=1666.666626,yMax=3449.999756},
  [139]={continent=0,name="EasternPlaguelands",xMin=1218.75,yMin=-6056.25,xMax=3799.999756,yMax=-2185.416504},
  [141]={continent=1,name="Teldrassil",xMin=8437.5,yMin=-1277.083252,xMax=11831.25,yMax=3814.583252},
  [148]={continent=1,name="Darkshore",xMin=3966.666504,yMin=-3608.333252,xMax=8333.333008,yMax=2941.666504},
  [215]={continent=1,name="Mulgore",xMin=-3697.916504,yMin=-3089.583252,xMax=-272.9166565,yMax=2047.916626},
  [267]={continent=0,name="Hilsbrad",xMin=-1733.333252,yMin=-2133.333252,xMax=400,yMax=1066.666626},
  [331]={continent=1,name="Ashenvale",xMin=829.166626,yMin=-4066.666504,xMax=4672.916504,yMax=1699.999878},
  [357]={continent=1,name="Feralas",xMin=-6999.999512,yMin=-1508.333252,xMax=-2366.666504,yMax=5441.666504},
  [361]={continent=1,name="Felwood",xMin=3299.999756,yMin=-4108.333008,xMax=7133.333008,yMax=1641.666626},
  [400]={continent=1,name="ThousandNeedles",xMin=-6899.999512,yMin=-4833.333008,xMax=-3966.666504,yMax=-433.333313},
  [405]={continent=1,name="Desolace",xMin=-2545.833252,yMin=-262.5,xMax=452.083313,yMax=4233.333008},
  [406]={continent=1,name="StonetalonMountains",xMin=-339.583313,yMin=-1637.499878,xMax=2916.666504,yMax=3245.833252},
  [440]={continent=1,name="Tanaris",xMin=-10475,yMin=-7118.749512,xMax=-5875,yMax=-218.7499847},
  [490]={continent=1,name="UngoroCrater",xMin=-8433.333008,yMin=-3166.666504,xMax=-5966.666504,yMax=533.333313},
  [493]={continent=1,name="Moonglade",xMin=6952.083008,yMin=-3689.583252,xMax=8491.666016,yMax=-1381.25},
  [618]={continent=1,name="Winterspring",xMin=3799.999756,yMin=-7416.666504,xMax=8533.333008,yMax=-316.6666565},
  [1377]={continent=1,name="Silithus",xMin=-8281.25,yMin=-945.8339844,xMax=-5958.333984,yMax=2537.5},
  [1497]={continent=0,name="Undercity",xMin=1237.841187,yMin=-86.18240356,xMax=1877.945312,yMax=873.192627},
  [1519]={continent=0,name="Stormwind",xMin=-9175.205078,yMin=36.70063019,xMax=-8278.850586,yMax=1380.971436},
  [1537]={continent=0,name="Ironforge",xMin=-5096.845703,yMin=-1504.216431,xMax=-4569.241211,yMax=-713.5913696},
  [1637]={continent=1,name="Ogrimmar",xMin=1338.460571,yMin=-5083.205566,xMax=2273.877197,yMax=-3680.601074},
  [1638]={continent=1,name="ThunderBluff",xMin=-1545.833252,yMin=-527.083313,xMax=-849.999939,yMax=516.666626},
  [1657]={continent=1,name="Darnassis",xMin=9532.586914,yMin=1880.029541,xMax=10238.31641,yMax=2938.362793},
}

function C:GetClientContinentMapID(clientContinentID)
  clientContinentID=tonumber(clientContinentID)
  if clientContinentID==1 then return 1 end -- Kalimdor
  if clientContinentID==2 then return 0 end -- Eastern Kingdoms / Azeroth
  return nil
end

function C:GetZoneContinent(mapID)
  local z=self.zones[tonumber(mapID)]
  return z and z.continent or nil
end

function C:Project(mapID,x,y)
  local z=self.zones[tonumber(mapID)]
  if not z then return nil,nil,nil end
  local c=self.continents[z.continent]
  x=tonumber(x); y=tonumber(y)
  if not c or not x or not y then return nil,nil,nil end
  local zw=z.xMax-z.xMin
  local zh=z.yMax-z.yMin
  local cw=c.xMax-c.xMin
  local ch=c.yMax-c.yMin
  if zw==0 or zh==0 or cw==0 or ch==0 then return nil,nil,nil end
  -- pfQuest extractor conversion is:
  -- localX = 100 - (worldY-yMin)/(yMax-yMin)*100
  -- localY = 100 - (worldX-xMin)/(xMax-xMin)*100
  local worldY=z.yMin+((100-x)/100)*zh
  local worldX=z.xMin+((100-y)/100)*zw
  local cx=100-((worldY-c.yMin)/ch)*100
  local cy=100-((worldX-c.xMin)/cw)*100
  if cx<0 or cx>100 or cy<0 or cy>100 then return nil,nil,z.continent end
  return cx,cy,z.continent
end

function C:GetZoneMapIDs(continentMapID)
  continentMapID=tonumber(continentMapID)
  local result={}
  for mapID,z in pairs(self.zones) do
    if z.continent==continentMapID then table.insert(result,mapID) end
  end
  table.sort(result)
  return result
end
