--!strict
--[[
	Royal Castle of Aurenholm — modular textured structure.
	Stone block walls, tiled floors, towers, battlements, banners, windows.
]]

local MaterialPalette = require(game.ReplicatedStorage.Shared.Modules.MaterialPalette)
local SurfaceTextures = require(game.ReplicatedStorage.Shared.Modules.SurfaceTextures)

local CastleBuilder = {}
local A = MaterialPalette.Regions.Aurenholm

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, name: string?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.Name = name or "CastlePart"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function shade(c: Color3, d: number): Color3
	return Color3.new(math.clamp(c.R + d, 0, 1), math.clamp(c.G + d, 0, 1), math.clamp(c.B + d, 0, 1))
end

local function noise(i: number, j: number): number
	local n = math.sin(i * 12.9898 + j * 78.233) * 43758.5453
	n = n - math.floor(n)
	return (n - 0.5) * 0.1
end

local STONE = Color3.fromRGB(112, 108, 100)
local STONE_DARK = Color3.fromRGB(85, 82, 76)
local STONE_LIGHT = Color3.fromRGB(135, 130, 120)
local ROOF = Color3.fromRGB(78, 36, 36)
local BANNER = Color3.fromRGB(90, 30, 40)
local GOLD = Color3.fromRGB(200, 170, 90)
local WOOD = Color3.fromRGB(62, 44, 28)

local function blockFacade(parent: Instance, center: Vector3, width: number, height: number, depth: number, facing: "N" | "S" | "E" | "W")
	-- Build outer wall as stone blocks on the facing side
	local folder = Instance.new("Folder")
	folder.Name = "Facade_" .. facing
	folder.Parent = parent

	local blockW, blockH = 8, 7
	local cols = math.max(1, math.floor(width / blockW))
	local rows = math.max(1, math.floor(height / blockH))

	for row = 0, rows - 1 do
		local bond = (row % 2 == 0) and 0 or (blockW * 0.45)
		for col = 0, cols - 1 do
			local bw = blockW - 0.3
			local p = Instance.new("Part")
			p.Name = string.format("Stone_%d_%d", row, col)
			p.Anchored = true
			p.Material = Enum.Material.Limestone
			p.Color = shade(STONE, noise(row + 3, col + 1))
			local x, y, z = center.X, center.Y - height / 2 + row * blockH + blockH / 2, center.Z
			if facing == "N" or facing == "S" then
				p.Size = Vector3.new(bw, blockH - 0.25, 2.2)
				x = center.X - width / 2 + col * blockW + blockW / 2 + bond
				z = center.Z + (if facing == "N" then -depth / 2 - 0.5 else depth / 2 + 0.5)
			else
				p.Size = Vector3.new(2.2, blockH - 0.25, bw)
				z = center.Z - width / 2 + col * blockW + blockW / 2 + bond
				x = center.X + (if facing == "W" then -depth / 2 - 0.5 else depth / 2 + 0.5)
			end
			p.CFrame = CFrame.new(x, y, z)
			p.Parent = folder
		end
	end
	return folder
end

local function tower(parent: Instance, pos: Vector3, height: number, size: number, name: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	-- Stacked cylindrical-ish blocks (square for performance)
	local tiers = math.max(3, math.floor(height / 10))
	for i = 0, tiers - 1 do
		local s = size - (i * 0.15)
		part(folder,
			Vector3.new(s, 10, s),
			CFrame.new(pos + Vector3.new(0, 5 + i * 10, 0)),
			shade(STONE_DARK, noise(i, 2)),
			Enum.Material.Slate,
			"Tier_" .. i
		)
	end

	-- Battlements (crenellations)
	local topY = tiers * 10
	local crenelCount = 4
	for i = 0, crenelCount - 1 do
		local a = (i / crenelCount) * math.pi * 2
		local r = size * 0.45
		part(folder,
			Vector3.new(2.5, 4, 2.5),
			CFrame.new(pos + Vector3.new(math.cos(a) * r, topY + 2, math.sin(a) * r)),
			STONE_LIGHT,
			Enum.Material.Rock,
			"Crenel_" .. i
		)
	end

	-- Roof cone approximation
	part(folder,
		Vector3.new(size * 0.9, 3, size * 0.9),
		CFrame.new(pos + Vector3.new(0, topY + 5, 0)),
		ROOF,
		Enum.Material.WoodPlanks,
		"TowerRoof"
	)
	part(folder,
		Vector3.new(size * 0.55, 3, size * 0.55),
		CFrame.new(pos + Vector3.new(0, topY + 7.5, 0)),
		shade(ROOF, -0.05),
		Enum.Material.WoodPlanks,
		"TowerRoof2"
	)

	-- Window slits
	for _, yOff in { 12, 24, 36 } do
		if yOff < height - 5 then
			local win = part(folder,
				Vector3.new(2.5, 3.5, 0.4),
				CFrame.new(pos + Vector3.new(0, yOff, -size / 2 - 0.1)),
				Color3.fromRGB(30, 50, 70),
				Enum.Material.Glass,
				"Window"
			)
			win.Transparency = 0.35
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 200, 120)
			light.Brightness = 0.6
			light.Range = 18
			light.Parent = win
		end
	end

	return folder
