--!strict
--[[
	Builds placeholder but readable world geometry for Aurenholm + Eldoria.
	Replace with MeshPart/Terrain art pass in Studio later.
]]

local WorldLayout = require(game.ReplicatedStorage.Shared.Config.World.WorldLayout)
local MaterialPalette = require(game.ReplicatedStorage.Shared.Modules.MaterialPalette)
local SurfaceTextures = require(game.ReplicatedStorage.Shared.Modules.SurfaceTextures)

local WorldBuilder = {}
local A = MaterialPalette.Regions.Aurenholm
local E = MaterialPalette.Regions.Eldoria

local function p(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Name = name or "WorldPart"
	part.Parent = parent
	return part
end

local function label(parent: BasePart, text: string, offset: Vector3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 200, 0, 40)
	bb.StudsOffset = offset or Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = Color3.fromRGB(230, 210, 170)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextStrokeTransparency = 0.5
	t.Parent = bb
end

local function building(folder: Folder, pos: Vector3, size: Vector3, color: Color3, roofColor: Color3, name: string)
	local base = p(folder, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), color, Enum.Material.Brick, name)
	-- roof
	p(folder, Vector3.new(size.X + 2, 2, size.Z + 2),
		CFrame.new(pos + Vector3.new(0, size.Y + 1, 0)),
		roofColor, Enum.Material.WoodPlanks, name .. "_Roof")
	-- door
	p(folder, Vector3.new(4, 8, 1),
		CFrame.new(pos + Vector3.new(0, 4, size.Z / 2 + 0.4)),
		Color3.fromRGB(40, 30, 20), Enum.Material.Wood, name .. "_Door")
	label(base, name, Vector3.new(0, size.Y / 2 + 4, 0))
	return base
end

local function tree(folder: Folder, pos: Vector3, scale: number?)
	scale = scale or 1
	local trunk = p(folder, Vector3.new(2 * scale, 10 * scale, 2 * scale),
		CFrame.new(pos + Vector3.new(0, 5 * scale, 0)),
		Color3.fromRGB(70, 50, 30), Enum.Material.Wood, "TreeTrunk")
	p(folder, Vector3.new(10 * scale, 8 * scale, 10 * scale),
		CFrame.new(pos + Vector3.new(0, 12 * scale, 0)),
		Color3.fromRGB(35, 90, 45), Enum.Material.Grass, "TreeCanopy")
	return trunk
end

local function road(folder: Folder, from: Vector3, to: Vector3, width: number)
	local mid = (from + to) / 2
	local dist = (to - from).Magnitude
	local cf = CFrame.lookAt(mid, to) * CFrame.Angles(0, 0, 0)
	-- flatten: use look at on XZ
	local dir = (to - from) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then return end
	cf = CFrame.new(mid.X, math.min(from.Y, to.Y) + 0.2, mid.Z) * CFrame.lookAt(Vector3.zero, dir.Unit)
	local part = p(folder, Vector3.new(width, 0.4, dist + 4),
		CFrame.new(mid.X, mid.Y + 0.15, mid.Z) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0),
		Color3.fromRGB(90, 80, 65), Enum.Material.Cobblestone, "Road")
	return part
end

