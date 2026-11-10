--!strict
--[[
	Continuous world layout — NO region portals.
	Coordinates in studs. Player walks between regions via roads/gates.
]]

local WorldLayout = {}

-- Approximate map: ~6200 x 5000 studs design target (phase 1 uses subset)
WorldLayout.Spawn = {
	RegionId = "Aurenholm",
	CFrame = CFrame.new(0, 12, 0), -- outside eastern approach / gate plaza placeholder
}

WorldLayout.Regions = {
	Aurenholm = {
		Id = "Aurenholm",
		DisplayName = "Aurenholm",
		Type = "Capital",
		Bounds = { Min = Vector3.new(-350, -50, -350), Max = Vector3.new(350, 200, 350) },
		Center = Vector3.new(0, 10, 0),
		LevelRange = { 1, 60 },
		ConnectedTo = { "Eldoria", "Nocthold", "Morven" },
		ExitGates = {
			{
				Id = "EastGate_Eldoria",
				DisplayName = "Eastern Gate — Road to Eldoria",
				Position = Vector3.new(320, 10, 0),
				LeadsToRegion = "Eldoria",
				RoadStart = Vector3.new(340, 10, 0),
			},
		},
		Zones = {
			{ Id = "CentralPlaza", Name = "Central Plaza", Position = Vector3.new(0, 10, 0), Radius = 80 },
			{ Id = "RoyalCastle", Name = "Royal Castle", Position = Vector3.new(0, 15, -180), Radius = 90 },
			{ Id = "Market", Name = "Market District", Position = Vector3.new(120, 10, 80), Radius = 70 },
			{ Id = "ForgeQuarter", Name = "Forge Quarter", Position = Vector3.new(-140, 10, 60), Radius = 50 },
			{ Id = "ArcaneAcademy", Name = "Arcane Academy", Position = Vector3.new(150, 12, -100), Radius = 55 },
			{ Id = "Temple", Name = "Temple of the Lost Keepers", Position = Vector3.new(-80, 12, -120), Radius = 45 },
			{ Id = "Tavern", Name = "The Broken Crown", Position = Vector3.new(60, 10, 140), Radius = 30 },
			{ Id = "Barracks", Name = "Royal Barracks", Position = Vector3.new(-160, 10, -40), Radius = 50 },
			{ Id = "EastGate", Name = "Eastern Gate", Position = Vector3.new(300, 10, 0), Radius = 40 },
		},
	},

	Eldoria = {
		Id = "Eldoria",
		DisplayName = "Eldoria — Enchanted Forest",
		Type = "Region",
		Bounds = { Min = Vector3.new(400, -50, -600), Max = Vector3.new(1500, 250, 600) },
		Center = Vector3.new(900, 20, 0),
		LevelRange = { 1, 8 },
		ConnectedTo = { "Aurenholm", "Viridia", "Nocthold" },
		Zones = {
			{ Id = "ForestRoad", Name = "Forest Road", Position = Vector3.new(500, 12, 0), Radius = 60 },
			{ Id = "MossyGlade", Name = "Mossy Light Glade", Position = Vector3.new(700, 14, 80), Radius = 70 },
			{ Id = "RuinedElfPost", Name = "Ruined Elven Post", Position = Vector3.new(850, 15, -100), Radius = 50 },
			{ Id = "WoodfolkVillage", Name = "Woodfolk Village", Position = Vector3.new(950, 14, 120), Radius = 80 },
			{ Id = "RootWaterfall", Name = "Waterfall of Ancient Roots", Position = Vector3.new(1100, 20, -50), Radius = 55 },
			{ Id = "AbandonedObservatory", Name = "Abandoned Observatory", Position = Vector3.new(1050, 35, 200), Radius = 40 },
			{ Id = "AncientTemple", Name = "Ancient Temple Entrance", Position = Vector3.new(1200, 16, 0), Radius = 45 },
			{ Id = "SacredGlade", Name = "Sacred Glade (Boss Arena)", Position = Vector3.new(1350, 18, 0), Radius = 95 },
		},
		DungeonEntrance = {
			Id = "TempleOfRoots",
			Position = Vector3.new(1200, 16, 0),
			DisplayName = "Temple of Roots",
		},
		BossArena = {
			Id = "ForestGuardianArena",
			Position = Vector3.new(1350, 18, 0),
			Radius = 90,
		},
	},
}

-- Road path samples (for markers / future path props)
WorldLayout.Roads = {
	{
		Id = "Aurenholm_to_Eldoria",
		From = Vector3.new(320, 10, 0),
		To = Vector3.new(500, 12, 0),
		Width = 26,
	},
}

WorldLayout.NPCs = {
	CommanderRys = {
		Id = "CommanderRys",
		DisplayName = "Commander Rys",
		Role = "QuestGiver",
		RegionId = "Aurenholm",
		Position = Vector3.new(-20, 10, -30),
		Dialogue = {
			Greeting = "Traveler. The eastern road grows quiet. Too quiet.",
			Offer = "A patrol is missing near Eldoria. Follow the road through the East Gate. Find what happened.",
		},
	},
	HeraldMira = {
		Id = "HeraldMira",
		DisplayName = "Herald Mira",
		Role = "Guide",
		RegionId = "Aurenholm",
		Position = Vector3.new(15, 10, 20),
		Dialogue = {
			Greeting = "Welcome to Aurenholm, heart of Aydra. The Keepers are gone — but the city still stands.",
		},
	},
	WoodfolkElder = {
		Id = "WoodfolkElder",
		DisplayName = "Elder Saan",
		Role = "QuestGiver",
		RegionId = "Eldoria",
		Position = Vector3.new(950, 14, 120),
		Dialogue = {
			Greeting = "The roots remember blood. The patrol came this way. The Temple stirs.",
		},
	},
	TempleWarden = {
		Id = "TempleWarden",
		DisplayName = "Warden of Roots",
		Role = "DungeonIntro",
		RegionId = "Eldoria",
		Position = Vector3.new(1190, 16, 10),
		Dialogue = {
			Greeting = "Beyond this gate sleeps the Forest Guardian. Enter only if your steel and will are ready.",
		},
	},
}

function WorldLayout.GetRegion(id: string)
	return WorldLayout.Regions[id]
end

function WorldLayout.GetNPC(id: string)
	return WorldLayout.NPCs[id]
end

return WorldLayout
