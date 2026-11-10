--!strict
--[[
	Statuses — every buff/debuff in the game. CombatService applies the Effects generically;
	special behaviour is keyed by Id where noted. Icon is a short glyph rendered by the HUD.
]]

export type StatusDef = {
	Id: string,
	Name: string,
	Kind: "Buff" | "Debuff",
	Icon: string,
	Color: Color3,
	MaxStacks: number,
	Tick: number?, -- seconds between periodic effects
	DamageType: string?, -- for DoTs: Magnitude = damage per tick (per stack)
	HealPerTick: boolean?, -- for HoTs: Magnitude = heal per tick
	Effects: {
		MoveSpeedMult: number?, -- multiplied (Magnitude overrides when status has Magnitude and UseMagnitude="MoveSpeed")
		DamageTakenMult: number?,
		DamageDealtMult: number?,
		HealingTakenMult: number?,
		PreventsActions: boolean?,
		PreventsMovement: boolean?,
		Invulnerable: boolean?,
		Untargetable: boolean?,
		SuperArmor: boolean?,
	},
	UseMagnitude: ("MoveSpeed" | "DamageTaken" | "DamageDealt")?, -- Magnitude replaces that effect value
	Dispellable: boolean?,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Statuses: { [string]: StatusDef } = {
	Stun = { Id = "Stun", Name = "Оглушение", Kind = "Debuff", Icon = "✦", Color = c(240, 210, 90), MaxStacks = 1, Effects = { PreventsActions = true, PreventsMovement = true } },
	Stagger = { Id = "Stagger", Name = "Пошатнулся", Kind = "Debuff", Icon = "≋", Color = c(230, 170, 80), MaxStacks = 1, Effects = { PreventsActions = true, PreventsMovement = true, DamageTakenMult = 1.15 } },
	Knockdown = { Id = "Knockdown", Name = "Сбит с ног", Kind = "Debuff", Icon = "⤓", Color = c(220, 140, 70), MaxStacks = 1, Effects = { PreventsActions = true, PreventsMovement = true } },
	Root = { Id = "Root", Name = "Опутан корнями", Kind = "Debuff", Icon = "❦", Color = c(110, 170, 80), MaxStacks = 1, Effects = { PreventsMovement = true }, Dispellable = true },
	Slow = { Id = "Slow", Name = "Замедление", Kind = "Debuff", Icon = "◔", Color = c(140, 170, 220), MaxStacks = 1, Effects = { MoveSpeedMult = 0.6 }, UseMagnitude = "MoveSpeed", Dispellable = true },
	Chill = { Id = "Chill", Name = "Озноб", Kind = "Debuff", Icon = "❄", Color = c(150, 210, 255), MaxStacks = 3, Effects = { MoveSpeedMult = 0.8 }, Dispellable = true },
	Burn = { Id = "Burn", Name = "Горение", Kind = "Debuff", Icon = "♨", Color = c(255, 130, 50), MaxStacks = 3, Tick = 1, DamageType = "Fire", Effects = {}, Dispellable = true },
	Venom = { Id = "Venom", Name = "Яд", Kind = "Debuff", Icon = "☣", Color = c(140, 220, 90), MaxStacks = 5, Tick = 1, DamageType = "Nature", Effects = { HealingTakenMult = 0.7 }, Dispellable = true },
	Bleed = { Id = "Bleed", Name = "Кровотечение", Kind = "Debuff", Icon = "♦", Color = c(200, 40, 50), MaxStacks = 5, Tick = 1, DamageType = "Physical", Effects = {} },
	Marked = { Id = "Marked", Name = "Метка охотника", Kind = "Debuff", Icon = "◎", Color = c(255, 200, 80), MaxStacks = 1, Effects = { DamageTakenMult = 1.15 }, UseMagnitude = "DamageTaken" },
	Vulnerable = { Id = "Vulnerable", Name = "Уязвимость", Kind = "Debuff", Icon = "⚠", Color = c(255, 90, 90), MaxStacks = 1, Effects = { DamageTakenMult = 1.25 }, UseMagnitude = "DamageTaken" },
	Weakened = { Id = "Weakened", Name = "Ослабление", Kind = "Debuff", Icon = "↓", Color = c(170, 120, 200), MaxStacks = 1, Effects = { DamageDealtMult = 0.75 }, UseMagnitude = "DamageDealt", Dispellable = true },
	Silence = { Id = "Silence", Name = "Безмолвие", Kind = "Debuff", Icon = "∅", Color = c(150, 150, 190), MaxStacks = 1, Effects = {} },
	Guarded = { Id = "Guarded", Name = "Железная стойка", Kind = "Buff", Icon = "⛨", Color = c(200, 200, 210), MaxStacks = 1, Effects = { DamageTakenMult = 0.6, SuperArmor = true }, UseMagnitude = "DamageTaken" },
	Empowered = { Id = "Empowered", Name = "Усиление", Kind = "Buff", Icon = "▲", Color = c(255, 190, 90), MaxStacks = 1, Effects = { DamageDealtMult = 1.2 }, UseMagnitude = "DamageDealt" },
	Haste = { Id = "Haste", Name = "Ускорение", Kind = "Buff", Icon = "»", Color = c(140, 230, 200), MaxStacks = 1, Effects = { MoveSpeedMult = 1.3 }, UseMagnitude = "MoveSpeed" },
	Regeneration = { Id = "Regeneration", Name = "Восстановление", Kind = "Buff", Icon = "✚", Color = c(120, 230, 120), MaxStacks = 1, Tick = 1, HealPerTick = true, Effects = {} },
	Stealth = { Id = "Stealth", Name = "Скрытность", Kind = "Buff", Icon = "◐", Color = c(120, 110, 170), MaxStacks = 1, Effects = { Untargetable = true, MoveSpeedMult = 1.1 } },
	Invulnerable = { Id = "Invulnerable", Name = "Неуязвимость", Kind = "Buff", Icon = "✧", Color = c(255, 240, 180), MaxStacks = 1, Effects = { Invulnerable = true } },
	SuperArmor = { Id = "SuperArmor", Name = "Непоколебимость", Kind = "Buff", Icon = "◆", Color = c(210, 190, 140), MaxStacks = 1, Effects = { SuperArmor = true } },
	Warded = { Id = "Warded", Name = "Руническая защита", Kind = "Buff", Icon = "ᛟ", Color = c(150, 140, 255), MaxStacks = 1, Effects = { DamageTakenMult = 0.85 } },
	Rallied = { Id = "Rallied", Name = "Боевой клич", Kind = "Buff", Icon = "⚑", Color = c(230, 200, 120), MaxStacks = 1, Effects = { DamageDealtMult = 1.1, MoveSpeedMult = 1.1 } },
	Exposed = { Id = "Exposed", Name = "Обнажённое ядро", Kind = "Debuff", Icon = "✸", Color = c(255, 220, 120), MaxStacks = 1, Effects = { DamageTakenMult = 1.5 }, UseMagnitude = "DamageTaken" },
	Weakness = { Id = "Weakness", Name = "Слабость после смерти", Kind = "Debuff", Icon = "☠", Color = c(160, 160, 170), MaxStacks = 1, Effects = { DamageDealtMult = 0.9 } },
}

return {
	Statuses = Statuses,
	Get = function(id: string): StatusDef?
		return Statuses[id]
	end,
}
