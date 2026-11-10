--!strict
--[[
	Client procedural animation + VFX driven by combat/skill events.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RemoteRegistry = require(ReplicatedStorage.Remotes.RemoteRegistry)
local ProceduralAnimation = require(ReplicatedStorage.Shared.Modules.ProceduralAnimation)
local VFX = require(ReplicatedStorage.Shared.Modules.VFX)

local combo = 0
local lastLight = 0
local blocking = false

local function character(): Model?
	return player.Character
end

local function rootCF(): CFrame?
	local c = character()
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.CFrame or nil
end

RunService.RenderStepped:Connect(function()
	local c = character()
	if c then
		ProceduralAnimation.Update(c)
	end
	-- Also update other nearby player characters lightly
	for _, plr in Players:GetPlayers() do
		if plr ~= player and plr.Character then
			ProceduralAnimation.Update(plr.Character)
		end
	end
end)

-- Local input feedback animations
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local c = character()
	if not c then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local now = os.clock()
		if now - lastLight < 1.0 then
			combo = (combo % 3) + 1
		else
			combo = 1
		end
		lastLight = now
		local clip = combo == 1 and "Light1" or combo == 2 and "Light2" or "Light3"
		ProceduralAnimation.Play(c, clip)
		local cf = rootCF()
		if cf then VFX.Slash(cf, Color3.fromRGB(220, 220, 255)) end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		ProceduralAnimation.Play(c, "Heavy")
		local cf = rootCF()
		if cf then
			VFX.Slash(cf * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(255, 200, 120))
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		blocking = true
		ProceduralAnimation.Play(c, "Block")
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		ProceduralAnimation.Play(c, "Dodge")
		local cf = rootCF()
		if cf then VFX.ShadowBurst(cf.Position) end
	elseif input.KeyCode == Enum.KeyCode.One
		or input.KeyCode == Enum.KeyCode.Two
		or input.KeyCode == Enum.KeyCode.Three
		or input.KeyCode == Enum.KeyCode.Four then
		ProceduralAnimation.Play(c, "Cast")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Q then
		blocking = false
		local c = character()
		if c then ProceduralAnimation.Play(c, "CombatIdle") end
	end
end)

RemoteRegistry.RE_CombatResult.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	if data.Type == "Hit" then
		local pos = nil
		if data.Position then
			pos = data.Position
		elseif typeof(data.Target) == "number" then
			local plr = Players:GetPlayerByUserId(data.Target)
			if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				pos = plr.Character.HumanoidRootPart.Position
				if plr == player then
					ProceduralAnimation.Play(plr.Character, "Hit")
				end
			end
		end
		if pos then VFX.HitSparks(pos) end
	elseif data.Type == "IncomingHit" then
		local c = character()
		if c then ProceduralAnimation.Play(c, "Hit") end
	end
end)

RemoteRegistry.RE_SkillResult.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" or not data.Success then return end
	local caster = Players:GetPlayerByUserId(data.Caster or 0)
	local c = caster and caster.Character
	if c then ProceduralAnimation.Play(c, "Cast") end
	local cf = c and c:FindFirstChild("HumanoidRootPart") and c.HumanoidRootPart.CFrame

	if data.SkillId == "ArcaneBolt" and cf then
		VFX.ArcaneBolt(cf.Position + Vector3.new(0, 2, 0), cf.Position + cf.LookVector * 40)
	elseif data.SkillId == "FlameWave" and cf then
		VFX.FlameWave(cf)
	elseif data.SkillId == "MeteorFragment" and data.Origin then
		VFX.TelegraphCircle(data.Origin, data.Radius or 10, 0.8)
		task.delay(0.8, function()
			VFX.Flash(data.Origin, Color3.fromRGB(255, 100, 40), 12, 0.5)
		end)
	elseif data.SkillId == "RainOfThorns" and data.Origin then
		VFX.GroundRing(data.Origin, data.Radius or 10, Color3.fromRGB(80, 160, 60), 0.8)
	elseif data.SkillId == "ShadowStep" and cf then
		VFX.ShadowBurst(cf.Position)
	elseif data.SkillId == "RuneWard" and cf then
		VFX.GroundRing(cf.Position, 5, Color3.fromRGB(120, 160, 255), 1.2)
	elseif data.SkillId == "IronGuard" and cf then
		VFX.GroundRing(cf.Position, 4, Color3.fromRGB(180, 180, 200), 0.8)
	elseif data.Type == "AoE" and data.Origin then
		VFX.Flash(data.Origin, Color3.fromRGB(200, 160, 80), 8, 0.4)
	end
end)

RemoteRegistry.RE_BossEvent.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	if data.Type == "AbilityTelegraph" then
		local arena = data.Arena or Vector3.new(1350, 18, 0)
		local windup = data.Windup or 1
		if data.Ability == "RootSlam" then
			VFX.TelegraphCircle(arena + Vector3.new(0, 0.2, 0), 16, windup)
			task.delay(windup, function()
				VFX.Flash(arena, Color3.fromRGB(100, 160, 60), 14, 0.4)
				for i = 1, 6 do
					local a = (i / 6) * math.pi * 2
					VFX.RootSpike(arena + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10))
				end
			end)
		elseif data.Ability == "BranchSweep" then
			VFX.GroundRing(arena, 22, Color3.fromRGB(255, 80, 60), windup)
		elseif data.Ability == "RootLines" then
			for i = -2, 2 do
				local pos = arena + Vector3.new(i * 8, 0.2, 0)
				VFX.TelegraphCircle(pos, 4, windup)
				task.delay(windup, function()
					VFX.RootSpike(pos)
				end)
			end
		elseif data.Ability == "AwakenedFury" then
			VFX.Flash(arena + Vector3.new(0, 8, 0), Color3.fromRGB(180, 255, 100), 20, 0.8)
			VFX.GroundRing(arena, 30, Color3.fromRGB(150, 255, 80), 1.2)
		elseif data.Ability == "GuardianCall" then
			VFX.GroundRing(arena, 12, Color3.fromRGB(80, 140, 60), 1)
		end
	elseif data.Type == "Intro" then
		local arena = data.Arena or Vector3.new(1350, 18, 0)
		VFX.GroundRing(arena, 40, Color3.fromRGB(120, 200, 80), 2)
		VFX.Flash(arena + Vector3.new(0, 10, 0), Color3.fromRGB(150, 255, 100), 16, 1)
	end
end)

player.CharacterAdded:Connect(function(c)
	task.wait(0.5)
	ProceduralAnimation.Play(c, "Idle")
end)

print("[AnimationController] Procedural anim + VFX ready")
