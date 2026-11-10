--!strict

local Players = game:GetService("Players")
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local ClassesConfig = require(game.ReplicatedStorage.Shared.Config.Classes.ClassesConfig)
local RacesConfig = require(game.ReplicatedStorage.Shared.Config.Races.RacesConfig)
local WorldLayout = require(game.ReplicatedStorage.Shared.Config.World.WorldLayout)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local CharacterService = {}

function CharacterService.CreateCharacter(player: Player, payload: any)
	local profile = DataService.Get(player)
	if not profile then
		RemoteRegistry.RE_CreateCharacterResult:FireClient(player, false, "No profile")
		return
	end

	local name = typeof(payload.Name) == "string" and payload.Name or ""
	name = string.gsub(name, "^%s*(.-)%s*$", "%1")
	if #name < 3 or #name > 16 then
		RemoteRegistry.RE_CreateCharacterResult:FireClient(player, false, "Invalid name")
		return
	end

	local race = RacesConfig.Get(payload.Race)
	local class = ClassesConfig.Get(payload.Class)
	if not race or not class or not class.IsPhase1Playable then
		RemoteRegistry.RE_CreateCharacterResult:FireClient(player, false, "Invalid race/class")
		return
	end

	profile.CharacterName = name
	if typeof(payload.Appearance) == "table" then
		for k, v in pairs(payload.Appearance) do
			profile.Appearance[k] = v
		end
	end

	if not DataService.ApplyRaceClass(profile, payload.Race, payload.Class) then
		RemoteRegistry.RE_CreateCharacterResult:FireClient(player, false, "Failed to apply class")
		return
	end

	-- Place at capital spawn
	local spawn = WorldLayout.Spawn.CFrame
	profile.LastLocation = {
		RegionId = "Aurenholm",
		Position = { X = spawn.X, Y = spawn.Y, Z = spawn.Z },
	}

	DataService.Save(player)
	DataService.Sync(player)
	RemoteRegistry.RE_CreateCharacterResult:FireClient(player, true, "Created")

	-- Respawn character to apply scale
	if player.Character then
		player:LoadCharacter()
	end
end

function CharacterService.SetupCharacter(player: Player, character: Model)
	local profile = DataService.Get(player)
	if not profile or not profile.HasCharacter then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = profile.MaxHealth
		humanoid.Health = profile.Health
		local scale = profile.Appearance.Scale or 1
		pcall(function()
			humanoid.BodyDepthScale.Value = scale
			humanoid.BodyHeightScale.Value = scale
			humanoid.BodyWidthScale.Value = scale
			humanoid.HeadScale.Value = math.clamp(scale, 0.75, 1.25)
		end)
	end

	character:SetAttribute("Race", profile.Race)
	character:SetAttribute("Class", profile.Class)
	character:SetAttribute("Level", profile.Level)

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and profile.LastLocation and profile.LastLocation.Position then
		local p = profile.LastLocation.Position
		root.CFrame = CFrame.new(p.X, p.Y + 3, p.Z)
	end

	DataService.Sync(player)
end

function CharacterService.Init()
	RemoteRegistry.RE_CreateCharacter.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then return end
		CharacterService.CreateCharacter(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			CharacterService.SetupCharacter(player, character)
		end)
		if player.Character then
			CharacterService.SetupCharacter(player, player.Character)
		end
	end)

	print("[CharacterService] Ready")
end

return CharacterService
