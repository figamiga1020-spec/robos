--!strict
--[[
	Expanded VFX — particles, beams, trails, lights, telegraphs.
	Uses built-in ParticleEmitter (no custom texture asset IDs).
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VFX = {}

local function basePart(size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Parent = workspace
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = true
	e.Rate = props.Rate or 20
	e.Lifetime = NumberRange.new(props.LifetimeMin or 0.4, props.LifetimeMax or 1.0)
	e.Speed = NumberRange.new(props.SpeedMin or 1, props.SpeedMax or 4)
	e.SpreadAngle = Vector2.new(props.Spread or 30, props.Spread or 30)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.LightEmission = props.LightEmission or 0.4
	e.LightInfluence = props.LightInfluence or 0.2
	e.Size = props.Size or NumberSequence.new({
		NumberSequenceKeypoint.new(0, props.SizeStart or 0.4),
		NumberSequenceKeypoint.new(1, props.SizeEnd or 0.05),
	})
	e.Transparency = props.Transparency or NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = props.Color or ColorSequence.new(Color3.fromRGB(255, 255, 255))
	e.Acceleration = props.Acceleration or Vector3.new(0, 2, 0)
	e.Drag = props.Drag or 2
	e.Parent = parent
	return e
end

function VFX.Flash(position: Vector3, color: Color3, size: number?, life: number?)
	size = size or 4
	life = life or 0.35
	local p = basePart(Vector3.new(size, size, size), color)
	p.Shape = Enum.PartType.Ball
	p.CFrame = CFrame.new(position)
	p.Transparency = 0.25
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 3
	light.Range = size * 3
	light.Parent = p
	TweenService:Create(p, TweenInfo.new(life), {
		Size = Vector3.new(size * 2.4, size * 2.4, size * 2.4),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(life), { Brightness = 0 }):Play()
	Debris:AddItem(p, life + 0.05)
end

function VFX.BurstParticles(position: Vector3, color: Color3, count: number?)
	local anchor = basePart(Vector3.new(0.4, 0.4, 0.4), color)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(position)
	local e = emitter(anchor, {
		Rate = 0,
		LifetimeMin = 0.3, LifetimeMax = 0.7,
		SpeedMin = 6, SpeedMax = 14,
		Spread = 180,
		SizeStart = 0.5, SizeEnd = 0.05,
		LightEmission = 0.6,
		Color = ColorSequence.new(color),
		Acceleration = Vector3.new(0, -5, 0),
	})
	e:Emit(count or 18)
	Debris:AddItem(anchor, 1.2)
end

function VFX.Slash(origin: CFrame, color: Color3?)
	color = color or Color3.fromRGB(220, 225, 255)
	local p = basePart(Vector3.new(0.25, 0.08, 7), color)
	p.CFrame = origin * CFrame.new(0, 1, -3) * CFrame.Angles(0, 0, math.rad(40))
	p.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 12
	light.Parent = p
	local e = emitter(p, {
		Rate = 40, LifetimeMin = 0.15, LifetimeMax = 0.35,
		SpeedMin = 1, SpeedMax = 3, Spread = 15,
		SizeStart = 0.25, SizeEnd = 0.02,
		Color = ColorSequence.new(color),
		Acceleration = Vector3.zero,
	})
	TweenService:Create(p, TweenInfo.new(0.22), {
		Transparency = 1,
		Size = Vector3.new(0.08, 0.04, 9),
	}):Play()
	task.delay(0.15, function() e.Enabled = false end)
	Debris:AddItem(p, 0.4)
end

function VFX.ArcaneBolt(from: Vector3, to: Vector3)
	local p = basePart(Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(130, 170, 255))
	p.Shape = Enum.PartType.Ball
	p.CFrame = CFrame.new(from)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(130, 170, 255)
	light.Brightness = 2
	light.Range = 16
	light.Parent = p
	local e = emitter(p, {
		Rate = 50, LifetimeMin = 0.15, LifetimeMax = 0.35,
		SpeedMin = 0.5, SpeedMax = 2, Spread = 40,
		SizeStart = 0.35, SizeEnd = 0.05,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 210, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 100, 255)),
		}),
		Acceleration = Vector3.zero,
	})
	local att0 = Instance.new("Attachment", p)
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, 0.3, 0)
	att1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.25
	trail.LightEmission = 0.7
	trail.Color = ColorSequence.new(Color3.fromRGB(140, 180, 255))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = p
	TweenService:Create(p, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { CFrame = CFrame.new(to) }):Play()
	task.delay(0.22, function()
		VFX.Flash(to, Color3.fromRGB(140, 180, 255), 3.5, 0.3)
		VFX.BurstParticles(to, Color3.fromRGB(150, 190, 255), 14)
		e.Enabled = false
	end)
	Debris:AddItem(p, 0.6)
