--!strict
--[[
	Consistent material + color language for REALMS OF ETERNITY.
	Uses built-in Roblox materials (no external texture IDs required).
]]

local MaterialPalette = {}

MaterialPalette.Regions = {
	Aurenholm = {
		Ground = { Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(92, 84, 72) },
		Plaza = { Material = Enum.Material.Limestone, Color = Color3.fromRGB(140, 130, 115) },
		Wall = { Material = Enum.Material.Slate, Color = Color3.fromRGB(78, 82, 88) },
		Roof = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(72, 42, 36) },
		Brick = { Material = Enum.Material.Brick, Color = Color3.fromRGB(118, 98, 82) },
		Marble = { Material = Enum.Material.Marble, Color = Color3.fromRGB(175, 168, 155) },
		Wood = { Material = Enum.Material.Wood, Color = Color3.fromRGB(62, 44, 30) },
		Metal = { Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 115, 125) },
		NeonAccent = { Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 170, 90) },
	},
	Eldoria = {
		Ground = { Material = Enum.Material.Grass, Color = Color3.fromRGB(42, 78, 48) },
		Moss = { Material = Enum.Material.LeafyGrass, Color = Color3.fromRGB(48, 95, 55) },
		Path = { Material = Enum.Material.Ground, Color = Color3.fromRGB(70, 58, 42) },
		Trunk = { Material = Enum.Material.Wood, Color = Color3.fromRGB(58, 42, 28) },
		Canopy = { Material = Enum.Material.Grass, Color = Color3.fromRGB(28, 88, 42) },
		AncientCanopy = { Material = Enum.Material.LeafyGrass, Color = Color3.fromRGB(36, 110, 55) },
		StoneRuin = { Material = Enum.Material.Rock, Color = Color3.fromRGB(88, 90, 78) },
		Temple = { Material = Enum.Material.Slate, Color = Color3.fromRGB(62, 72, 58) },
		GlowPlant = { Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 220, 140) },
		Mist = { Material = Enum.Material.ForceField, Color = Color3.fromRGB(170, 200, 175) },
	},
	Boss = {
		Bark = { Material = Enum.Material.Wood, Color = Color3.fromRGB(48, 58, 36) },
		Stone = { Material = Enum.Material.Rock, Color = Color3.fromRGB(95, 95, 88) },
		Eye = { Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 255, 90) },
		Aura = { Material = Enum.Material.ForceField, Color = Color3.fromRGB(90, 200, 80) },
		Root = { Material = Enum.Material.Wood, Color = Color3.fromRGB(40, 32, 22) },
	},
}

MaterialPalette.Rarity = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(80, 190, 90),
	Rare = Color3.fromRGB(70, 130, 230),
	Epic = Color3.fromRGB(170, 80, 210),
	Legendary = Color3.fromRGB(230, 170, 50),
	Mythic = Color3.fromRGB(230, 70, 70),
}

MaterialPalette.VFX = {
	Arcane = Color3.fromRGB(120, 160, 255),
	Fire = Color3.fromRGB(255, 120, 40),
	Nature = Color3.fromRGB(90, 200, 100),
	Shadow = Color3.fromRGB(60, 30, 90),
	Holy = Color3.fromRGB(255, 230, 150),
	Blood = Color3.fromRGB(180, 40, 40),
	Ice = Color3.fromRGB(150, 210, 255),
	Poison = Color3.fromRGB(140, 220, 60),
}

function MaterialPalette.Apply(part: BasePart, style: { Material: Enum.Material, Color: Color3 })
	part.Material = style.Material
	part.Color = style.Color
end

return MaterialPalette
