--!strict
--[[
	Anchors — named world points declared in Config/WorldLayout.Anchors.
	Server builders create them; everyone else reads them. The container is a Persistent
	model so anchors are always present on clients even with StreamingEnabled.

	Server:  Anchors.Create(id, cframe)          explicit placement (indoors, rooftops)
	         Anchors.CreateOnFloor(id, ignore?)   raycast to the walkable floor at the XZ guide
	Shared:  Anchors.Get(id) -> BasePart?  ·  Anchors.Wait(id, timeout?)  ·  Anchors.CFrame(id)
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(script.Parent.Parent.Config.WorldLayout)

local Anchors = {}

local CONTAINER = "Anchors"

local function worldFolder(): Instance
	local world = Workspace:FindFirstChild("World")
	if not world then
		assert(RunService:IsServer(), "World folder missing")
		world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = Workspace
	end
	return world :: Instance
end

local function container(): Model
	local world = worldFolder()
	local existing = world:FindFirstChild(CONTAINER)
	if existing then
		return existing :: Model
	end
	local model = Instance.new("Model")
	model.Name = CONTAINER
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = world
	return model
end

function Anchors.Create(id: string, cframe: CFrame): BasePart
	assert(RunService:IsServer(), "server only")
	local def = WorldLayout.Anchors[id]
	if not def then
		warn(`[Anchors] '{id}' is not declared in WorldLayout.Anchors`)
	end
	local parent = container()
	local part = parent:FindFirstChild(id) :: BasePart?
	if not part then
		local created = Instance.new("Part")
		created.Name = id
		created.Size = Vector3.new(1, 1, 1)
		created.Transparency = 1
		created.Anchored = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.Parent = parent
		part = created
	end
	local anchor = part :: BasePart
	anchor.CFrame = cframe
	if def then
		anchor:SetAttribute("Kind", def.Kind)
		anchor:SetAttribute("Note", def.Note)
	end
	return anchor
end

-- Places the anchor on the first surface below its declared XZ (or explicit Height).
function Anchors.CreateOnFloor(id: string, ignore: { Instance }?): BasePart?
	local def = WorldLayout.Anchors[id]
	if not def then
		warn(`[Anchors] unknown anchor '{id}'`)
		return nil
	end
	local startY = if def.Height then def.Height + 6 else 600
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { container() }
	for _, item in ignore or {} do
		table.insert(exclude, item)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local origin = Vector3.new(def.Pos.X, startY, def.Pos.Y)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(startY + 200), 0), params)
	local y = if result then result.Position.Y else (def.Height or WorldLayout.Capital.GroundY)
	local position = Vector3.new(def.Pos.X, y + 0.05, def.Pos.Y)
	return Anchors.Create(id, WorldLayout.YawCFrame(position, def.Yaw))
end

-- Creates every anchor for a region that the builder has not placed explicitly.
function Anchors.CreateRegion(region: string, ignore: { Instance }?)
	local parent = container()
	for id, def in WorldLayout.Anchors do
		if def.Region == region and not parent:FindFirstChild(id) then
			Anchors.CreateOnFloor(id, ignore)
		end
	end
end

function Anchors.Get(id: string): BasePart?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild(CONTAINER)
	return folder and folder:FindFirstChild(id) :: BasePart?
end

function Anchors.Wait(id: string, timeout: number?): BasePart?
	local world = Workspace:WaitForChild("World", timeout or 60)
	local folder = world and world:WaitForChild(CONTAINER, timeout or 60)
	return folder and folder:WaitForChild(id, timeout or 60) :: BasePart?
end

-- Best-known CFrame: real anchor if present, else the declared guide (Y from Height/GroundY).
function Anchors.CFrame(id: string): CFrame?
	local part = Anchors.Get(id)
	if part then
		return part.CFrame
	end
	local def = WorldLayout.Anchors[id]
	if not def then
		return nil
	end
	local y = def.Height or WorldLayout.Capital.GroundY
	return WorldLayout.YawCFrame(Vector3.new(def.Pos.X, y, def.Pos.Y), def.Yaw)
end

return Anchors
