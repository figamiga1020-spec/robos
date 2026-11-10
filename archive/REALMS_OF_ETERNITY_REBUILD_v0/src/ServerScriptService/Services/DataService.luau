--!strict
--[[
	Authoritative player profile load/save with versioning.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local RacesConfig = require(game.ReplicatedStorage.Shared.Config.Races.RacesConfig)
local ClassesConfig = require(game.ReplicatedStorage.Shared.Config.Classes.ClassesConfig)
local ItemsConfig = require(game.ReplicatedStorage.Shared.Config.Items.ItemsConfig)
local WorldLayout = require(game.ReplicatedStorage.Shared.Config.World.WorldLayout)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local DataService = {}

local STORE_NAME = "ROE_Rebuild_PlayerData_v1"
local VERSION = 1
local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [number]: any } = {}
local saving: { [number]: boolean } = {}

local function defaultProfile(player: Player): any
	local now = os.time()
	local spawn = WorldLayout.Spawn.CFrame.Position
	return {
		UserId = player.UserId,
		CharacterName = player.DisplayName,
		Race = "Human",
		Class = "Knight",
		Appearance = {
			Gender = "Neutral",
			SkinTone = 1,
			HairStyle = "Short",
			HairColor = { 0.2, 0.15, 0.1 },
			EyeColor = { 0.2, 0.3, 0.4 },
			FaceId = "Default",
			Scale = 1,
		},
		Level = 1,
		Experience = 0,
		Stats = {
			Strength = 10, Dexterity = 10, Intelligence = 10, Vitality = 10,
			CriticalChance = 0.05, CriticalDamage = 1.5, Armor = 0, Resistance = 0,
			MovementSpeed = 1, Recovery = 1,
		},
		Health = 100, MaxHealth = 100,
		Resource = 50, MaxResource = 50,
		Stamina = 100, MaxStamina = 100,
		Inventory = {},
		Equipment = {},
		KnownSkills = {},
		SkillBar = {},
		Currency = { Gold = 25 },
		Quests = {},
		CompletedQuests = {},
		UnlockedRegions = { "Aurenholm", "Eldoria" },
		LastLocation = {
			RegionId = "Aurenholm",
			Position = { X = spawn.X, Y = spawn.Y, Z = spawn.Z },
		},
		Settings = { CameraSensitivity = 1, MusicVolume = 0.7, SfxVolume = 0.8 },
		DataVersion = VERSION,
		CreatedAt = now,
		LastSave = now,
		HasCharacter = false,
	}
end

function DataService.ApplyRaceClass(profile: any, raceId: string, classId: string)
	local race = RacesConfig.Get(raceId)
	local class = ClassesConfig.Get(classId)
	if not race or not class or not class.IsPhase1Playable then
		return false
	end

	profile.Race = raceId
	profile.Class = classId
	profile.Appearance.Scale = race.Scale

	local base = 10
	profile.Stats = {
		Strength = base, Dexterity = base, Intelligence = base, Vitality = base,
		CriticalChance = 0.05, CriticalDamage = 1.5, Armor = 0, Resistance = 0,
		MovementSpeed = 1, Recovery = 1,
	}
	for k, v in pairs(race.StatMods) do
		if profile.Stats[k] ~= nil then
			profile.Stats[k] += v
		end
	end

	profile.MaxHealth = math.floor(100 * class.HealthMult + profile.Stats.Vitality * 6)
	profile.MaxResource = math.floor(50 * class.ResourceMult + profile.Stats.Intelligence * 4)
	profile.MaxStamina = math.floor(100 * class.StaminaMult + profile.Stats.Dexterity * 2)
	profile.Health = profile.MaxHealth
	profile.Resource = profile.MaxResource
	profile.Stamina = profile.MaxStamina

	profile.KnownSkills = {}
	profile.SkillBar = {}
	for _, skill in class.Skills do
		if skill.UnlockLevel <= 1 then
			profile.KnownSkills[skill.Id] = 1
			table.insert(profile.SkillBar, skill.Id)
		end
	end

	-- Starter gear
	profile.Inventory = {}
	profile.Equipment = {}
	local pack = ItemsConfig.ClassStarters[classId] or ItemsConfig.ClassStarters.Knight
	for _, entry in pack do
		local uid = HttpService:GenerateGUID(false)
		table.insert(profile.Inventory, { Uid = uid, ItemId = entry.ItemId, Amount = entry.Amount or 1 })
		if entry.Equip then
			profile.Equipment[entry.Equip] = uid
		end
	end

	profile.HasCharacter = true
	return true
end

local function loadKey(key: string): (boolean, any)
	for i = 1, 4 do
		local ok, data = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then return true, data end
		task.wait(0.8 * i)
	end
	return false, nil
end

function DataService.Load(player: Player)
	if profiles[player.UserId] then return profiles[player.UserId] end
	local ok, data = loadKey("P_" .. player.UserId)
	local profile = (ok and data) and data or defaultProfile(player)
	profile.UserId = player.UserId
	profiles[player.UserId] = profile
	return profile
end

function DataService.Save(player: Player): boolean
	local profile = profiles[player.UserId]
	if not profile or saving[player.UserId] then return false end
	saving[player.UserId] = true
	profile.LastSave = os.time()
	local ok = false
	for i = 1, 4 do
		local success = pcall(function()
			store:SetAsync("P_" .. player.UserId, profile)
		end)
		if success then ok = true break end
		task.wait(0.8 * i)
	end
	saving[player.UserId] = false
	return ok
end

function DataService.Get(player: Player)
	return profiles[player.UserId]
end

function DataService.Update(player: Player, fn: (any) -> ())
	local p = profiles[player.UserId]
	if p then fn(p) end
end

function DataService.Sync(player: Player)
	local p = profiles[player.UserId]
	if not p then return end
	RemoteRegistry.RE_ProfileSync:FireClient(player, {
		CharacterName = p.CharacterName,
		Race = p.Race,
		Class = p.Class,
		Level = p.Level,
		Experience = p.Experience,
		Health = p.Health,
		MaxHealth = p.MaxHealth,
		Resource = p.Resource,
		MaxResource = p.MaxResource,
		Stamina = p.Stamina,
		MaxStamina = p.MaxStamina,
		Stats = p.Stats,
		Currency = p.Currency,
		SkillBar = p.SkillBar,
		KnownSkills = p.KnownSkills,
		HasCharacter = p.HasCharacter,
		LastLocation = p.LastLocation,
	})
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		DataService.Load(player)
		DataService.Sync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(90)
			for _, plr in Players:GetPlayers() do
				DataService.Save(plr)
			end
		end
	end)
	game:BindToClose(function()
		for _, plr in Players:GetPlayers() do
			DataService.Save(plr)
		end
		task.wait(2)
	end)
	print("[DataService] Ready")
end

return DataService