end

function VFX.FlameWave(origin: CFrame)
	for i = 1, 6 do
		local p = basePart(Vector3.new(5, 2, 3.5), Color3.fromRGB(255, 110, 35))
		p.CFrame = origin * CFrame.new(0, 0.8, -i * 3.5)
		p.Transparency = 0.25
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Brightness = 2
		light.Range = 14
		light.Parent = p
		emitter(p, {
			Rate = 30, LifetimeMin = 0.25, LifetimeMax = 0.55,
			SpeedMin = 2, SpeedMax = 6, Spread = 50,
			SizeStart = 0.6, SizeEnd = 0.1,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 30)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 20, 10)),
			}),
			Acceleration = Vector3.new(0, 6, 0),
		})
		TweenService:Create(p, TweenInfo.new(0.5), {
			Transparency = 1,
			Size = Vector3.new(7, 0.5, 4),
			CFrame = p.CFrame * CFrame.new(0, 1.5, -2),
		}):Play()
		Debris:AddItem(p, 0.55)
	end
end

function VFX.GroundRing(position: Vector3, radius: number, color: Color3, life: number?)
	life = life or 1.0
	local p = basePart(Vector3.new(0.2, 0.5, 0.5), color)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.45
	TweenService:Create(p, TweenInfo.new(life * 0.5), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Transparency = 0.3,
	}):Play()
	task.delay(life * 0.5, function()
		TweenService:Create(p, TweenInfo.new(life * 0.5), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(p, life + 0.1)
end

function VFX.TelegraphCircle(position: Vector3, radius: number, windup: number)
	local p = basePart(Vector3.new(0.15, 0.4, 0.4), Color3.fromRGB(255, 50, 50))
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.55
	local fill = basePart(Vector3.new(0.05, 0.2, 0.2), Color3.fromRGB(255, 80, 60))
	fill.Shape = Enum.PartType.Cylinder
	fill.CFrame = p.CFrame
	fill.Transparency = 0.7
	TweenService:Create(p, TweenInfo.new(windup, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		Transparency = 0.25,
	}):Play()
	TweenService:Create(fill, TweenInfo.new(windup), {
		Size = Vector3.new(0.05, radius * 1.6, radius * 1.6),
		Transparency = 0.55,
	}):Play()
	Debris:AddItem(p, windup + 0.2)
	Debris:AddItem(fill, windup + 0.2)
	return p
end

function VFX.RootSpike(position: Vector3)
	local p = basePart(Vector3.new(1.4, 7, 1.4), Color3.fromRGB(55, 90, 40), Enum.Material.Wood)
	p.CFrame = CFrame.new(position + Vector3.new(0, -3.5, 0))
	emitter(p, {
		Rate = 12, LifetimeMin = 0.4, LifetimeMax = 0.8,
		SpeedMin = 1, SpeedMax = 3, Spread = 40,
		SizeStart = 0.3, SizeEnd = 0.05,
		Color = ColorSequence.new(Color3.fromRGB(100, 160, 70)),
		Acceleration = Vector3.new(0, 2, 0),
	})
	TweenService:Create(p, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
		CFrame = CFrame.new(position + Vector3.new(0, 3.2, 0)),
	}):Play()
	task.delay(0.9, function()
		TweenService:Create(p, TweenInfo.new(0.35), {
			CFrame = CFrame.new(position + Vector3.new(0, -4, 0)),
			Transparency = 1,
		}):Play()
	end)
	Debris:AddItem(p, 1.4)
end

function VFX.HitSparks(position: Vector3)
	VFX.BurstParticles(position, Color3.fromRGB(255, 230, 140), 12)
	local p = basePart(Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 240, 180))
	p.Transparency = 1
	p.CFrame = CFrame.new(position)
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 10
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = p
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	Debris:AddItem(p, 0.3)
end

