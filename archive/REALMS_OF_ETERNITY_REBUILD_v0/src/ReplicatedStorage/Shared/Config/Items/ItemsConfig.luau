--!strict

local ItemsConfig = {}

export type ItemDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Type: "Weapon" | "Armor" | "Consumable" | "Material" | "Quest" | "Misc",
	Rarity: string,
	Stackable: boolean,
	MaxStack: number,
	Value: number,
	EquipSlot: string?,
	Stats: { [string]: number }?,
	ConsumeEffect: { Heal: number?, Mana: number?, Stamina: number? }?,
	RequiredLevel: number?,
}

ItemsConfig.Data = {
	HealthPotion = {
		Id = "HealthPotion", DisplayName = "Health Potion", Description = "Restores health.",
		Type = "Consumable", Rarity = "Common", Stackable = true, MaxStack = 20, Value = 10,
		ConsumeEffect = { Heal = 50 },
	},
	ManaPotion = {
		Id = "ManaPotion", DisplayName = "Mana Potion", Description = "Restores resource.",
		Type = "Consumable", Rarity = "Common", Stackable = true, MaxStack = 20, Value = 10,
		ConsumeEffect = { Mana = 40 },
	},
	WolfPelt = {
		Id = "WolfPelt", DisplayName = "Wolf Pelt", Description = "Useful crafting material.",
		Type = "Material", Rarity = "Common", Stackable = true, MaxStack = 50, Value = 4,
	},
	IronSword = {
		Id = "IronSword", DisplayName = "Iron Sword", Description = "Reliable iron blade.",
		Type = "Weapon", Rarity = "Common", Stackable = false, MaxStack = 1, Value = 40,
		EquipSlot = "MainHand", Stats = { Damage = 12 }, RequiredLevel = 1,
	},
	ApprenticeStaff = {
		Id = "ApprenticeStaff", DisplayName = "Apprentice Staff", Description = "Channels basic arcana.",
		Type = "Weapon", Rarity = "Common", Stackable = false, MaxStack = 1, Value = 40,
		EquipSlot = "MainHand", Stats = { Damage = 8, Intelligence = 2 }, RequiredLevel = 1,
	},
	HuntingBow = {
		Id = "HuntingBow", DisplayName = "Hunting Bow", Description = "Simple but accurate.",
		Type = "Weapon", Rarity = "Common", Stackable = false, MaxStack = 1, Value = 42,
		EquipSlot = "MainHand", Stats = { Damage = 11, Dexterity = 1 }, RequiredLevel = 1,
	},
	TwinDaggers = {
		Id = "TwinDaggers", DisplayName = "Twin Daggers", Description = "Fast paired blades.",
		Type = "Weapon", Rarity = "Common", Stackable = false, MaxStack = 1, Value = 38,
		EquipSlot = "MainHand", Stats = { Damage = 9, Dexterity = 2, CriticalChance = 0.03 }, RequiredLevel = 1,
	},
	TravelerTunic = {
		Id = "TravelerTunic", DisplayName = "Traveler's Tunic", Description = "Light starting armor.",
		Type = "Armor", Rarity = "Common", Stackable = false, MaxStack = 1, Value = 20,
		EquipSlot = "Chest", Stats = { Armor = 5, Vitality = 1 },
	},
	IronMail = {
		Id = "IronMail", DisplayName = "Iron Mail", Description = "Heavy protection for knights.",
		Type = "Armor", Rarity = "Uncommon", Stackable = false, MaxStack = 1, Value = 70,
		EquipSlot = "Chest", Stats = { Armor = 14, Vitality = 2 }, RequiredLevel = 3,
	},
	RareForestBlade = {
		Id = "RareForestBlade", DisplayName = "Heartwood Blade", Description = "Forged with living wood grain.",
		Type = "Weapon", Rarity = "Rare", Stackable = false, MaxStack = 1, Value = 180,
		EquipSlot = "MainHand", Stats = { Damage = 18, Strength = 2 }, RequiredLevel = 4,
	},
	GuardianHeartwood = {
		Id = "GuardianHeartwood", DisplayName = "Guardian Heartwood", Description = "Quest trophy from the Forest Guardian.",
		Type = "Quest", Rarity = "Epic", Stackable = false, MaxStack = 1, Value = 0,
	},
	WoodenShield = {
		Id = "WoodenShield", DisplayName = "Wooden Shield", Description = "Basic shield.",
		Type = "Armor", Rarity = "Common", Stackable = false, MaxStack = 1, Value = 25,
		EquipSlot = "OffHand", Stats = { Armor = 6 },
	},
} :: { [string]: ItemDef }

ItemsConfig.ClassStarters = {
	Knight = {
		{ ItemId = "IronSword", Amount = 1, Equip = "MainHand" },
		{ ItemId = "WoodenShield", Amount = 1, Equip = "OffHand" },
		{ ItemId = "IronMail", Amount = 1, Equip = "Chest" },
		{ ItemId = "HealthPotion", Amount = 5 },
	},
	Mage = {
		{ ItemId = "ApprenticeStaff", Amount = 1, Equip = "MainHand" },
		{ ItemId = "TravelerTunic", Amount = 1, Equip = "Chest" },
		{ ItemId = "ManaPotion", Amount = 6 },
		{ ItemId = "HealthPotion", Amount = 3 },
	},
	Ranger = {
		{ ItemId = "HuntingBow", Amount = 1, Equip = "MainHand" },
		{ ItemId = "TravelerTunic", Amount = 1, Equip = "Chest" },
		{ ItemId = "HealthPotion", Amount = 4 },
	},
	Assassin = {
		{ ItemId = "TwinDaggers", Amount = 1, Equip = "MainHand" },
		{ ItemId = "TravelerTunic", Amount = 1, Equip = "Chest" },
		{ ItemId = "HealthPotion", Amount = 4 },
	},
}

function ItemsConfig.Get(id: string): ItemDef?
	return ItemsConfig.Data[id]
end

return ItemsConfig
