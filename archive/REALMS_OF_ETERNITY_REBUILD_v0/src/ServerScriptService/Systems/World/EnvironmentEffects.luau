--!strict
--[[
	Ambient environment effects: fireflies, mist particles, torch lights, glow plants.
]]

local MaterialPalette = require(game.ReplicatedStorage.Shared.Modules.MaterialPalette)

local EnvironmentEffects = {}

local function particleAnchor(parent: Instance, pos: Vector3, name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(1, 1, 1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = CFrame.new(pos)
	p.Parent = parent
	return p
end

local function fireflies(parent: Instance, pos: Vector3)
	local a = particleAnchor(parent, pos, "Fireflies")
	local e = Instance.new("ParticleEmitter")
	e.Rate = 8
	e.Lifetime = NumberRange.new(2, 4)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.9
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(180, 255, 120))
	e.Acceleration = Vector3.new(0, 0.4, 0)
	e.Drag = 1
	e.Parent = a
end

local function mist(parent: Instance, pos: Vector3, size: number)
	local a = particleAnchor(parent, pos, "Mist")
	local e = Instance.new("ParticleEmitter")
	e.Rate = 5
	e.Lifetime = NumberRange.new(4, 7)
	e.Speed = NumberRange.new(0.2, 0.8)
	e.SpreadAngle = Vector2.new(40, 10)
	e.LightEmission = 0.05
	e.LightInfluence = 0.6
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.3),
		NumberSequenceKeypoint.new(1, size),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(190, 210, 195))
	e.Acceleration = Vector3.new(0.2, 0.1, 0)
	e.Parent = a
end

local function torch(parent: Instance, pos: Vector3)
	local pole = Instance.new("Part")
	pole.Name = "TorchPole"
	pole.Size = Vector3.new(0.6, 6, 0.6)
	pole.Material = Enum.Material.Wood
	pole.Color = Color3.fromRGB(55, 40, 25)
	pole.Anchored = true
	pole.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	pole.Parent = parent

	local flame = Instance.new("Part")
	flame.Name = "TorchFlame"
	flame.Size = Vector3.new(1, 1.4, 1)
	flame.Material = Enum.Material.Neon
	flame.Color = Color3.fromRGB(255, 160, 50)
	flame.Anchored = true
	flame.CanCollide = false
	flame.CFrame = CFrame.new(pos + Vector3.new(0, 6.5, 0))
	flame.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Brightness = 2
	light.Range = 28
	light.Parent = flame

	local e = Instance.new("ParticleEmitter")
	e.Rate = 20
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(20, 20)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 10)),
	})
	e.Acceleration = Vector3.new(0, 6, 0)
	e.Parent = flame
end

local function glowPlant(parent: Instance, pos: Vector3)
	local stem = Instance.new("Part")
	stem.Size = Vector3.new(0.4, 3, 0.4)
	stem.Material = Enum.Material.Grass
	stem.Color = Color3.fromRGB(40, 90, 50)
	stem.Anchored = true
	stem.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
	stem.Parent = parent

	local bulb = Instance.new("Part")
	bulb.Shape = Enum.PartType.Ball
	bulb.Size = Vector3.new(1.4, 1.4, 1.4)
	bulb.Material = Enum.Material.Neon
	bulb.Color = MaterialPalette.Regions.Eldoria.GlowPlant.Color
	bulb.Anchored = true
	bulb.CanCollide = false
	bulb.CFrame = CFrame.new(pos + Vector3.new(0, 3.4, 0))
	bulb.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(130, 255, 150)
	light.Brightness = 1.2
	light.Range = 16
	light.Parent = bulb

	local e = Instance.new("ParticleEmitter")
	e.Rate = 4
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(0.3, 1)
	e.LightEmission = 0.7
	e.Size = NumberSequence.new(0.2, 0.05)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Color = ColorSequence.new(Color3.fromRGB(150, 255, 160))
	e.Parent = bulb
end

function EnvironmentEffects.Apply()
	local world = workspace:FindFirstChild("ROE_World")
	if not world then return end

	local fx = world:FindFirstChild("EnvironmentFX")
	if fx then fx:Destroy() end
	fx = Instance.new("Folder")
	fx.Name = "EnvironmentFX"
	fx.Parent = world

	-- Capital torches
	local torchSpots = {
		Vector3.new(20, 1, 20), Vector3.new(-20, 1, 20),
		Vector3.new(20, 1, -20), Vector3.new(-20, 1, -20),
		Vector3.new(300, 1, 20), Vector3.new(300, 1, -20),
		Vector3.new(100, 1, 70), Vector3.new(-120, 1, 50),
	}
	for _, pos in torchSpots do
		torch(fx, pos)
	end

	-- Eldoria fireflies + mist + glow plants
	local forestSpots = {
		Vector3.new(550, 4, 30), Vector3.new(650, 5, -40), Vector3.new(750, 4, 50),
		Vector3.new(850, 6, -20), Vector3.new(1000, 5, 80), Vector3.new(1150, 5, 10),
		Vector3.new(1280, 6, -30), Vector3.new(1330, 5, 20),
	}
	for _, pos in forestSpots do
		fireflies(fx, pos)
		mist(fx, pos + Vector3.new(0, 1, 0), 6)
	end

	local plantSpots = {
		Vector3.new(600, 1, 45), Vector3.new(700, 1, -55), Vector3.new(900, 1, 30),
		Vector3.new(1100, 1, -40), Vector3.new(1250, 1, 25), Vector3.new(1340, 1, -15),
	}
	for _, pos in plantSpots do
		glowPlant(fx, pos)
	end

	-- Sacred glade ambient nature
	local glade = particleAnchor(fx, Vector3.new(1350, 6, 0), "GladeAura")
	local ge = Instance.new("ParticleEmitter")
	ge.Rate = 10
	ge.Lifetime = NumberRange.new(2, 3.5)
	ge.Speed = NumberRange.new(0.5, 2)
	ge.SpreadAngle = Vector2.new(80, 80)
	ge.LightEmission = 0.5
	ge.Size = NumberSequence.new(0.4, 0.05)
	ge.Transparency = NumberSequence.new(0.4, 1)
	ge.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 255, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 120, 50)),
	})
	ge.Acceleration = Vector3.new(0, 1.5, 0)
	ge.Parent = glade

	print("[EnvironmentEffects] Ambient FX applied")
end

function EnvironmentEffects.Init()
	task.defer(function()
		task.wait(0.5)
		EnvironmentEffects.Apply()
	end)
end

return EnvironmentEffects
