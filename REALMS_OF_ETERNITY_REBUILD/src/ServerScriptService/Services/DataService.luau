--!strict
--[[
	DataService — the only owner of persisted player data.

	• Session-locked profiles via UpdateAsync (a second server cannot overwrite a live session).
	• Versioned schema + migrations (Logic/DataSchema); profiles saved by a newer build are
	  opened read-only so an old server can never roll them back.
	• Retries with backoff, request-budget awareness, autosave, safe release on leave and
	  BindToClose flush.
	• Studio uses an in-memory MockDataStore unless ServerStorage attribute
	  "UseLiveDataStore" = true, so development never touches production data.
	• State replication: services call MarkDirty(player, section); dirty sections are sent to
	  the owning client once per frame via the "StateSection" remote.

	Sections: Account, Character, Inventory, Equipment, Hotbar, Quests, World, Settings, Bank.
	Non-persisted sections (Stats, Party, ...) are pushed with PushSection(player, name, data).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local DataSchema = require(Shared.Logic.DataSchema)
local Formulas = require(Shared.Logic.Formulas)
local Net = require(Shared.Core.Net)
local Signal = require(Shared.Core.Signal)
local Types = require(Shared.Core.Types)
local Validate = require(Shared.Logic.Validate)

type Profile = Types.Profile
type CharacterRecord = Types.CharacterRecord

local STORE_NAME = "RealmsOfEternity_Profiles_v1"
local AUTOSAVE_INTERVAL = 90
local LOCK_STALE_SECONDS = 600
local LOCK_RETRIES = 6
local LOCK_RETRY_DELAY = 4
local MIN_SAVE_GAP = 6

type Session = {
	Player: Player,
	Profile: Profile,
	ActiveId: string?,
	ReadOnly: boolean,
	LastSave: number,
	JoinedAt: number,
	Dirty: { [string]: boolean },
	Released: boolean,
}

local DataService = {
	Priority = 100,
	ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>,
	ProfileReleasing = Signal.new() :: Signal.Signal<Player, Profile>,
	CharacterActivated = Signal.new() :: Signal.Signal<Player, CharacterRecord>,
}

local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local store: any = nil
local usingMock = false

-- ── Mock store (Studio) ───────────────────────────────────────────────────────
local MockStore = {}
MockStore.__index = MockStore
local mockData: { [string]: any } = {}

function MockStore.GetAsync(_self: any, key: string): any
	return DataSchema.DeepCopy(mockData[key])
end

function MockStore.UpdateAsync(_self: any, key: string, transform: (any) -> any): any
	task.wait(0.05)
	local result = transform(DataSchema.DeepCopy(mockData[key]))
	if result ~= nil then
		mockData[key] = DataSchema.DeepCopy(result)
	end
	return result
end

function MockStore.RemoveAsync(_self: any, key: string)
	mockData[key] = nil
end

local function resolveStore()
	local wantLive = not RunService:IsStudio() or ServerStorage:GetAttribute("UseLiveDataStore") == true
	if wantLive then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
			usingMock = false
			return
		end
		warn(`[DataService] DataStore unavailable ({result}); falling back to MockDataStore`)
	end
	store = setmetatable({}, MockStore)
	usingMock = true
end

local function keyFor(userId: number): string
	return `profile_{userId}`
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T?)
	local delay = 1
	for attempt = 1, 4 do
		if not usingMock then
			while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < 1 do
				task.wait(0.5)
			end
		end
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} failed (attempt {attempt}): {result}`)
		task.wait(delay)
		delay *= 2
	end
	return false, nil
end

-- ── Views sent to the client ──────────────────────────────────────────────────
local function accountView(session: Session): any
	local list = {}
	for _, id in session.Profile.Order do
		local character = session.Profile.Characters[id]
		if character then
			table.insert(list, {
				Id = character.Id,
				Name = character.Name,
				Race = character.Race,
				Class = character.Class,
				Level = character.Level,
				Appearance = character.Appearance,
				Equipment = (function()
					local ids = {}
					for slot, uid in character.Equipment do
						local item = character.Inventory[uid]
						if item then
							ids[slot] = item.Id
						end
					end
					return ids
				end)(),
				LastPlayed = character.LastPlayed,
			})
		end
	end
	return {
		Characters = list,
		LastCharacter = session.Profile.LastCharacter,
		MaxCharacters = DataSchema.MAX_CHARACTERS,
		ReadOnly = session.ReadOnly,
		MockData = usingMock,
	}
end

local function sectionData(session: Session, section: string): any
	local profile = session.Profile
	if section == "Account" then
		return accountView(session)
	elseif section == "Settings" then
		return profile.Settings
	elseif section == "Bank" then
		return profile.Bank
	end
	local character = session.ActiveId and profile.Characters[session.ActiveId]
	if not character then
		return nil
	end
	if section == "Character" then
		return {
			Id = character.Id,
			Name = character.Name,
			Race = character.Race,
			Class = character.Class,
			Level = character.Level,
			XP = character.XP,
			XPToNext = Formulas.XPToNext(character.Level),
			LevelCap = Formulas.LevelCap,
			Gold = character.Gold,
			Spec = character.Spec,
			Talents = character.Talents,
			Appearance = character.Appearance,
			Reputation = character.Reputation,
			Bosses = character.Bosses,
		}
	elseif section == "Inventory" then
		return { Items = character.Inventory, Capacity = character.InventoryCapacity }
	elseif section == "Equipment" then
		return character.Equipment
	elseif section == "Hotbar" then
		return character.Hotbar
	elseif section == "Quests" then
		return character.Quests
	elseif section == "World" then
		return {
			Discovered = character.World.Discovered,
			Flags = character.World.Flags,
			Waystone = character.World.Waystone,
		}
	end
	return nil
end

-- ── Public API ────────────────────────────────────────────────────────────────
function DataService:IsMock(): boolean
	return usingMock
end

function DataService:GetProfile(player: Player): Profile?
	local session = sessions[player]
	return session and session.Profile
end

function DataService:WaitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and os.clock() < deadline do
		local session = sessions[player]
		if session then
			return session.Profile
		end
		if not loading[player] and not sessions[player] then
			-- load failed or not started
			task.wait(0.2)
		end
		task.wait(0.1)
	end
	return nil
end

function DataService:GetCharacter(player: Player): CharacterRecord?
	local session = sessions[player]
	if not session or not session.ActiveId then
		return nil
	end
	return session.Profile.Characters[session.ActiveId]
end

function DataService:GetActiveId(player: Player): string?
	local session = sessions[player]
	return session and session.ActiveId
end

function DataService:SetActiveCharacter(player: Player, id: string): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	local character = session.Profile.Characters[id]
	if not character then
		return false
	end
	session.ActiveId = id
	session.Profile.LastCharacter = id
	character.LastPlayed = os.time()
	for _, section in { "Character", "Inventory", "Equipment", "Hotbar", "Quests", "World", "Account" } do
		session.Dirty[section] = true
	end
	DataService.CharacterActivated:Fire(player, character)
	return true
end

-- Adds a brand-new character record (CharacterService validates everything first).
function DataService:AddCharacter(player: Player, record: CharacterRecord): boolean
	local session = sessions[player]
	if not session or session.ReadOnly then
		return false
	end
	local count = 0
	for _ in session.Profile.Characters do
		count += 1
	end
	if count >= DataSchema.MAX_CHARACTERS then
		return false
	end
	session.Profile.Characters[record.Id] = record
	table.insert(session.Profile.Order, record.Id)
	session.Dirty.Account = true
	return true
end

function DataService:DeleteCharacter(player: Player, id: string): boolean
	local session = sessions[player]
	if not session or session.ReadOnly or session.ActiveId == id then
		return false
	end
	if not session.Profile.Characters[id] then
		return false
	end
	session.Profile.Characters[id] = nil
	local index = table.find(session.Profile.Order, id)
	if index then
		table.remove(session.Profile.Order, index)
	end
	if session.Profile.LastCharacter == id then
		session.Profile.LastCharacter = nil
	end
	session.Dirty.Account = true
	return true
end

function DataService:NewUid(): string
	return HttpService:GenerateGUID(false)
end

function DataService:MarkDirty(player: Player, section: string)
	local session = sessions[player]
	if session then
		session.Dirty[section] = true
	end
end

-- Push a non-persisted section immediately (e.g. Stats, Party).
function DataService:PushSection(player: Player, section: string, data: any)
	Net.FireClient(player, "StateSection", section, data)
end

local function serialize(session: Session): any
	local profile = session.Profile
	local character = session.ActiveId and profile.Characters[session.ActiveId]
	if character then
		local now = os.clock()
		character.PlayTime += math.floor(now - session.JoinedAt)
		session.JoinedAt = now
		local player = session.Player
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local safe = player.Character and player.Character:GetAttribute("SafePosition")
		if typeof(safe) == "Vector3" then
			character.World.Position = { safe.X, safe.Y, safe.Z }
		elseif root and not (player.Character and player.Character:GetAttribute("InInstance")) then
			character.World.Position = { root.Position.X, root.Position.Y, root.Position.Z }
		end
	end
	return profile
end

function DataService:Save(player: Player, reason: string?, force: boolean?): boolean
	local session = sessions[player]
	if not session or session.ReadOnly or session.Released then
		return false
	end
	if not force and os.clock() - session.LastSave < MIN_SAVE_GAP then
		return false
	end
	session.LastSave = os.clock()
	local snapshot = DataSchema.DeepCopy(serialize(session))
	snapshot.SessionLock = { JobId = game.JobId, Time = os.time() }
	local lostLock = false
	local ok = withRetries(`save {player.UserId} ({reason or "manual"})`, function()
		return store:UpdateAsync(keyFor(player.UserId), function(current: any): any
			if current and current.SessionLock and current.SessionLock.JobId ~= game.JobId then
				lostLock = true
				return nil -- another server owns this profile now; never overwrite it
			end
			return snapshot
		end)
	end)
	if lostLock then
		warn(`[DataService] session lock lost for {player.Name}; saves disabled`)
		session.ReadOnly = true
		return false
	end
	return ok
end

local function release(player: Player)
	local session = sessions[player]
	if not session or session.Released then
		return
	end
	DataService.ProfileReleasing:Fire(player, session.Profile)
	if not session.ReadOnly then
		local snapshot = DataSchema.DeepCopy(serialize(session))
		snapshot.SessionLock = nil
		withRetries(`release {player.UserId}`, function()
			return store:UpdateAsync(keyFor(player.UserId), function(current: any): any
				if current and current.SessionLock and current.SessionLock.JobId ~= game.JobId then
					return nil
				end
				return snapshot
			end)
		end)
	end
	session.Released = true
	sessions[player] = nil
end

local function load(player: Player)
	loading[player] = true
	local now = os.time()
	local profile: any = nil
	local readOnly = false

	for attempt = 1, LOCK_RETRIES do
		local blocked = false
		local ok, result = withRetries(`load {player.UserId}`, function()
			return store:UpdateAsync(keyFor(player.UserId), function(current: any): any
				local lock = current and current.SessionLock
				if
					lock
					and lock.JobId ~= game.JobId
					and os.time() - (lock.Time or 0) < LOCK_STALE_SECONDS
					and attempt < LOCK_RETRIES
				then
					blocked = true
					return nil
				end
				local migrated = DataSchema.Migrate(current, now)
				if (migrated.Version or 0) > DataSchema.VERSION then
					return nil -- newer build's data: leave untouched
				end
				migrated.SessionLock = { JobId = game.JobId, Time = os.time() }
				return migrated
			end)
		end)
		if not ok then
			break
		end
		if blocked then
			task.wait(LOCK_RETRY_DELAY)
			continue
		end
		profile = result
		if profile == nil then
			-- UpdateAsync returned nil: the data is from a newer version; read it read-only.
			local _, raw = withRetries("read newer", function()
				return store:GetAsync(keyFor(player.UserId))
			end)
			profile = raw
			readOnly = true
		end
		break
	end

	loading[player] = nil
	if not player.Parent then
		return
	end
	if type(profile) ~= "table" then
		player:Kick(
			"Не удалось загрузить данные персонажа. Пожалуйста, перезайдите — ваш прогресс в безопасности."
		)
		return
	end

	local session: Session = {
		Player = player,
		Profile = profile,
		ActiveId = nil,
		ReadOnly = readOnly,
		LastSave = os.clock(),
		JoinedAt = os.clock(),
		Dirty = { Account = true, Settings = true, Bank = true },
		Released = false,
	}
	sessions[player] = session
	DataService.ProfileLoaded:Fire(player, profile)
end

local function flushDirty()
	for player, session in sessions do
		if next(session.Dirty) == nil then
			continue
		end
		local dirty = session.Dirty
		session.Dirty = {}
		for section in dirty do
			local data = sectionData(session, section)
			if data ~= nil then
				Net.FireClient(player, "StateSection", section, data)
			end
		end
	end
end

function DataService:Init()
	resolveStore()
	if usingMock then
		print(
			"[DataService] Using MockDataStore (Studio). Set ServerStorage.UseLiveDataStore = true to test real saves."
		)
	end

	Net.HandleInvoke("RequestState", { Rate = { 5, 1 } }, function(player)
		local session = sessions[player]
		if not session then
			return nil
		end
		local result = {}
		for _, section in
			{ "Account", "Settings", "Bank", "Character", "Inventory", "Equipment", "Hotbar", "Quests", "World" }
		do
			result[section] = sectionData(session, section)
		end
		return result
	end)

	local settingsShape = Validate.Shape({
		Keybinds = Validate.Optional(function(value)
			if type(value) ~= "table" then
				return false, "table"
			end
			local count = 0
			for key, bind in value do
				count += 1
				if type(key) ~= "string" or #key > 24 or type(bind) ~= "string" or #bind > 24 then
					return false, "bind"
				end
			end
			return count <= 40, "too many"
		end),
		CameraSensitivity = Validate.Optional(Validate.Number(0.1, 3)),
		MusicVolume = Validate.Optional(Validate.Number(0, 1)),
		SfxVolume = Validate.Optional(Validate.Number(0, 1)),
		DamageNumbers = Validate.Optional(Validate.Boolean()),
		CameraShake = Validate.Optional(Validate.Boolean()),
		Quality = Validate.Optional(Validate.OneOf({ "Auto", "Low", "Medium", "High" })),
	})
	Net.Handle("SaveSettings", { Args = { settingsShape }, Rate = { 4, 0.5 } }, function(player, settings)
		local session = sessions[player]
		if not session then
			return
		end
		for key, value in settings do
			(session.Profile.Settings :: any)[key] = value
		end
		session.Dirty.Settings = true
	end)

	RunService.Heartbeat:Connect(flushDirty)
end

function DataService:Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- wait for an in-flight load so we can release its lock
		local deadline = os.clock() + 20
		while loading[player] and os.clock() < deadline do
			task.wait(0.2)
		end
		release(player)
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	-- Staggered autosave.
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in sessions do
			task.spawn(function()
				DataService:Save(player, "autosave")
			end)
			task.wait(0.5)
		end
	end
end

return DataService