end

local function banner(parent: Instance, pos: Vector3, facingZ: number)
	local pole = part(parent, Vector3.new(0.5, 14, 0.5), CFrame.new(pos + Vector3.new(0, 7, 0)), WOOD, Enum.Material.Wood, "BannerPole")
	local cloth = part(parent, Vector3.new(5, 8, 0.3), CFrame.new(pos + Vector3.new(2.5, 8, facingZ * 0.2)), BANNER, Enum.Material.Fabric, "BannerCloth")
	-- gold trim
	part(parent, Vector3.new(5.2, 0.4, 0.35), CFrame.new(pos + Vector3.new(2.5, 12.2, facingZ * 0.2)), GOLD, Enum.Material.Metal, "BannerTrim")
	part(parent, Vector3.new(5.2, 0.4, 0.35), CFrame.new(pos + Vector3.new(2.5, 4, facingZ * 0.2)), GOLD, Enum.Material.Metal, "BannerTrim2")
	return cloth
end

local function windowRow(parent: Instance, center: Vector3, count: number, spacing: number, y: number, zFace: number)
	for i = 0, count - 1 do
		local x = center.X - ((count - 1) * spacing) / 2 + i * spacing
		local frame = part(parent, Vector3.new(3.2, 4.5, 0.6), CFrame.new(x, y, zFace), STONE_DARK, Enum.Material.Rock, "WindowFrame")
		local glass = part(parent, Vector3.new(2.4, 3.6, 0.3), CFrame.new(x, y, zFace - 0.2), Color3.fromRGB(40, 70, 95), Enum.Material.Glass, "Glass")
		glass.Transparency = 0.4
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 140)
		light.Brightness = 0.5
		light.Range = 14
		light.Parent = glass
	end
end

