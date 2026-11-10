--!strict
--[[
	Procedural surface texturing for floors and walls.
	Uses tiled geometry + material variation (no external texture asset IDs).
	In Studio you can later replace tiles with MeshParts + SurfaceAppearance.
]]

local SurfaceTextures = {}

local function shade(c: Color3, delta: number): Color3
	return Color3.new(
		math.clamp(c.R + delta, 0, 1),
		math.clamp(c.G + delta, 0, 1),
		math.clamp(c.B + delta, 0, 1)
	)
end

local function noise(i: number, j: number): number
	-- deterministic pseudo-noise in [-0.06, 0.06]
	local n = math.sin(i * 12.9898 + j * 78.233) * 43758.5453
	n = n - math.floor(n)
	return (n - 0.5) * 0.12
end

----------------------------------------------------------------
-- FLOORS
----------------------------------------------------------------

--- Cobblestone / stone tile floor centered at `center` covering `width` x `depth`
function SurfaceTextures.TiledFloor(
	parent: Instance,
	center: Vector3,
	width: number,
	depth: number,
	tileSize: number?,
	baseColor: Color3?,
	material: Enum.Material?,
	y: number?
)
	tileSize = tileSize or 8
	baseColor = baseColor or Color3.fromRGB(120, 110, 95)
	material = material or Enum.Material.Cobblestone
	y = y or (center.Y + 0.15)

	local folder = Instance.new("Folder")
	folder.Name = "FloorTiles"
	folder.Parent = parent

	local nx = math.max(1, math.floor(width / tileSize))
	local nz = math.max(1, math.floor(depth / tileSize))
	local originX = center.X - (nx * tileSize) / 2 + tileSize / 2
	local originZ = center.Z - (nz * tileSize) / 2 + tileSize / 2

	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local gap = 0.15
			local part = Instance.new("Part")
			part.Name = string.format("Tile_%d_%d", i, j)
			part.Size = Vector3.new(tileSize - gap, 0.35, tileSize - gap)
			part.Anchored = true
			part.Material = material
			part.Color = shade(baseColor, noise(i, j))
			-- slight height variation for cobble feel
			local yOff = noise(j, i) * 0.4
			part.CFrame = CFrame.new(originX + i * tileSize, y + yOff, originZ + j * tileSize)
			part.TopSurface = Enum.SurfaceType.Smooth
			part.Parent = folder
		end
	end

	-- grout / underlayer
	local under = Instance.new("Part")
	under.Name = "FloorGrout"
	under.Size = Vector3.new(nx * tileSize + 1, 0.2, nz * tileSize + 1)
	under.Anchored = true
	under.Material = Enum.Material.Slate
	under.Color = shade(baseColor, -0.12)
	under.CFrame = CFrame.new(center.X, y - 0.15, center.Z)
	under.Parent = folder

	return folder
end

--- Wood plank floor
function SurfaceTextures.WoodFloor(
	parent: Instance,
	center: Vector3,
	width: number,
	depth: number,
	plankWidth: number?,
	y: number?
)
	plankWidth = plankWidth or 3
	y = y or (center.Y + 0.2)
	local folder = Instance.new("Folder")
	folder.Name = "WoodFloor"
	folder.Parent = parent

	local n = math.max(1, math.floor(width / plankWidth))
	local originX = center.X - (n * plankWidth) / 2 + plankWidth / 2
	local base = Color3.fromRGB(95, 70, 45)

	for i = 0, n - 1 do
		local part = Instance.new("Part")
		part.Name = "Plank_" .. i
		part.Size = Vector3.new(plankWidth - 0.12, 0.3, depth)
		part.Anchored = true
		part.Material = Enum.Material.WoodPlanks
		part.Color = shade(base, noise(i, 0) * 1.2)
		part.CFrame = CFrame.new(originX + i * plankWidth, y, center.Z)
		part.Parent = folder
	end
	return folder
end

--- Dirt / forest path with patch variation
function SurfaceTextures.DirtPath(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	width: number
)
	local folder = Instance.new("Folder")
	folder.Name = "DirtPath"
	folder.Parent = parent

	local dir = (to - from) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1 then return folder end
	local dist = dir.Magnitude
	local steps = math.max(2, math.floor(dist / 6))
	local base = Color3.fromRGB(72, 58, 40)

	for s = 0, steps do
		local t = s / steps
		local pos = from:Lerp(to, t)
		local part = Instance.new("Part")
		part.Name = "PathSeg_" .. s
		part.Size = Vector3.new(width * (0.85 + noise(s, 1) * 0.5), 0.35, 7)
		part.Anchored = true
		part.Material = Enum.Material.Ground
		part.Color = shade(base, noise(s, 2))
		part.CFrame = CFrame.new(pos.X, math.min(from.Y, to.Y) + 0.2, pos.Z)
			* CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
		part.Parent = folder
	end
	return folder
end

