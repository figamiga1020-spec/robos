--!strict
--[[
	Builds a multi-part Forest Guardian visual body (placeholder art).
	Hooked when boss model spawns.
]]

local BossVisuals = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

function BossVisuals.EnhanceForestGuardian(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	root.Size = Vector3.new(6, 8, 5)
	root.Color = Color3.fromRGB(55, 70, 40)
	root.Material = Enum.Material.Wood
	root.Transparency = 0

	local function limb(name: string, size: Vector3, offset: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = root.CFrame * offset
		p.Color = color
		p.Material = Enum.Material.Wood
		p.CanCollide = false
		p.Massless = true
		p.Parent = model
		weld(root, p)
		return p
	end

	-- Head
	local head = limb("Head", Vector3.new(4, 4, 4), CFrame.new(0, 7, 0), Color3.fromRGB(45, 55, 35))
	-- Glowing eyes
	for _, x in { -0.9, 0.9 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.8, 0.8, 0.8)
		eye.Color = Color3.fromRGB(180, 255, 100)
		eye.Material = Enum.Material.Neon
		eye.CFrame = head.CFrame * CFrame.new(x, 0.3, -1.8)
		eye.CanCollide = false
		eye.Massless = true
		eye.Parent = model
		weld(head, eye)
	end

	-- Arms (root limbs)
	limb("LeftArm", Vector3.new(2.2, 9, 2.2), CFrame.new(-5, 1, 0) * CFrame.Angles(0, 0, math.rad(15)), Color3.fromRGB(60, 75, 40))
	limb("RightArm", Vector3.new(2.2, 9, 2.2), CFrame.new(5, 1, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(60, 75, 40))

	-- Stone plates
	limb("ChestPlate", Vector3.new(7, 5, 3), CFrame.new(0, 2, -0.5), Color3.fromRGB(90, 90, 85)).Material = Enum.Material.Slate

	-- Roots hanging
	for i = 1, 5 do
		local r = limb("Root_" .. i, Vector3.new(0.6, 5 + i, 0.6),
			CFrame.new((i - 3) * 1.2, -4, 1.5),
			Color3.fromRGB(50, 40, 25))
		r.Material = Enum.Material.Wood
	end

	-- Aura
	local aura = Instance.new("Part")
	aura.Name = "Aura"
	aura.Shape = Enum.PartType.Ball
	aura.Size = Vector3.new(14, 14, 14)
	aura.Color = Color3.fromRGB(100, 200, 80)
	aura.Material = Enum.Material.ForceField
	aura.Transparency = 0.85
	aura.CanCollide = false
	aura.Massless = true
	aura.CFrame = root.CFrame
	aura.Parent = model
	weld(root, aura)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 255, 100)
	light.Brightness = 2
	light.Range = 40
	light.Parent = root
end

return BossVisuals
