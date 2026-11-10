--!strict
--[[
	REALMS OF ETERNITY REBUILD — Core Types
]]

export type RaceId =
	"Human" | "Elf" | "DarkElf" | "HighElf" | "Dwarf" |
	"Orc" | "HalfOrc" | "Gnome" | "Dragonborn" | "Demon" |
	"HalfDemon" | "Undead" | "Vampire" | "Beastfolk" | "Faerie"

export type ClassId =
	"Knight" | "Mage" | "Ranger" | "Assassin" | -- Phase 1 full
	"Berserker" | "Paladin" | "Cryomancer" | "Necromancer" |
	"Druid" | "Cleric" | "Spellblade" | "Warlock" | "Monk" |
	"Lancer" | "Duelist" | "Marksman" | "Summoner" | "Bard" |
	"Engineer" | "ShadowKnight"

export type StatId =
	"Strength" | "Dexterity" | "Intelligence" | "Vitality" |
	"CriticalChance" | "CriticalDamage" | "Armor" | "Resistance" |
	"MovementSpeed" | "Recovery"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type EquipmentSlot =
	"Helmet" | "Chest" | "Shoulders" | "Gloves" | "Bracers" |
	"Legs" | "Boots" | "Belt" | "Cloak" | "MainHand" | "OffHand" |
	"Amulet" | "Ring1" | "Ring2"

export type AppearanceData = {
	Gender: string,
	SkinTone: number,
	HairStyle: string,
	HairColor: { number },
	EyeColor: { number },
	FaceId: string,
	Scale: number,
	ExtraFeatures: { string }?,
}

export type ItemInstance = {
	Uid: string,
	ItemId: string,
	Amount: number,
	Bound: boolean?,
	Durability: number?,
}

export type QuestObjectiveProgress = {
	[string]: number,
}

export type QuestState = {
	QuestId: string,
	Objectives: QuestObjectiveProgress,
	Completed: boolean,
	TurnedIn: boolean,
}

export type PartyMemberSnapshot = {
	UserId: number,
	Name: string,
	Level: number,
	Class: ClassId,
	Health: number,
	MaxHealth: number,
	IsLeader: boolean,
}

export type PlayerProfile = {
	UserId: number,
	CharacterName: string,
	Race: RaceId,
	Class: ClassId,
	Appearance: AppearanceData,
	Level: number,
	Experience: number,
	Stats: { [StatId]: number },
	Health: number,
	MaxHealth: number,
	Resource: number, -- mana/stamina/class resource
	MaxResource: number,
	Stamina: number,
	MaxStamina: number,
	Inventory: { ItemInstance },
	Equipment: { [EquipmentSlot]: string? },
	KnownSkills: { [string]: number },
	SkillBar: { string },
	Currency: { Gold: number },
	Quests: { [string]: QuestState },
	CompletedQuests: { string },
	UnlockedRegions: { string },
	LastLocation: {
		RegionId: string,
		Position: { X: number, Y: number, Z: number },
	},
	Settings: {
		CameraSensitivity: number,
		MusicVolume: number,
		SfxVolume: number,
	},
	DataVersion: number,
	CreatedAt: number,
	LastSave: number,
}

return nil