function VFX.ShadowBurst(position: Vector3)
	VFX.Flash(position, Color3.fromRGB(50, 20, 70), 5, 0.4)
	VFX.BurstParticles(position, Color3.fromRGB(40, 15, 60), 20)
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		local p = basePart(Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(30, 10, 45))
		p.CFrame = CFrame.new(position)
		TweenService:Create(p, TweenInfo.new(0.4), {
			CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 7, 2, math.sin(a) * 7)),
			Transparency = 1,
			Size = Vector3.new(2.5, 2.5, 2.5),
		}):Play()
		Debris:AddItem(p, 0.45)
	end
end

function VFX.HealPulse(position: Vector3)
	VFX.Flash(position, Color3.fromRGB(90, 230, 130), 3.5, 0.5)
	VFX.GroundRing(position, 5, Color3.fromRGB(90, 230, 130), 0.7)
	VFX.BurstParticles(position + Vector3.new(0, 2, 0), Color3.fromRGB(120, 255, 160), 10)
end

function VFX.NatureAura(position: Vector3, duration: number?)
	duration = duration or 2
	local anchor = basePart(Vector3.new(1, 1, 1), Color3.fromRGB(100, 200, 100))
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(position)
	local e = emitter(anchor, {
		Rate = 15, LifetimeMin = 0.8, LifetimeMax = 1.4,
		SpeedMin = 1, SpeedMax = 3, Spread = 60,
		SizeStart = 0.35, SizeEnd = 0.05,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 255, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 100, 50)),
		}),
		Acceleration = Vector3.new(0, 3, 0),
	})
	task.delay(duration, function() e.Enabled = false end)
	Debris:AddItem(anchor, duration + 1.5)
end

function VFX.MeteorImpact(position: Vector3, radius: number)
	VFX.TelegraphCircle(position, radius, 0.9)
	task.delay(0.9, function()
		VFX.Flash(position, Color3.fromRGB(255, 100, 40), radius, 0.5)
		VFX.BurstParticles(position, Color3.fromRGB(255, 140, 40), 28)
		VFX.GroundRing(position, radius, Color3.fromRGB(255, 120, 50), 0.8)
	end)
end

function VFX.Beam(from: Vector3, to: Vector3, color: Color3, life: number?)
	life = life or 0.35
	local a0 = Instance.new("Part")
	a0.Anchored = true
	a0.CanCollide = false
	a0.Transparency = 1
	a0.Size = Vector3.new(0.2, 0.2, 0.2)
	a0.CFrame = CFrame.new(from)
	a0.Parent = workspace
	local a1 = a0:Clone()
	a1.CFrame = CFrame.new(to)
	a1.Parent = workspace
	local att0 = Instance.new("Attachment", a0)
	local att1 = Instance.new("Attachment", a1)
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Width0 = 1.2
	beam.Width1 = 0.4
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 0.8
	beam.Transparency = NumberSequence.new(0.15, 0.6)
	beam.FaceCamera = true
	beam.Parent = a0
	TweenService:Create(beam, TweenInfo.new(life), { Width0 = 0, Width1 = 0 }):Play()
	Debris:AddItem(a0, life + 0.1)
	Debris:AddItem(a1, life + 0.1)
end

return VFX
