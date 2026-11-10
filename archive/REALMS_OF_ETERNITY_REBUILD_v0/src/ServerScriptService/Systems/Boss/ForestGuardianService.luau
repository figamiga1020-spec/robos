--!strict
--[[
	Forest Guardian — 3-phase regional boss.
	Placeholder model until Studio meshes exist.
	Mechanics are server-driven and party-scaled.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EnemiesConfig = require(game.ReplicatedStorage.Shared.Config.Enemies.EnemiesConfig)
local PartyService = require(script.Parent.Parent.Party.PartyService)
local EnemyService = require(script.Parent.Parent.Enemy.EnemyService)
local WorldLayout = require(game.ReplicatedStorage.Shared.Config.World.WorldLayout)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local ForestGuardianService = {}

local bossState: any = nil
local ARENA = Vector3.new(1350, 18, 0)
local ARENA_RADIUS = 90

local function phaseOf(hum: Humanoid): number
	local pct = hum.Health / hum.MaxHealth
	if pct > 0.66 then return 1 end
	if pct > 0.33 then return 2 end
	return 3
end

function ForestGuardianService.SpawnForParty(leader: Player)
	if bossState and bossState.Model and bossState.Model.Parent then
		RemoteRegistry.RE_BossEvent:FireClient(leader, { Type = "AlreadyActive" })
		return
	end

	local size = PartyService.GetPartySizeForPlayer(leader)
	local scale = PartyService.GetScale(size)
	local def = EnemiesConfig.Get("ForestGuardian")
	if not def then return end

	local hp = math.floor(def.Health * scale.Health)
	local id = EnemyService.Spawn("ForestGuardian", CFrame.new(ARENA + Vector3.new(0, 5, 0)), hp)
	if not id then return end

	bossState = {
		InstanceId = id,
		Phase = 1,
		LastAbility = 0,
		AbilityIndex = 1,
		Engaged = false,
	}

	local members = PartyService.GetMembers(leader)
	for _, p in members do
		RemoteRegistry.RE_BossEvent:FireClient(p, {
			Type = "Intro",
			BossName = "Forest Guardian",
			Phases = 3,
			Arena = ARENA,
		})
	end
end

local function announce(msg: string)
	if not bossState then return end
	for _, p in Players:GetPlayers() do
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local d = (p.Character.HumanoidRootPart.Position - ARENA).Magnitude
			if d < ARENA_RADIUS + 40 then
				RemoteRegistry.RE_BossEvent:FireClient(p, { Type = "Announcement", Text = msg })
			end
		end
	end
end

local ABILITIES = {
	[1] = { "RootSlam", "BranchSweep", "RootLines" },
	[2] = { "RootSlam", "BranchSweep", "RootLines", "GuardianCall" },
	[3] = { "RootSlam", "BranchSweep", "RootLines", "GuardianCall", "AwakenedFury" },
}

function ForestGuardianService.Init()
	-- Phase / ability telegraph loop (reads boss humanoid in workspace by attribute)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not bossState then continue end
			-- Find boss model
			local model: Model? = nil
			for _, inst in workspace:GetChildren() do
				if inst:IsA("Model") and inst:GetAttribute("EnemyId") == "ForestGuardian" and inst:FindFirstChildOfClass("Humanoid") then
					model = inst
					break
				end
			end
			if not model then
				bossState = nil
				continue
			end
			local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			if hum.Health <= 0 then
				announce("The Forest Guardian falls. The glade grows still.")
				RemoteRegistry.RE_BossEvent:FireAllClients({ Type = "Defeated" })
				bossState = nil
				continue
			end

			local phase = phaseOf(hum)
			if phase ~= bossState.Phase then
				bossState.Phase = phase
				announce("Phase " .. phase .. " — the Guardian adapts!")
				RemoteRegistry.RE_BossEvent:FireAllClients({ Type = "PhaseChange", Phase = phase })
			end

			local now = os.clock()
			local cd = phase == 3 and 4.5 or phase == 2 and 5.5 or 6.5
			if now - bossState.LastAbility >= cd then
				bossState.LastAbility = now
				local list = ABILITIES[phase]
				local ability = list[((bossState.AbilityIndex - 1) % #list) + 1]
				bossState.AbilityIndex += 1
				-- Telegraph
				RemoteRegistry.RE_BossEvent:FireAllClients({
					Type = "AbilityTelegraph",
					Ability = ability,
					Phase = phase,
					Windup = ability == "RootSlam" and 1.2 or ability == "BranchSweep" and 0.9 or 1.0,
					Arena = ARENA,
				})
			end
		end
	end)

	RemoteRegistry.RE_DungeonAction.OnServerEvent:Connect(function(player, data)
		if typeof(data) ~= "table" then return end
		if data.Action == "EngageForestGuardian" then
			ForestGuardianService.SpawnForParty(player)
		end
	end)

	print("[ForestGuardianService] Ready")
end

return ForestGuardianService
