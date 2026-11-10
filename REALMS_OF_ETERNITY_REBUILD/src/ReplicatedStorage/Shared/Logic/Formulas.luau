--!strict
--[[
	Formulas — all combat & progression math in one pure module (unit-tested under Lune).

	ComputeStats(input) builds the final Stats table from:
	  class base + per-level growth + race attribute mods + equipped item stats
	  + set bonuses (2/4 pieces) + passive/spec/talent stat modifiers.
	Order: additive attributes → derived (power, health from vitality) → Add mods → Mul mods.
]]

local Types = require(script.Parent.Parent.Core.Types)

type Stats = Types.Stats

local Formulas = {}

Formulas.MaxLevel = 60
Formulas.LevelCap = 8 -- vertical-slice cap; raise as regions ship

local STAT_KEYS = {
	"MaxHealth",
	"MaxResource",
	"MaxStamina",
	"Strength",
	"Dexterity",
	"Intelligence",
	"Vitality",
	"AttackPower",
	"SpellPower",
	"Armor",
	"Resistance",
	"CritChance",
	"CritDamage",
	"MoveSpeed",
	"HealthRegen",
	"ResourceRegen",
	"StaminaRegen",
	"Haste",
	"Recovery",
}
Formulas.StatKeys = STAT_KEYS

local function zeroStats(): { [string]: number }
	local stats: { [string]: number } = {}
	for _, key in STAT_KEYS do
		stats[key] = 0
	end
	return stats
end

export type StatInput = {
	Class: any, -- Classes.ClassDef
	Race: any?, -- Races.RaceDef
	Level: number,
	ItemStats: { { [string]: number } }, -- stats of each equipped item
	Modifiers: { any }, -- Classes.Modifier list (only Stat mods are used here)
}

function Formulas.ComputeStats(input: StatInput): Stats
	local class = input.Class
	local stats = zeroStats()
	local levelSteps = math.max(0, input.Level - 1)

	for key, value in class.BaseStats do
		stats[key] = (stats[key] or 0) + value
	end
	for key, value in class.PerLevel do
		stats[key] = (stats[key] or 0) + value * levelSteps
	end
	if input.Race then
		for key, value in input.Race.StatMods do
			stats[key] = (stats[key] or 0) + value
		end
	end

	-- Item stats: attributes first, flat power/defence later (so they are not rescaled).
	local itemFlat = zeroStats()
	for _, itemStats in input.ItemStats do
		for key, value in itemStats do
			if key == "Strength" or key == "Dexterity" or key == "Intelligence" or key == "Vitality" then
				stats[key] += value
			else
				itemFlat[key] = (itemFlat[key] or 0) + value
			end
		end
	end

	-- Derived values from attributes.
	local function scaled(map: { [string]: number }): number
		local total = 0
		for attribute, factor in map do
			total += (stats[attribute] or 0) * factor
		end
		return total
	end
	stats.AttackPower += 6 + scaled(class.PowerScaling.Attack)
	stats.SpellPower += 6 + scaled(class.PowerScaling.Spell)
	stats.MaxHealth += stats.Vitality * 6
	stats.HealthRegen += stats.Vitality * 0.05
	stats.CritChance += stats.Dexterity * 0.0015

	for key, value in itemFlat do
		stats[key] += value
	end

	-- Modifiers: all Adds, then all Muls (commutative within each group).
	for _, mod in input.Modifiers do
		if mod.Stat and (mod.Op == "Add" or mod.Op == nil) then
			stats[mod.Stat] = (stats[mod.Stat] or 0) + mod.Value
		end
	end
	for _, mod in input.Modifiers do
		if mod.Stat and mod.Op == "Mul" then
			stats[mod.Stat] = (stats[mod.Stat] or 0) * mod.Value
		end
	end

	stats.CritChance = math.clamp(stats.CritChance, 0, 0.75)
	stats.Haste = math.clamp(stats.Haste, 0, 0.5)
	stats.MoveSpeed = math.clamp(stats.MoveSpeed, 8, 28)
	stats.CritDamage = math.max(1, stats.CritDamage)
	stats.Recovery = math.max(0.1, if stats.Recovery == 0 then 1 else stats.Recovery)
	stats.MaxHealth = math.max(1, math.floor(stats.MaxHealth + 0.5))
	stats.MaxResource = math.max(1, math.floor(stats.MaxResource + 0.5))
	stats.MaxStamina = math.max(1, math.floor(stats.MaxStamina + 0.5))
	return (stats :: any) :: Stats
