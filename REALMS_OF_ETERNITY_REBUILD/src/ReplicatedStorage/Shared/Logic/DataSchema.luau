--!strict
--[[
	DataSchema — profile defaults, versioned migrations and reconciliation.
	Pure Luau (tested under Lune). DataService is the only writer of persisted profiles.

	Migration rule: never delete player progress in a migration; transform it.
	Bump VERSION and add MIGRATIONS[newVersion] = function(profile) ... end.
]]

local Types = require(script.Parent.Parent.Core.Types)

type Profile = Types.Profile
type CharacterRecord = Types.CharacterRecord

local DataSchema = {}

DataSchema.VERSION = 2
DataSchema.MAX_CHARACTERS = 3
DataSchema.DEFAULT_CAPACITY = 36
DataSchema.BANK_CAPACITY = 48

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy :: any
end
DataSchema.DeepCopy = deepCopy

function DataSchema.DefaultSettings(): Types.Settings
	return {
		Keybinds = {},
		CameraSensitivity = 1,
		MusicVolume = 0.6,
		SfxVolume = 0.8,
		DamageNumbers = true,
		CameraShake = true,
		Quality = "Auto",
	}
end

function DataSchema.NewProfile(now: number): Profile
	return {
		Version = DataSchema.VERSION,
		Characters = {},
		Order = {},
		LastCharacter = nil,
		Settings = DataSchema.DefaultSettings(),
		Bank = { Gold = 0, Items = {}, Capacity = DataSchema.BANK_CAPACITY },
		Achievements = {},
		Created = now,
		SessionLock = nil,
	}
end

export type NewCharacterParams = {
	Id: string,
	Name: string,
	Race: string,
	Class: string,
	Appearance: Types.Appearance,
	StartWaystone: string,
}

function DataSchema.NewCharacter(params: NewCharacterParams, now: number): CharacterRecord
	return {
		Id = params.Id,
		Name = params.Name,
		Race = params.Race,
		Class = params.Class,
		Appearance = deepCopy(params.Appearance),
		Level = 1,
		XP = 0,
		Gold = 15,
		Spec = nil,
		Talents = {},
		Inventory = {},
		InventoryCapacity = DataSchema.DEFAULT_CAPACITY,
		Equipment = {},
		Hotbar = { "potion_health_minor", "potion_mana_minor", "ration_travel", "" },
		Quests = { Active = {}, Completed = {}, Tracked = nil },
		World = { Position = nil, Waystone = params.StartWaystone, Discovered = {}, Flags = {} },
		Bosses = {},
		Rewards = {},
		Reputation = { RoyalOrder = 0, Archivists = 0, FreeSeekers = 0, AshOrder = 0, DeepOath = 0 },
		Professions = { Herbalism = 1, Gathering = 1 },
		PlayTime = 0,
		Created = now,
		LastPlayed = now,
	}
end

-- Migrations keyed by the version they produce.
local MIGRATIONS: { [number]: (any) -> () } = {
	-- v1 → v2: introduced per-character Rewards ledger and Hotbar; older saves lacked them.
	[2] = function(profile)
		for _, character in profile.Characters or {} do
			character.Rewards = character.Rewards or {}
			character.Hotbar = character.Hotbar or { "potion_health_minor", "potion_mana_minor", "ration_travel", "" }
		end
	end,
}

