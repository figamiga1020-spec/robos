--!strict
--[[
	15 races with visual identity notes.
	Phase 1 playable visual differentiation is data-driven;
	final meshes require Studio/Blender assets.
]]

local RacesConfig = {}

export type RaceDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Lore: string,
	Scale: number,
	BodyHint: string, -- Humanoid | Tall | Stocky | Compact | Powerful | Ethereal | Tiny
	StatMods: { [string]: number },
	PassiveName: string,
	PassiveDesc: string,
	PassiveEffects: { [string]: number },
}

RacesConfig.List = {
	"Human", "Elf", "DarkElf", "HighElf", "Dwarf",
	"Orc", "HalfOrc", "Gnome", "Dragonborn", "Demon",
	"HalfDemon", "Undead", "Vampire", "Beastfolk", "Faerie",
}

RacesConfig.Data = {
	Human = {
		Id = "Human", DisplayName = "Human",
		Description = "Adaptable and ambitious.",
		Lore = "After the Keepers vanished, humans rebuilt Aurenholm into the last great capital of Aydra.",
		Scale = 1.0, BodyHint = "Humanoid",
		StatMods = {},
		PassiveName = "Ambition",
		PassiveDesc = "+5% experience from all sources.",
		PassiveEffects = { ExpBonus = 0.05 },
	},
	Elf = {
		Id = "Elf", DisplayName = "Elf",
		Description = "Graceful forest-born people of Eldoria.",
		Lore = "Tied to the living woods that still remember the Keepers.",
		Scale = 1.02, BodyHint = "Tall",
		StatMods = { Dexterity = 2, Intelligence = 1, Vitality = -1 },
		PassiveName = "Forest Step",
		PassiveDesc = "+8% move speed in forest regions.",
		PassiveEffects = { ForestSpeed = 0.08 },
	},
	DarkElf = {
		Id = "DarkElf", DisplayName = "Dark Elf",
		Description = "Shadow-dwelling kin with sharp features.",
		Lore = "Exiles of the high courts, they thrived in Nocthold's dusk.",
		Scale = 1.0, BodyHint = "Lean",
		StatMods = { Dexterity = 2, Intelligence = 1 },
		PassiveName = "Night Eyes",
		PassiveDesc = "Slight detection bonus in darkness.",
		PassiveEffects = { DarkVision = 1 },
	},
	HighElf = {
		Id = "HighElf", DisplayName = "High Elf",
		Description = "Arcane nobility of the floating courts.",
		Lore = "Keepers of pure arcane tradition after the Schism of Keepers.",
		Scale = 1.05, BodyHint = "Tall",
		StatMods = { Intelligence = 3, Strength = -1 },
		PassiveName = "Arcane Affinity",
		PassiveDesc = "+10% max resource for magic classes.",
		PassiveEffects = { ResourceMult = 0.10 },
	},
	Dwarf = {
		Id = "Dwarf", DisplayName = "Dwarf",
		Description = "Stout masters of stone and forge.",
		Lore = "Their holds under the mountains survived when kingdoms above fell.",
		Scale = 0.85, BodyHint = "Stocky",
		StatMods = { Strength = 2, Vitality = 2, Dexterity = -2 },
		PassiveName = "Stone Skin",
		PassiveDesc = "+8% physical damage reduction.",
		PassiveEffects = { PhysDR = 0.08 },
	},
	Orc = {
		Id = "Orc", DisplayName = "Orc",
		Description = "Powerful warriors of the borderlands.",
		Lore = "Clans that broke free of demonic yokes during the Keepers' fall.",
		Scale = 1.12, BodyHint = "Powerful",
		StatMods = { Strength = 3, Vitality = 1, Intelligence = -2 },
		PassiveName = "Blood Fury",
		PassiveDesc = "Bonus damage when below 30% health.",
		PassiveEffects = { LowHealthDamage = 0.15 },
	},
	HalfOrc = {
		Id = "HalfOrc", DisplayName = "Half-Orc",
		Description = "Between two peoples, stronger for it.",
		Lore = "Often outcasts, often soldiers of Aurenholm's borders.",
		Scale = 1.06, BodyHint = "Powerful",
		StatMods = { Strength = 2, Vitality = 1 },
		PassiveName = "Relentless",
		PassiveDesc = "+5% stamina regeneration.",
		PassiveEffects = { StaminaRegen = 0.05 },
	},
	Gnome = {
		Id = "Gnome", DisplayName = "Gnome",
		Description = "Small, clever, and dangerously inventive.",
		Lore = "Survived by vanishing into workshops and under-cities.",
		Scale = 0.72, BodyHint = "Compact",
		StatMods = { Intelligence = 2, Dexterity = 2, Strength = -2 },
		PassiveName = "Tinker Mind",
		PassiveDesc = "+10% crafting success (when professions unlock).",
		PassiveEffects = { CraftBonus = 0.10 },
	},
	Dragonborn = {
		Id = "Dragonborn", DisplayName = "Dragonborn",
		Description = "Scaled heirs of vanished dragons.",
		Lore = "Rare bloodlines that still carry elemental breath.",
		Scale = 1.08, BodyHint = "Powerful",
		StatMods = { Strength = 2, Vitality = 2 },
		PassiveName = "Draconic Blood",
		PassiveDesc = "Partial resistance to one element (chosen later).",
		PassiveEffects = { ElementResist = 0.15 },
	},
	Demon = {
		Id = "Demon", DisplayName = "Demon",
		Description = "Beings of ruin that crossed when barriers cracked.",
		Lore = "Feared in Aydra; some now walk among mortals under uneasy truce.",
		Scale = 1.1, BodyHint = "Powerful",
		StatMods = { Strength = 2, Intelligence = 2, Vitality = 1 },
		PassiveName = "Infernal Core",
		PassiveDesc = "+15% fire resistance.",
		PassiveEffects = { FireResist = 0.15 },
	},
	HalfDemon = {
		Id = "HalfDemon", DisplayName = "Half-Demon",
		Description = "Caught between mortal and infernal blood.",
		Lore = "Untrusted by both sides, uniquely resilient.",
		Scale = 1.04, BodyHint = "Humanoid",
		StatMods = { Strength = 1, Intelligence = 1, Vitality = 1 },
		PassiveName = "Dual Nature",
		PassiveDesc = "Slight bonus to both light and dark damage.",
		PassiveEffects = { HybridDamage = 0.06 },
	},
	Undead = {
		Id = "Undead", DisplayName = "Undead",
		Description = "Walking remnants who retained will.",
		Lore = "Raised by residual Keeper-collapse magic; some seek purpose.",
		Scale = 1.0, BodyHint = "Gaunt",
		StatMods = { Vitality = 2, Dexterity = -1 },
		PassiveName = "Deathless Flesh",
		PassiveDesc = "Immune to poison status.",
		PassiveEffects = { PoisonImmune = 1 },
	},
	Vampire = {
		Id = "Vampire", DisplayName = "Vampire",
		Description = "Nocturnal aristocrats of blood and shadow.",
		Lore = "Old houses of Nocthold still rule from ruined halls.",
		Scale = 1.02, BodyHint = "Elegant",
		StatMods = { Dexterity = 2, Intelligence = 1 },
		PassiveName = "Blood Thirst",
		PassiveDesc = "Small lifesteal on melee hits.",
		PassiveEffects = { Lifesteal = 0.05 },
	},
	Beastfolk = {
		Id = "Beastfolk", DisplayName = "Beastfolk",
		Description = "Animal-kin with primal senses.",
		Lore = "Tribes of the wild edges of Eldoria and Viridia.",
		Scale = 1.03, BodyHint = "Athletic",
		StatMods = { Dexterity = 2, Strength = 1 },
		PassiveName = "Predator Senses",
		PassiveDesc = "+8% move speed.",
		PassiveEffects = { MoveSpeed = 0.08 },
	},
	Faerie = {
		Id = "Faerie", DisplayName = "Faerie",
		Description = "Tiny, magical, and unpredictable.",
		Lore = "Older than kingdoms; treat mortal wars as seasons.",
		Scale = 0.58, BodyHint = "Tiny",
		StatMods = { Intelligence = 2, Dexterity = 2, Strength = -3, Vitality = -1 },
		PassiveName = "Fae Luck",
		PassiveDesc = "+3% critical chance.",
		PassiveEffects = { CritChance = 0.03 },
	},
} :: { [string]: RaceDef }

function RacesConfig.Get(id: string): RaceDef?
	return RacesConfig.Data[id]
end

return RacesConfig