----------------------------------------------------------------
-- WALLS
----------------------------------------------------------------

--- Stone block wall along a span (horizontal wall facing Z or X)
function SurfaceTextures.BlockWall(
	parent: Instance,
	center: Vector3,
	length: number,
	height: number,
	thickness: number,
	axis: "X" | "Z",
	baseColor: Color3?,
	material: Enum.Material?
)
	baseColor = baseColor or Color3.fromRGB(88, 90, 96)
	material = material or Enum.Material.Slate

	local folder = Instance.new("Folder")
	folder.Name = "BlockWall"
	folder.Parent = parent

	local blockW, blockH = 10, 8
	local cols = math.max(1, math.floor(length / blockW))
	local rows = math.max(1, math.floor(height / blockH))

	for row = 0, rows - 1 do
		local offset = (row % 2 == 0) and 0 or (blockW * 0.5) -- brick bond
		for col = 0, cols - 1 do
			local w = blockW - 0.25
			-- edge blocks may be shorter
			if col == cols - 1 and offset > 0 then
				w = blockW * 0.5 - 0.25
			end
			local part = Instance.new("Part")
			part.Name = string.format("Block_%d_%d", row, col)
			part.Size = if axis == "X"
				then Vector3.new(w, blockH - 0.2, thickness)
				else Vector3.new(thickness, blockH - 0.2, w)
			part.Anchored = true
			part.Material = material
			part.Color = shade(baseColor, noise(row, col))
			local x = center.X
			local z = center.Z
			if axis == "X" then
				x = center.X - length / 2 + col * blockW + blockW / 2 + offset
			else
				z = center.Z - length / 2 + col * blockW + blockW / 2 + offset
			end
			local y = center.Y - height / 2 + row * blockH + blockH / 2
			part.CFrame = CFrame.new(x, y, z)
			part.Parent = folder
		end
	end

	-- top cap / battlement line
	local cap = Instance.new("Part")
	cap.Name = "WallCap"
	cap.Size = if axis == "X"
		then Vector3.new(length + 2, 1.5, thickness + 1.5)
		else Vector3.new(thickness + 1.5, 1.5, length + 2)
	cap.Anchored = true
	cap.Material = Enum.Material.Rock
	cap.Color = shade(baseColor, 0.05)
	cap.CFrame = CFrame.new(center.X, center.Y + height / 2 + 0.5, center.Z)
	cap.Parent = folder

	return folder
end

--- Interior plaster wall with baseboard and wood trim
function SurfaceTextures.InteriorWall(
	parent: Instance,
	center: Vector3,
	length: number,
	height: number,
	thickness: number,
	axis: "X" | "Z"
)
	local folder = Instance.new("Folder")
	folder.Name = "InteriorWall"
	folder.Parent = parent

	local main = Instance.new("Part")
	main.Name = "Plaster"
	main.Size = if axis == "X"
		then Vector3.new(length, height, thickness)
		else Vector3.new(thickness, height, length)
	main.Anchored = true
	main.Material = Enum.Material.SmoothPlastic
	main.Color = Color3.fromRGB(155, 148, 135)
	main.CFrame = CFrame.new(center)
	main.Parent = folder

	-- baseboard
	local board = Instance.new("Part")
	board.Name = "Baseboard"
	board.Size = if axis == "X"
		then Vector3.new(length, 1.2, thickness + 0.3)
		else Vector3.new(thickness + 0.3, 1.2, length)
	board.Anchored = true
	board.Material = Enum.Material.Wood
	board.Color = Color3.fromRGB(70, 50, 35)
	board.CFrame = CFrame.new(center.X, center.Y - height / 2 + 0.6, center.Z)
	board.Parent = folder

	-- top trim
	local trim = board:Clone()
	trim.Name = "TopTrim"
	trim.CFrame = CFrame.new(center.X, center.Y + height / 2 - 0.5, center.Z)
	trim.Parent = folder

	return folder
end

--- Apply a simple repeating Texture instance using material-like look via SurfaceGui grid (lightweight)
--- For true PBR, replace in Studio with SurfaceAppearance.
function SurfaceTextures.ApplyDetailDecals(part: BasePart, kind: "stone" | "wood" | "dirt")
	-- Subtle color noise already done on tiles; add edge highlight part for readability
	local edge = Instance.new("Part")
	edge.Name = "EdgeHighlight"
	edge.Size = part.Size + Vector3.new(0.05, 0.02, 0.05)
	edge.CFrame = part.CFrame
	edge.Anchored = true
	edge.CanCollide = false
	edge.Transparency = 0.92
	edge.Material = Enum.Material.Neon
	if kind == "stone" then
		edge.Color = Color3.fromRGB(180, 180, 190)
	elseif kind == "wood" then
		edge.Color = Color3.fromRGB(160, 120, 70)
	else
		edge.Color = Color3.fromRGB(100, 80, 50)
	end
	edge.Parent = part.Parent
end

return SurfaceTextures
