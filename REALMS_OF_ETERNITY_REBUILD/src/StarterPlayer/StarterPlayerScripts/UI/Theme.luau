--!strict
--[[
	Theme — the visual language of REALMS OF ETERNITY's interface.
	Dark stone, aged silver, muted gold, deep green, thin rune lines. No default Roblox greys.
]]

local Theme = {}

Theme.Colors = {
	Stone900 = Color3.fromRGB(14, 15, 17),
	Stone800 = Color3.fromRGB(22, 23, 26),
	Stone700 = Color3.fromRGB(31, 32, 36),
	Stone600 = Color3.fromRGB(44, 45, 50),
	Stone500 = Color3.fromRGB(62, 63, 69),
	Silver = Color3.fromRGB(168, 170, 172),
	SilverDim = Color3.fromRGB(104, 106, 110),
	SilverBright = Color3.fromRGB(214, 214, 210),
	Gold = Color3.fromRGB(201, 168, 106),
	GoldBright = Color3.fromRGB(236, 205, 140),
	GoldDim = Color3.fromRGB(128, 104, 64),
	Green = Color3.fromRGB(70, 128, 96),
	GreenDeep = Color3.fromRGB(28, 58, 46),
	GreenBright = Color3.fromRGB(122, 196, 150),
	Text = Color3.fromRGB(226, 220, 206),
	TextDim = Color3.fromRGB(156, 150, 138),
	TextMuted = Color3.fromRGB(110, 106, 98),
	Danger = Color3.fromRGB(196, 72, 64),
	DangerBright = Color3.fromRGB(236, 104, 92),
	Health = Color3.fromRGB(176, 46, 46),
	HealthBright = Color3.fromRGB(222, 84, 72),
	Stamina = Color3.fromRGB(196, 170, 96),
	Shield = Color3.fromRGB(196, 214, 236),
	Xp = Color3.fromRGB(150, 118, 210),
	Mana = Color3.fromRGB(80, 128, 236),
	Overlay = Color3.fromRGB(6, 7, 8),
}

Theme.Fonts = {
	-- Logo only (Latin glyphs): GrenzeGotisch has no Cyrillic, so Russian text never uses it.
	Logo = Font.new("rbxasset://fonts/families/GrenzeGotisch.json", Enum.FontWeight.Bold),
	Title = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy),
	Heading = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular),
	BodyBold = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	Ui = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium),
	UiBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
	Numbers = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
}

Theme.TextSize = {
	Hero = 64,
	Title = 34,
	Heading = 24,
	Body = 17,
	Small = 14,
	Tiny = 12,
}

Theme.Corner = UDim.new(0, 4)
Theme.CornerLarge = UDim.new(0, 8)

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Open = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
}

-- Rarity colours mirror Config/Items.Rarities (kept here for UI-only lookups).
Theme.Rarity = {
	Common = Color3.fromRGB(200, 200, 196),
	Uncommon = Color3.fromRGB(110, 200, 110),
	Rare = Color3.fromRGB(90, 150, 240),
	Epic = Color3.fromRGB(176, 104, 240),
	Legendary = Color3.fromRGB(245, 168, 60),
	Mythic = Color3.fromRGB(240, 80, 90),
}

Theme.DamageColors = {
	Physical = Color3.fromRGB(240, 232, 214),
	Fire = Color3.fromRGB(255, 140, 60),
	Frost = Color3.fromRGB(150, 210, 255),
	Nature = Color3.fromRGB(140, 220, 100),
	Shadow = Color3.fromRGB(176, 120, 230),
	Arcane = Color3.fromRGB(150, 150, 255),
	Holy = Color3.fromRGB(255, 226, 140),
	True = Color3.fromRGB(255, 255, 255),
	Heal = Color3.fromRGB(120, 230, 120),
}

return Theme
