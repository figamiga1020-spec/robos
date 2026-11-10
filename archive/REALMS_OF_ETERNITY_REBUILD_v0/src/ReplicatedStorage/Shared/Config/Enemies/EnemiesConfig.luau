--!strict

local EnemiesConfig = {}

export type EnemyDef = {
	Id: string,
	DisplayName: string,
	Type: "Normal" | "Elite" | "MiniBoss" | "Boss",
	Level: number,
	Health: number,
	Damage: number,
	Armor: number,
	Speed: number,
	Experience: number,
	GoldMin: number,
	GoldMax: number,
	AttackRange: number,
	AttackCooldown: number,
	AggroRange: number,
	LeashRange: number,
	Abilities: { string }?,
	Loot: { { ItemId: string, Chance: number, Min: number, Max: number } },
	Scale: number?,
	RegionIds: { string },
}

EnemiesConfig.Data = {
	ForestBrigand = {
		Id = "ForestBrigand", DisplayName = "Forest Brigand", Type = "Normal",
		Level = 2, Health = 95, Damage = 11, Armor = 4, Speed = 1.0,
		Experience = 22, GoldMin = 2, GoldMax = 7,
		AttackRange = 7, AttackCooldown = 1.35, AggroRange = 30, LeashRange = 55,
		Loot = { { ItemId = "HealthPotion", Chance = 0.15, Min = 1, Max = 1 } },
		RegionIds = { "Eldoria" },
	},
	CorruptedWolf = {
		Id = "CorruptedWolf", DisplayName = "Corrupted Wolf", Type = "Normal",
		Level = 2, Health = 80, Damage = 13, Armor = 2, Speed = 1.2,
		Experience = 20, GoldMin = 0, GoldMax = 3,
		AttackRange = 6, AttackCooldown = 1.2, AggroRange = 32, LeashRange = 50,
		Loot = { { ItemId = "WolfPelt", Chance = 0.5, Min = 1, Max = 2 } },
		RegionIds = { "Eldoria" },
	},
	RootCultist = {
		Id = "RootCultist", DisplayName = "Root Cultist", Type = "Normal",
		Level = 3, Health = 110, Damage = 14, Armor = 3, Speed = 1.0,
		Experience = 28, GoldMin = 3, GoldMax = 8,
		AttackRange = 8, AttackCooldown = 1.5, AggroRange = 28, LeashRange = 50,
		Abilities = { "RootBolt" },
		Loot = { { ItemId = "ManaPotion", Chance = 0.2, Min = 1, Max = 1 } },
		RegionIds = { "Eldoria" },
	},
	TempleSentinel = {
		Id = "TempleSentinel", DisplayName = "Temple Sentinel", Type = "MiniBoss",
		Level = 4, Health = 650, Damage = 22, Armor = 10, Speed = 0.95,
		Experience = 120, GoldMin = 25, GoldMax = 45,
		AttackRange = 10, AttackCooldown = 1.6, AggroRange = 40, LeashRange = 70,
		Abilities = { "StoneSlam", "RootSnare" },
		Loot = {
			{ ItemId = "HealthPotion", Chance = 0.8, Min = 2, Max = 3 },
			{ ItemId = "IronSword", Chance = 0.25, Min = 1, Max = 1 },
		},
		Scale = 1.4,
		RegionIds = { "Eldoria" },
	},
	ForestGuardian = {
		Id = "ForestGuardian", DisplayName = "Forest Guardian", Type = "Boss",
		Level = 5, Health = 3200, Damage = 28, Armor = 14, Speed = 0.85,
		Experience = 400, GoldMin = 80, GoldMax = 140,
		AttackRange = 14, AttackCooldown = 2.0, AggroRange = 55, LeashRange = 120,
		Abilities = { "RootSlam", "BranchSweep", "RootLines", "GuardianCall", "AwakenedFury" },
		Loot = {
			{ ItemId = "GuardianHeartwood", Chance = 1.0, Min = 1, Max = 1 },
			{ ItemId = "RareForestBlade", Chance = 0.4, Min = 1, Max = 1 },
			{ ItemId = "HealthPotion", Chance = 1.0, Min = 3, Max = 5 },
		},
		Scale = 2.0,
		RegionIds = { "Eldoria" },
	},
} :: { [string]: EnemyDef }

-- Boss phase thresholds (fraction of max health remaining)
EnemiesConfig.ForestGuardianPhases = {
	Phase1 = { HealthAbove = 0.66 },
	Phase2 = { HealthAbove = 0.33 },
	Phase3 = { HealthAbove = 0 },
}

function EnemiesConfig.Get(id: string): EnemyDef?
	return EnemiesConfig.Data[id]
end

return EnemiesConfig
