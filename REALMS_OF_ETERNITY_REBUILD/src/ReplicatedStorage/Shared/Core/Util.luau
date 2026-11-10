--!strict
--[[
	Util — small Roblox helpers shared by server and client.
]]

local Workspace = game:GetService("Workspace")

local Util = {}

function Util.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[Util.DeepCopy(key)] = Util.DeepCopy(item)
	end
	return copy :: any
end

-- Instance factory: Util.Make("Part", { Name = "X", Size = ..., Parent = folder })
-- Parent is assigned last so property changes do not replicate one by one.
function Util.Make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Static decorative part (anchored, no collision by default unless `collide`).
function Util.Part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = collide == true
	part.CanQuery = collide == true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Util.Weld(part0: BasePart, part1: BasePart, name: string?): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Name = name or "Weld"
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

-- Rigid weld preserving an explicit offset (C0) — used for equipment and rig accessories.
function Util.WeldOffset(part0: BasePart, part1: BasePart, c0: CFrame, name: string?): Weld
	local weld = Instance.new("Weld")
	weld.Name = name or "Weld"
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = c0
	weld.C1 = CFrame.identity
	weld.Parent = part1
	return weld
end

function Util.Flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Util.FlatUnit(vector: Vector3, fallback: Vector3?): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 1e-4 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- Raycasts straight down. `ignore` defaults to characters/enemies folders.
function Util.GroundAt(position: Vector3, ignore: { Instance }?, depth: number?): (Vector3?, Instance?, Enum.Material?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = ignore or {}
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local origin = position + Vector3.new(0, 4, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(depth or 400), 0), params)
	if result then
		return result.Position, result.Instance, result.Material
	end
	return nil, nil, nil
end

function Util.FormatNumber(value: number): string
	local rounded = math.floor(value + 0.5)
	local text = tostring(math.abs(rounded))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1 ")))
	formatted = string.gsub(formatted, "^%s+", "")
	return (if rounded < 0 then "-" else "") .. formatted
end

function Util.ServerTime(): number
	return Workspace:GetServerTimeNow()
end

-- Finds the combat model (Model with Humanoid or CombatantId attribute) owning a part.
function Util.ModelFromPart(part: Instance?): Model?
	local current = part
	while current and current ~= Workspace do
		if current:IsA("Model") and (current:GetAttribute("CombatantId") ~= nil or current:FindFirstChildOfClass("Humanoid")) then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Util.Shuffle<T>(list: { T }, rng: Random): { T }
	for index = #list, 2, -1 do
		local swap = rng:NextInteger(1, index)
		list[index], list[swap] = list[swap], list[index]
	end
	return list
end

return Util