function CastleBuilder.Build(parent: Instance, origin: Vector3?)
	origin = origin or Vector3.new(0, 0, -180)

	local castle = Instance.new("Folder")
	castle.Name = "RoyalCastle"
	castle.Parent = parent

	local bodyW, bodyH, bodyD = 90, 50, 70
	local center = origin + Vector3.new(0, bodyH / 2, 0)

	-- Core solid (interior fill / collision)
	part(castle, Vector3.new(bodyW - 4, bodyH - 2, bodyD - 4),
		CFrame.new(center),
		STONE_DARK, Enum.Material.Slate, "KeepCore")

	-- Four facades of stone blocks
	blockFacade(castle, center, bodyW, bodyH, bodyD, "N")
	blockFacade(castle, center, bodyW, bodyH, bodyD, "S")
	blockFacade(castle, Vector3.new(center.X, center.Y, center.Z), bodyD, bodyH, bodyW, "E")
	blockFacade(castle, Vector3.new(center.X, center.Y, center.Z), bodyD, bodyH, bodyW, "W")

	-- Main roof (layered for texture)
	part(castle, Vector3.new(bodyW + 6, 3, bodyD + 6),
		CFrame.new(origin + Vector3.new(0, bodyH + 1, 0)),
		ROOF, Enum.Material.WoodPlanks, "RoofBase")
	part(castle, Vector3.new(bodyW * 0.7, 3, bodyD * 0.7),
		CFrame.new(origin + Vector3.new(0, bodyH + 4, 0)),
		shade(ROOF, -0.04), Enum.Material.WoodPlanks, "RoofMid")
	part(castle, Vector3.new(bodyW * 0.4, 2.5, bodyD * 0.4),
		CFrame.new(origin + Vector3.new(0, bodyH + 6.5, 0)),
		shade(ROOF, -0.08), Enum.Material.WoodPlanks, "RoofTop")

	-- Battlement row on front (south-facing toward plaza)
	for i = -4, 4 do
		if i ~= 0 then
			part(castle, Vector3.new(5, 5, 3),
				CFrame.new(origin + Vector3.new(i * 9, bodyH + 2.5, bodyD / 2 + 1)),
				STONE_LIGHT, Enum.Material.Rock, "Battlement")
		end
	end

	-- Corner towers
	tower(castle, origin + Vector3.new(-bodyW / 2 - 2, 0, -bodyD / 2 - 2), 55, 16, "Tower_NW")
	tower(castle, origin + Vector3.new(bodyW / 2 + 2, 0, -bodyD / 2 - 2), 55, 16, "Tower_NE")
	tower(castle, origin + Vector3.new(-bodyW / 2 - 2, 0, bodyD / 2 + 2), 48, 14, "Tower_SW")
	tower(castle, origin + Vector3.new(bodyW / 2 + 2, 0, bodyD / 2 + 2), 48, 14, "Tower_SE")

	-- Grand entrance
	local arch = part(castle, Vector3.new(16, 22, 4),
		CFrame.new(origin + Vector3.new(0, 11, bodyD / 2 + 2)),
		STONE, Enum.Material.Limestone, "EntranceArch")
	local door = part(castle, Vector3.new(12, 16, 1.5),
		CFrame.new(origin + Vector3.new(0, 8, bodyD / 2 + 3.2)),
		WOOD, Enum.Material.Wood, "GrandDoor")
	-- Door iron bands
	for _, yOff in { 4, 8, 12 } do
		part(castle, Vector3.new(12.5, 0.6, 1.7),
			CFrame.new(origin + Vector3.new(0, yOff, bodyD / 2 + 3.2)),
			Color3.fromRGB(50, 50, 55), Enum.Material.Metal, "DoorBand")
	end
	-- Steps
	for i = 1, 5 do
		part(castle, Vector3.new(18 + i * 2, 1, 3),
			CFrame.new(origin + Vector3.new(0, i * 0.9 - 0.5, bodyD / 2 + 4 + i * 2.5)),
			STONE_LIGHT, Enum.Material.Limestone, "Step_" .. i)
	end

	-- Windows on south facade
	windowRow(castle, origin + Vector3.new(0, 28, 0), 5, 12, 28, origin.Z + bodyD / 2 + 1.2)
	windowRow(castle, origin + Vector3.new(0, 38, 0), 4, 14, 38, origin.Z + bodyD / 2 + 1.2)

	-- Banners at entrance
	banner(castle, origin + Vector3.new(-10, 0, bodyD / 2 + 5), 1)
	banner(castle, origin + Vector3.new(10, 0, bodyD / 2 + 5), 1)

	-- Interior / courtyard floors
	SurfaceTextures.TiledFloor(
		castle,
		origin + Vector3.new(0, 1, bodyD / 2 + 18),
		40, 24,
		5,
		Color3.fromRGB(120, 112, 100),
		Enum.Material.Cobblestone,
		1.2
	)
	-- Throne hall floor (marble-like tiles)
	SurfaceTextures.TiledFloor(
		castle,
		origin + Vector3.new(0, 1, 0),
		50, 40,
		6,
		Color3.fromRGB(145, 140, 130),
		Enum.Material.Marble,
		1.25
	)
	-- Side corridor floors
	SurfaceTextures.TiledFloor(
		castle,
		origin + Vector3.new(-30, 1, 0),
		16, 50,
		5,
		Color3.fromRGB(100, 95, 88),
		Enum.Material.Slate,
		1.2
	)
	SurfaceTextures.TiledFloor(
		castle,
		origin + Vector3.new(30, 1, 0),
		16, 50,
		5,
		Color3.fromRGB(100, 95, 88),
		Enum.Material.Slate,
		1.2
	)

	-- Inner keep columns
	for _, x in { -18, 18 } do
		for _, z in { -15, 0, 15 } do
			part(castle, Vector3.new(3, 28, 3),
				CFrame.new(origin + Vector3.new(x, 14, z)),
				STONE_LIGHT, Enum.Material.Marble, "Column")
			part(castle, Vector3.new(4, 1.5, 4),
				CFrame.new(origin + Vector3.new(x, 28.5, z)),
				GOLD, Enum.Material.Metal, "ColumnCap")
		end
	end

	-- Throne dais
	part(castle, Vector3.new(14, 2, 10),
		CFrame.new(origin + Vector3.new(0, 2, -22)),
		STONE_LIGHT, Enum.Material.Marble, "Dais")
	part(castle, Vector3.new(6, 8, 4),
		CFrame.new(origin + Vector3.new(0, 7, -24)),
		Color3.fromRGB(70, 40, 90), Enum.Material.Fabric, "Throne")
	part(castle, Vector3.new(7, 1, 1.5),
		CFrame.new(origin + Vector3.new(0, 11.5, -24)),
		GOLD, Enum.Material.Metal, "ThroneCrest")

	-- Label
	local labelPart = part(castle, Vector3.new(4, 4, 4),
		CFrame.new(origin + Vector3.new(0, bodyH + 12, 0)),
		GOLD, Enum.Material.Neon, "CastleLabelAnchor")
	labelPart.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 260, 0, 50)
	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.AlwaysOnTop = true
	bb.Parent = labelPart
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.Text = "Royal Castle of Aurenholm"
	t.TextColor3 = Color3.fromRGB(230, 200, 140)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextStrokeTransparency = 0.4
	t.Parent = bb

	print("[CastleBuilder] Royal Castle textured build complete")
	return castle
end

return CastleBuilder
