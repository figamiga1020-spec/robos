--!strict
--[[
	Continuous world helpers: zone reach detection for quests, death respawn.
	NO portals — player walks between Aurenholm and Eldoria.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local QuestService = require(script.Parent.Parent.Quest.QuestService)
local WorldLayout = require(game.ReplicatedStorage.Shared.Config.World.WorldLayout)
local RemoteRegistry = require(game.ReplicatedStorage.Remotes.RemoteRegistry)

local WorldService = {}

local lastZone: { [number]: string } = {}

local function allZones()
	local list = {}
	for _, region in WorldLayout.Regions do
		for _, zone in region.Zones or {} do
			table.insert(list, zone)
		end
	end
	return list
end

local ZONES = allZones()

function WorldService.Respawn(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	profile.Health = profile.MaxHealth
	profile.Resource = profile.MaxResource
	profile.Stamina = profile.MaxStamina

	-- Respawn at last safe region center or Aurenholm
	local regionId = profile.LastLocation and profile.LastLocation.RegionId or "Aurenholm"
	if regionId == "Eldoria" then
		-- Respawn at Woodfolk village as safe point
		profile.LastLocation.Position = { X = 950, Y = 16, Z = 120 }
	else
		local spawn = WorldLayout.Spawn.CFrame.Position
		profile.LastLocation = {
			RegionId = "Aurenholm",
			Position = { X = spawn.X, Y = spawn.Y, Z = spawn.Z },
		}
	end

	DataService.Sync(player)
	player:LoadCharacter()
end

function WorldService.Init()
	-- Zone enter detection for Reach objectives
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.75 then return end
		acc = 0
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root then continue end
			local pos = root.Position
			for _, zone in ZONES do
				if (pos - zone.Position).Magnitude <= zone.Radius then
					if lastZone[player.UserId] ~= zone.Id then
						lastZone[player.UserId] = zone.Id
						QuestService.OnReach(player, zone.Id)
						-- Track region for save
						DataService.Update(player, function(profile)
							for regionId, region in WorldLayout.Regions do
								for _, z in region.Zones or {} do
									if z.Id == zone.Id then
										profile.LastLocation.RegionId = regionId
										profile.LastLocation.Position = {
											X = pos.X, Y = pos.Y, Z = pos.Z,
										}
										return
									end
								end
							end
						end)
					end
					break
				end
			end
		end
	end)

	-- Death
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if not humanoid then return end
			humanoid.Died:Connect(function()
				local profile = DataService.Get(player)
				if profile then
					profile.Health = 0
					DataService.Sync(player)
				end
				RemoteRegistry.RE_WorldMessage:FireClient(player, {
					Type = "Death",
					Message = "You have fallen. You will return to a safe place.",
				})
				task.delay(4, function()
					if player.Parent then
						WorldService.Respawn(player)
					end
				end)
			end)
		end)
	end)

	RemoteRegistry.RE_RequestRespawn.OnServerEvent:Connect(function(player)
		WorldService.Respawn(player)
	end)

	print("[WorldService] Ready — continuous world, no portals")
end

return WorldService