function WorldBuilder.Build()
	local world = workspace:FindFirstChild("ROE_World")
	if world then world:Destroy() end
	world = Instance.new("Folder")
	world.Name = "ROE_World"
	world.Parent = workspace

	local capital = Instance.new("Folder")
	capital.Name = "Aurenholm"
	capital.Parent = world

	local forest = Instance.new("Folder")
	forest.Name = "Eldoria"
	forest.Parent = world

	-- Base ground planes (under tiles)
	p(capital, Vector3.new(700, 2, 700), CFrame.new(0, 0, 0), A.Ground.Color, A.Ground.Material, "CapitalGround")
	p(forest, Vector3.new(1100, 2, 1200), CFrame.new(950, 0, 0), E.Ground.Color, E.Ground.Material, "ForestGround")

	-- TEXTURED PLAZA FLOOR (stone tiles)
	SurfaceTextures.TiledFloor(
		capital,
		Vector3.new(0, 1, 0),
		100, 100,
		8,
		A.Plaza.Color,
		Enum.Material.Limestone,
		1.2
	)
	-- Market street floor
	SurfaceTextures.TiledFloor(
		capital,
		Vector3.new(80, 1, 40),
		80, 40,
		6,
		Color3.fromRGB(110, 100, 88),
		Enum.Material.Cobblestone,
		1.15
	)
	-- Castle courtyard floor
	SurfaceTextures.TiledFloor(
		capital,
		Vector3.new(0, 1, -150),
		60, 50,
		7,
		Color3.fromRGB(125, 118, 105),
		Enum.Material.Slate,
		1.15
	)

	p(capital, Vector3.new(8, 16, 8), CFrame.new(0, 9, 0), A.Marble.Color, A.Marble.Material, "PlazaObelisk")

	-- TEXTURED CITY WALLS (stone blocks)
	local wallH, wallT = 40, 8
	SurfaceTextures.BlockWall(capital, Vector3.new(0, wallH / 2, -350), 700, wallH, wallT, "X", A.Wall.Color, Enum.Material.Slate)
	SurfaceTextures.BlockWall(capital, Vector3.new(0, wallH / 2, 350), 700, wallH, wallT, "X", A.Wall.Color, Enum.Material.Slate)
	SurfaceTextures.BlockWall(capital, Vector3.new(-350, wallH / 2, 0), 700, wallH, wallT, "Z", A.Wall.Color, Enum.Material.Slate)
	-- East wall with gate gap (two segments)
	SurfaceTextures.BlockWall(capital, Vector3.new(350, wallH / 2, -180), 280, wallH, wallT, "Z", A.Wall.Color, Enum.Material.Slate)
	SurfaceTextures.BlockWall(capital, Vector3.new(350, wallH / 2, 180), 280, wallH, wallT, "Z", A.Wall.Color, Enum.Material.Slate)

	-- Gate pillars
	p(capital, Vector3.new(12, 50, 12), CFrame.new(340, 25, -35), A.Marble.Color, Enum.Material.Limestone, "GatePillarL")
	p(capital, Vector3.new(12, 50, 12), CFrame.new(340, 25, 35), A.Marble.Color, Enum.Material.Limestone, "GatePillarR")
	local gate = p(capital, Vector3.new(6, 28, 40), CFrame.new(340, 14, 0), A.Wood.Color, Enum.Material.Wood, "EastGate")
	label(gate, "Eastern Gate → Eldoria", Vector3.new(0, 20, 0))

	-- Royal Castle (full textured build)
	local CastleBuilder = require(script.Parent.CastleBuilder)
	CastleBuilder.Build(capital, Vector3.new(0, 0, -180))

	-- Key buildings
	building(capital, Vector3.new(120, 0, 80), Vector3.new(50, 22, 40), Color3.fromRGB(120, 100, 80), Color3.fromRGB(90, 50, 40), "Market Hall")
	building(capital, Vector3.new(-140, 0, 60), Vector3.new(40, 20, 35), Color3.fromRGB(90, 90, 95), Color3.fromRGB(50, 50, 55), "Forge Quarter")
	building(capital, Vector3.new(150, 0, -100), Vector3.new(45, 28, 40), Color3.fromRGB(90, 100, 130), Color3.fromRGB(50, 60, 90), "Arcane Academy")
	building(capital, Vector3.new(-80, 0, -120), Vector3.new(40, 30, 40), Color3.fromRGB(150, 140, 120), Color3.fromRGB(80, 70, 60), "Temple")
	building(capital, Vector3.new(60, 0, 140), Vector3.new(35, 18, 30), Color3.fromRGB(100, 70, 50), Color3.fromRGB(60, 40, 30), "The Broken Crown")
	building(capital, Vector3.new(-160, 0, -40), Vector3.new(50, 22, 40), Color3.fromRGB(80, 85, 90), Color3.fromRGB(50, 55, 60), "Barracks")

	-- NPC markers
	for id, npc in WorldLayout.NPCs do
		local folder = npc.RegionId == "Eldoria" and forest or capital
		local marker = p(folder, Vector3.new(2, 5, 2), CFrame.new(npc.Position + Vector3.new(0, 2.5, 0)),
			Color3.fromRGB(200, 180, 100), Enum.Material.Neon, "NPC_" .. id)
		marker.Transparency = 0.3
		label(marker, npc.DisplayName, Vector3.new(0, 4, 0))
		-- Proximity prompt for interaction
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = npc.DisplayName
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.Parent = marker
		prompt:SetAttribute("NPCId", id)
	end

	-- Roads / paths with surface texture
	SurfaceTextures.TiledFloor(world, Vector3.new(410, 10, 0), 180, 26, 5, Color3.fromRGB(95, 85, 70), Enum.Material.Cobblestone, 10.3)
	SurfaceTextures.DirtPath(world, Vector3.new(500, 12, 0), Vector3.new(900, 14, 0), 18)
	SurfaceTextures.DirtPath(world, Vector3.new(900, 14, 0), Vector3.new(1200, 16, 0), 14)

	-- Eldoria trees
	local treeSpots = {
		Vector3.new(480, 1, 40), Vector3.new(510, 1, -50), Vector3.new(560, 1, 30),
		Vector3.new(620, 1, -40), Vector3.new(680, 1, 70), Vector3.new(720, 1, -20),
		Vector3.new(780, 1, 50), Vector3.new(840, 1, -80), Vector3.new(900, 1, 20),
		Vector3.new(960, 1, 90), Vector3.new(1000, 1, -40), Vector3.new(1080, 1, 30),
		Vector3.new(1120, 1, -90), Vector3.new(1160, 1, 50), Vector3.new(1280, 1, 40),
		Vector3.new(1300, 1, -50), Vector3.new(1320, 1, 20),
	}
	for _, pos in treeSpots do
		tree(forest, pos, 0.9 + math.random() * 0.6)
	end

	-- Giant ancient tree at sacred glade
	tree(forest, Vector3.new(1350, 1, 0), 2.8)
	local gladeRing = p(forest, Vector3.new(160, 1, 160), CFrame.new(1350, 1.5, 0),
		Color3.fromRGB(55, 90, 50), Enum.Material.Grass, "SacredGlade")
	label(gladeRing, "Sacred Glade — Forest Guardian", Vector3.new(0, 12, 0))

	-- Temple entrance + stone floor
	building(forest, Vector3.new(1200, 0, 0), Vector3.new(40, 25, 30),
		Color3.fromRGB(70, 80, 60), Color3.fromRGB(40, 50, 35), "Temple of Roots")
	SurfaceTextures.TiledFloor(forest, Vector3.new(1200, 1, 0), 36, 28, 6, Color3.fromRGB(75, 82, 68), Enum.Material.Rock, 1.2)

	-- Sacred glade ring stones
	SurfaceTextures.TiledFloor(forest, Vector3.new(1350, 1, 0), 40, 40, 8, Color3.fromRGB(60, 70, 50), Enum.Material.Rock, 1.3)

	-- Woodfolk village houses
	building(forest, Vector3.new(940, 0, 110), Vector3.new(20, 12, 18),
		Color3.fromRGB(90, 70, 45), Color3.fromRGB(50, 80, 40), "Woodfolk Hut")
	building(forest, Vector3.new(970, 0, 130), Vector3.new(18, 11, 16),
		Color3.fromRGB(85, 65, 40), Color3.fromRGB(45, 75, 35), "Woodfolk Hut 2")

	-- Atmosphere: gentle fog parts (decorative)
	for i = 1, 8 do
		local fog = p(forest, Vector3.new(40, 8, 40),
			CFrame.new(600 + i * 80, 6, math.sin(i) * 40),
			Color3.fromRGB(180, 200, 180), Enum.Material.ForceField, "Mist")
		fog.Transparency = 0.85
		fog.CanCollide = false
	end

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 2, 40)
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(100, 90, 70)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Name = "AurenholmSpawn"
	spawn.Parent = capital

	print("[WorldBuilder] Aurenholm + Eldoria placeholder world built")
end

function WorldBuilder.Init()
	WorldBuilder.Build()
end

return WorldBuilder
