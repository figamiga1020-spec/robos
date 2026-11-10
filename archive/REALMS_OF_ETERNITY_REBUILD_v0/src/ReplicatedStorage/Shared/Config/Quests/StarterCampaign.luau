--!strict
--[[
	First adventure (~35–60 min design): Aurenholm → Eldoria → Temple → Forest Guardian
	5 linked quests. Continuous travel, no portals.
]]

local StarterCampaign = {}

StarterCampaign.Quests = {
	Q1_Arrival = {
		Id = "Q1_Arrival",
		DisplayName = "Arrival at Aurenholm",
		Description = "Speak with Herald Mira on the central approach and learn the state of the capital.",
		Type = "Main",
		Level = 1,
		Giver = "HeraldMira",
		TurnIn = "HeraldMira",
		Prerequisites = {},
		Objectives = {
			{ Id = "TalkHerald", Type = "Talk", TargetId = "HeraldMira", Count = 1, Text = "Speak with Herald Mira" },
		},
		Rewards = { Experience = 40, Gold = 15, Items = { { ItemId = "HealthPotion", Amount = 3 } } },
		Next = "Q2_MissingPatrol",
	},

	Q2_MissingPatrol = {
		Id = "Q2_MissingPatrol",
		DisplayName = "Traces on the Old Road",
		Description = "Commander Rys needs the missing patrol investigated on the road toward Eldoria.",
		Type = "Main",
		Level = 1,
		Giver = "CommanderRys",
		TurnIn = "CommanderRys",
		Prerequisites = { "Q1_Arrival" },
		Objectives = {
			{ Id = "TalkCommander", Type = "Talk", TargetId = "CommanderRys", Count = 1, Text = "Report to Commander Rys" },
			{ Id = "ReachEastGate", Type = "Reach", TargetId = "EastGate", Count = 1, Text = "Reach the Eastern Gate" },
		},
		Rewards = { Experience = 60, Gold = 25, Items = {} },
		Next = "Q3_IntoEldoria",
	},

	Q3_IntoEldoria = {
		Id = "Q3_IntoEldoria",
		DisplayName = "Into the Enchanted Forest",
		Description = "Follow the forest road into Eldoria. Defeat corrupted beasts and find the Woodfolk village.",
		Type = "Main",
		Level = 1,
		Giver = "CommanderRys",
		TurnIn = "WoodfolkElder",
		Prerequisites = { "Q2_MissingPatrol" },
		Objectives = {
			{ Id = "ReachForestRoad", Type = "Reach", TargetId = "ForestRoad", Count = 1, Text = "Enter the Forest Road" },
			{ Id = "KillBrigands", Type = "Kill", TargetId = "ForestBrigand", Count = 4, Text = "Defeat 4 Forest Brigands" },
			{ Id = "KillBeasts", Type = "Kill", TargetId = "CorruptedWolf", Count = 3, Text = "Defeat 3 Corrupted Wolves" },
			{ Id = "ReachVillage", Type = "Reach", TargetId = "WoodfolkVillage", Count = 1, Text = "Reach Woodfolk Village" },
			{ Id = "TalkElder", Type = "Talk", TargetId = "WoodfolkElder", Count = 1, Text = "Speak with Elder Saan" },
		},
		Rewards = { Experience = 120, Gold = 50, Items = { { ItemId = "HealthPotion", Amount = 5 } } },
		Next = "Q4_TempleOfRoots",
	},

	Q4_TempleOfRoots = {
		Id = "Q4_TempleOfRoots",
		DisplayName = "Temple of Roots",
		Description = "Investigate the ancient temple. Clear its halls and awaken the path to the Sacred Glade.",
		Type = "Main",
		Level = 3,
		Giver = "WoodfolkElder",
		TurnIn = "TempleWarden",
		Prerequisites = { "Q3_IntoEldoria" },
		Objectives = {
			{ Id = "ReachTemple", Type = "Reach", TargetId = "AncientTemple", Count = 1, Text = "Reach the Temple entrance" },
			{ Id = "KillCultists", Type = "Kill", TargetId = "RootCultist", Count = 5, Text = "Defeat 5 Root Cultists" },
			{ Id = "KillMiniBoss", Type = "Kill", TargetId = "TempleSentinel", Count = 1, Text = "Defeat the Temple Sentinel" },
			{ Id = "TalkWarden", Type = "Talk", TargetId = "TempleWarden", Count = 1, Text = "Speak with the Warden of Roots" },
		},
		Rewards = { Experience = 180, Gold = 80, Items = { { ItemId = "RareForestBlade", Amount = 1 } } },
		Next = "Q5_ForestGuardian",
	},

	Q5_ForestGuardian = {
		Id = "Q5_ForestGuardian",
		DisplayName = "The Forest Guardian",
		Description = "Face the Forest Guardian in the Sacred Glade and end the corruption's hold.",
		Type = "Main",
		Level = 4,
		Giver = "TempleWarden",
		TurnIn = "CommanderRys",
		Prerequisites = { "Q4_TempleOfRoots" },
		Objectives = {
			{ Id = "ReachGlade", Type = "Reach", TargetId = "SacredGlade", Count = 1, Text = "Enter the Sacred Glade" },
			{ Id = "KillGuardian", Type = "Kill", TargetId = "ForestGuardian", Count = 1, Text = "Defeat the Forest Guardian" },
			{ Id = "ReturnCommander", Type = "Talk", TargetId = "CommanderRys", Count = 1, Text = "Return to Commander Rys in Aurenholm" },
		},
		Rewards = {
			Experience = 350,
			Gold = 150,
			Items = {
				{ ItemId = "GuardianHeartwood", Amount = 1 },
				{ ItemId = "HealthPotion", Amount = 5 },
			},
		},
		Next = nil,
	},
}

function StarterCampaign.Get(id: string)
	return StarterCampaign.Quests[id]
end

function StarterCampaign.GetOrdered(): { any }
	return {
		StarterCampaign.Quests.Q1_Arrival,
		StarterCampaign.Quests.Q2_MissingPatrol,
		StarterCampaign.Quests.Q3_IntoEldoria,
		StarterCampaign.Quests.Q4_TempleOfRoots,
		StarterCampaign.Quests.Q5_ForestGuardian,
	}
end

return StarterCampaign