-- Fills any missing keys from `template` without overwriting existing data.
local function reconcile(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(target[key], value)
		end
	end
end

-- Upgrades a loaded profile in place. Returns (profile, migrated?). Never downgrades.
function DataSchema.Migrate(raw: any, now: number): (Profile, boolean)
	if type(raw) ~= "table" then
		return DataSchema.NewProfile(now), true
	end
	local profile = raw
	local version = tonumber(profile.Version) or 1
	local migrated = false
	if version > DataSchema.VERSION then
		-- Saved by a newer server build: keep data untouched, caller must not overwrite it.
		return profile :: Profile, false
	end
	while version < DataSchema.VERSION do
		version += 1
		local step = MIGRATIONS[version]
		if step then
			step(profile)
		end
		migrated = true
	end
	profile.Version = DataSchema.VERSION
	reconcile(profile, DataSchema.NewProfile(now))
	for id, character in profile.Characters do
		if type(character) ~= "table" then
			profile.Characters[id] = nil
			continue
		end
		local template = DataSchema.NewCharacter({
			Id = id,
			Name = character.Name or "Безымянный",
			Race = character.Race or "Human",
			Class = character.Class or "Knight",
			Appearance = character.Appearance or DataSchema.DefaultAppearance(),
			StartWaystone = "waystone_aurenholm",
		}, now)
		template.Inventory = {}
		reconcile(character, template)
	end
	-- Order must reference existing characters only.
	local order = {}
	for _, id in profile.Order do
		if profile.Characters[id] then
			table.insert(order, id)
		end
	end
	for id in profile.Characters do
		if not table.find(order, id) then
			table.insert(order, id)
		end
	end
	profile.Order = order
	return profile :: Profile, migrated
end

function DataSchema.DefaultAppearance(): Types.Appearance
	return {
		BodyType = 1,
		Height = 0,
		SkinTone = 2,
		Face = 1,
		Hair = "Cropped",
		HairColor = 2,
		EyeColor = 1,
		Feature = "None",
		FeatureColor = 1,
		Marking = 0,
	}
end

-- Name rules (before TextService filtering): 3–16 chars, letters (Latin/Cyrillic), space, ' and -.
function DataSchema.ValidateName(name: string): (boolean, string?)
	local length = utf8.len(name)
	if not length then
		return false, "Недопустимые символы"
	end
	if length < 3 or length > 16 then
		return false, "Имя должно содержать от 3 до 16 символов"
	end
	if string.find(name, "^[%s'%-]") or string.find(name, "[%s'%-]$") then
		return false, "Имя не может начинаться или заканчиваться пробелом или знаком"
	end
	if string.find(name, "%s%s") then
		return false, "Слишком много пробелов"
	end
	for _, code in utf8.codes(name) do
		local isLatin = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		local isCyrillic = (code >= 0x0410 and code <= 0x044F) or code == 0x0401 or code == 0x0451
		local isSeparator = code == 32 or code == 39 or code == 45
		if not (isLatin or isCyrillic or isSeparator) then
			return false, "Только буквы, пробел, апостроф и дефис"
		end
	end
	return true
end

-- Validates an appearance table against a race definition. Returns a sanitised copy.
function DataSchema.SanitizeAppearance(appearance: any, race: any): (Types.Appearance?, string?)
	if type(appearance) ~= "table" then
		return nil, "bad appearance"
	end
	local function index(value: any, max: number, allowZero: boolean?): number?
		if type(value) ~= "number" or value % 1 ~= 0 then
			return nil
		end
		local min = if allowZero then 0 else 1
		if value < min or value > max then
			return nil
		end
		return value
	end
	local result: Types.Appearance = {
		BodyType = index(appearance.BodyType, 2) or 1,
		Height = if type(appearance.Height) == "number" and appearance.Height == appearance.Height
			then math.clamp(appearance.Height, -1, 1)
			else 0,
		SkinTone = index(appearance.SkinTone, #race.SkinTones) or 1,
		Face = index(appearance.Face, race.Faces) or 1,
		Hair = if type(appearance.Hair) == "string" and table.find(race.HairStyles, appearance.Hair)
			then appearance.Hair
			else race.HairStyles[1],
		HairColor = index(appearance.HairColor, #race.HairColors) or 1,
		EyeColor = index(appearance.EyeColor, #race.EyeColors) or 1,
		Feature = if type(appearance.Feature) == "string" and table.find(race.Features, appearance.Feature)
			then appearance.Feature
			else race.Features[1],
		FeatureColor = index(appearance.FeatureColor, #race.FeatureColors) or 1,
		Marking = index(appearance.Marking, race.Markings, true) or 0,
	}
	return result
end

return DataSchema