end

-- Fraction of damage that gets through armour/resistance. Level-relative so that
-- mitigation does not trivialise low-level content.
function Formulas.Mitigation(defense: number, attackerLevel: number): number
	local k = 60 + 18 * math.max(1, attackerLevel)
	local reduction = defense / (defense + k)
	return 1 - math.clamp(reduction, 0, 0.75)
end

export type RollResult = { Amount: number, IsCrit: boolean }

-- Raw outgoing damage before target mitigation.
function Formulas.RollDamage(stats: Stats, spec: Types.DamageSpec, multiplier: number, rng: () -> number): RollResult
	local usesSpell = if spec.Power then spec.Power == "Spell" else spec.Type ~= "Physical"
	local power = if usesSpell then stats.SpellPower else stats.AttackPower
	local base = power * spec.Scale + (spec.Flat or 0)
	local variance = 0.92 + rng() * 0.16
	local critChance = stats.CritChance + (spec.CritBonus or 0)
	local isCrit = rng() < critChance
	local amount = base * variance * multiplier
	if isCrit then
		amount *= stats.CritDamage
	end
	return { Amount = math.max(1, amount), IsCrit = isCrit }
end

function Formulas.MitigatedDamage(amount: number, damageType: string, target: Stats, attackerLevel: number): number
	if damageType == "True" then
		return amount
	end
	local defense = if damageType == "Physical" then target.Armor else target.Resistance
	return amount * Formulas.Mitigation(defense, attackerLevel)
end

-- XP needed to go from `level` to `level + 1`.
function Formulas.XPToNext(level: number): number
	if level >= Formulas.MaxLevel then
		return math.huge
	end
	return math.floor(120 * level ^ 1.55 + 60 * level)
end

-- Applies XP and returns new level, remaining XP and number of levels gained (respects cap).
function Formulas.ApplyXP(level: number, xp: number, gained: number, cap: number?): (number, number, number)
	local maxLevel = cap or Formulas.LevelCap
	local newLevel = level
	local pool = xp + math.max(0, gained)
	local ups = 0
	while newLevel < maxLevel and pool >= Formulas.XPToNext(newLevel) do
		pool -= Formulas.XPToNext(newLevel)
		newLevel += 1
		ups += 1
	end
	if newLevel >= maxLevel then
		pool = math.min(pool, Formulas.XPToNext(newLevel) - 1)
	end
	return newLevel, pool, ups
end

-- Kill XP with level-difference falloff (grey mobs give little, harder mobs give more).
function Formulas.KillXP(baseXP: number, enemyLevel: number, playerLevel: number): number
	local diff = enemyLevel - playerLevel
	local factor = math.clamp(1 + diff * 0.15, 0.1, 1.6)
	return math.max(1, math.floor(baseXP * factor + 0.5))
end

-- Enemy stat scaling by level (enemy configs are authored at level 1).
function Formulas.EnemyHealth(base: number, level: number): number
	return math.floor(base * (1 + 0.32 * (level - 1)) + 0.5)
end

function Formulas.EnemyPower(base: number, level: number): number
	return base * (1 + 0.2 * (level - 1))
end

-- Counts equipped pieces per set and returns active bonus modifier lists.
function Formulas.SetBonuses(equippedSetIds: { string }, sets: { [string]: any }): ({ any }, { [string]: number })
	local counts: { [string]: number } = {}
	for _, setId in equippedSetIds do
		counts[setId] = (counts[setId] or 0) + 1
	end
	local mods = {}
	for setId, count in counts do
		local set = sets[setId]
		if set then
			for threshold, bonus in set.Bonuses do
				if count >= threshold then
					for _, mod in bonus.Mods do
						table.insert(mods, mod)
					end
				end
			end
		end
	end
	return mods, counts
end

return Formulas
