--!strict
--[[
	Classes — combat contract shared by the server (CombatService/PlayerCombat), the client
	(prediction, skill bar, animation) and the docs.

	TIMING CONTRACT
	  • Every ActionDef.Clip is played scaled so the clip spans exactly ActionDef.Duration.
	    Animation clips MUST be authored with Length == Duration and their impact pose at the
	    hit `At` time, so what the player sees matches the server hit moment.
	  • Hit/projectile `At` values are seconds after the server accepts the action.

	MODIFIERS (specs + talents)
	  { Stat = "CritChance", Op = "Add"|"Mul", Value = n }            → Formulas.ComputeStats
	  { Action = id, Path = "Hits.1.Damage.Scale", Op = "Add"|"Mul"|"Set", Value = n }
	  { Action = id, Path = "Hits.1.Statuses", Op = "Append", Value = StatusApply }
	  { Flag = name, Value = n }   → special behaviour implemented in PlayerCombat:
	      ParryRefund (resource on parry) · GuardReflect (fraction of blocked dmg reflected)
	      ExecuteBonus (dmg mult vs <30% hp) · BackstabCrit (crit chance from behind)
	      LifeSteal (fraction of dmg dealt) · ShieldOnDodge (absorb = Value*SpellPower)
	      MarkedBonus (dmg mult vs Marked) · KillCooldownRefund (seconds off all cds on kill)
	      UltimateGain (gauge gain multiplier) · AllyShield (Rune Ward also shields allies in 20 studs)
]]

local Types = require(script.Parent.Parent.Core.Types)

type ActionDef = Types.ActionDef
type Shape = Types.Shape

export type Modifier = {
	Stat: string?,
	Action: string?,
	Path: string?,
	Flag: string?,
	Op: ("Add" | "Mul" | "Set" | "Append")?,
	Value: any,
}

export type SpecDef = { Id: string, Name: string, NameEn: string, Description: string, Mods: { Modifier } }
export type TalentChoice = { Id: string, Name: string, Description: string, Mods: { Modifier } }
export type TalentTier = { Key: string, Level: number, Choices: { TalentChoice } }

export type ClassDef = {
	Id: string,
	Name: string,
	NameEn: string,
	Role: string,
	Identity: string,
	Description: string,
	Phase1: boolean,
	Color: Color3,
	Resource: { Type: string, Name: string, Color: Color3, StartFull: boolean, GainOnHit: number?, GainOnBlock: number?, DecayOutOfCombat: number? },
	BaseStats: { [string]: number },
	PerLevel: { [string]: number },
	PowerScaling: { Attack: { [string]: number }, Spell: { [string]: number } },
	Weapons: { MainHand: string, OffHand: string? },
	StarterKit: { string }, -- item ids granted at creation (auto-equipped where possible)
	AnimSet: string,
	Bar: { [string]: string }, -- input slot -> action id
	Actions: { [string]: ActionDef },
	Passives: { { Name: string, Description: string, Mods: { Modifier } } },
	Specs: { SpecDef },
	Talents: { TalentTier },
	-- design-only data for classes not yet playable
	Concept: { Skills: { string }, Ultimate: string, Specs: { string }, Silhouette: string }?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function cone(range: number, angle: number): Shape
	return { Type = "Cone", Range = range, Angle = angle }
end
local function sphere(radius: number, offset: Vector3?): Shape
	return { Type = "Sphere", Radius = radius, Offset = offset }
end
local function line(range: number, width: number): Shape
	return { Type = "Line", Range = range, Width = width }
end

local STANDARD_DODGE_COST = 25

-- ════════════════════════════════════════════════════════════════════════════
-- KNIGHT — щит, меч и стойкость. Ресурс: Решимость (копится в бою).
-- ════════════════════════════════════════════════════════════════════════════
local Knight: ClassDef = {
	Id = "Knight",
	Name = "Рыцарь",
	NameEn = "Knight",
	Role = "Защита и ближний бой",
	Identity = "Контроль атак, блок и парирование, защита союзников",
	Description = "Закованный в сталь страж. Держит удар щитом, ломает стойку врагов и обращает их натиск против них самих.",
	Phase1 = true,
	Color = rgb(196, 168, 104),
	Resource = { Type = "Resolve", Name = "Решимость", Color = rgb(222, 180, 90), StartFull = false, GainOnHit = 6, GainOnBlock = 10, DecayOutOfCombat = 4 },
	BaseStats = { MaxHealth = 230, MaxResource = 100, MaxStamina = 100, Strength = 14, Dexterity = 8, Intelligence = 5, Vitality = 13, Armor = 32, Resistance = 12, CritChance = 0.05, CritDamage = 1.5, MoveSpeed = 16, HealthRegen = 2, ResourceRegen = 2.5, StaminaRegen = 24, Haste = 0, Recovery = 1 },
	PerLevel = { MaxHealth = 30, Strength = 2, Vitality = 2, Dexterity = 0.5, Armor = 6, Resistance = 2 },
	PowerScaling = { Attack = { Strength = 1.0, Dexterity = 0.25 }, Spell = { Intelligence = 0.6, Strength = 0.4 } },
	Weapons = { MainHand = "Sword", OffHand = "Shield" },
	StarterKit = { "sword_recruit", "shield_recruit", "armor_recruit_chest", "armor_recruit_legs", "potion_health_minor", "potion_health_minor", "potion_health_minor" },
	AnimSet = "Knight",
	Bar = { Light = "Knight_Light1", Heavy = "Knight_Heavy", Secondary = "Knight_Block", Dodge = "Knight_Dodge", Skill1 = "Knight_ShieldBash", Skill2 = "Knight_HeavySlash", Skill3 = "Knight_IronGuard", Skill4 = "Knight_BannerCall", Ultimate = "Knight_RoyalJudgment" },
	Actions = {
		Knight_Light1 = {
			Id = "Knight_Light1", Name = "Рубящий удар", Description = "Широкий горизонтальный удар мечом.", Kind = "Light",
			Clip = "Knight_Light1", Duration = 0.55, CancelAfter = 0.36, ComboNext = "Knight_Light2", ComboWindow = 0.45, Targeting = "Aim", Icon = "⚔",
			Hits = { { At = 0.22, Shape = cone(8.5, 115), Damage = { Scale = 0.9, Type = "Physical" }, Poise = 10, Reaction = "Light", VFX = "Hit_Slash" } },
			VFX = { { At = 0.12, Id = "Trail_Sword" } },
		},
		Knight_Light2 = {
			Id = "Knight_Light2", Name = "Обратный удар", Description = "Возвратный удар с разворота корпуса.", Kind = "Light",
			Clip = "Knight_Light2", Duration = 0.55, CancelAfter = 0.36, ComboNext = "Knight_Light3", ComboWindow = 0.45, Targeting = "Aim", Icon = "⚔",
			Hits = { { At = 0.2, Shape = cone(8.5, 120), Damage = { Scale = 0.95, Type = "Physical" }, Poise = 10, Reaction = "Light", VFX = "Hit_Slash" } },
			VFX = { { At = 0.1, Id = "Trail_Sword" } },
		},
		Knight_Light3 = {
			Id = "Knight_Light3", Name = "Пронзающий выпад", Description = "Завершающий выпад с шагом вперёд.", Kind = "Light",
			Clip = "Knight_Light3", Duration = 0.8, CancelAfter = 0.6, Targeting = "Aim", Icon = "⚔",
			Moves = { { At = 0.22, Distance = 4, Time = 0.14 } },
			Hits = { { At = 0.38, Shape = line(10, 4.5), Damage = { Scale = 1.45, Type = "Physical" }, Poise = 26, Reaction = "Heavy", Knockback = 18, VFX = "Hit_Pierce" } },
			VFX = { { At = 0.25, Id = "Trail_Sword" } },
		},
		Knight_Heavy = {
			Id = "Knight_Heavy", Name = "Сокрушающий замах", Description = "Медленный удар сверху. Не прерывается во время замаха.", Kind = "Heavy",
			Clip = "Knight_Heavy", Duration = 1.25, CancelAfter = 1.0, StaminaCost = 20, Targeting = "Aim", Icon = "⚒", SuperArmor = { 0.25, 0.8 },
			Hits = { { At = 0.72, Shape = cone(10, 75), Damage = { Scale = 2.2, Type = "Physical", CanParry = false }, Poise = 45, Reaction = "Heavy", Knockback = 22, VFX = "Hit_HeavyImpact" } },
			VFX = { { At = 0.2, Id = "Windup_Steel" }, { At = 0.55, Id = "Trail_SwordHeavy" }, { At = 0.72, Id = "Ground_Crack" } },
		},
		Knight_Block = {
			Id = "Knight_Block", Name = "Блок щитом", Description = "Удерживайте, чтобы блокировать (−75% урона, тратит выносливость). Первые 0.22 с — парирование: атакующий теряет равновесие.", Kind = "Block",
			Clip = "Knight_BlockStart", Duration = 0.22, StaminaCost = 0, Targeting = "Aim", Icon = "⛨",
		},
		Knight_Dodge = {
			Id = "Knight_Dodge", Name = "Перекат", Description = "Короткий перекат. Неуязвимость в начале движения.", Kind = "Dodge",
			Clip = "Dodge_Roll", Duration = 0.6, StaminaCost = STANDARD_DODGE_COST, Invulnerable = { 0.04, 0.34 }, Targeting = "Aim", Icon = "↷",
			Moves = { { At = 0.02, Distance = 13, Time = 0.42 } },
		},
		Knight_ShieldBash = {
			Id = "Knight_ShieldBash", Name = "Удар щитом", Description = "Рывок вперёд и удар щитом: оглушает цель на 1.2 с и сбивает её атаку.", Kind = "Skill",
			Clip = "Knight_ShieldBash", Duration = 0.65, Cooldown = 8, ResourceCost = 15, CancelAfter = 0.5, Targeting = "Aim", Icon = "⛊", UnlockLevel = 1,
			Moves = { { At = 0.08, Distance = 7, Time = 0.14 } },
			Hits = { { At = 0.22, Shape = { Type = "Box", Width = 5.5, Length = 6.5 }, Damage = { Scale = 0.8, Type = "Physical", CanBlock = false }, Poise = 50, Reaction = "Heavy", Knockback = 14, Statuses = { { Id = "Stun", Duration = 1.2 } }, VFX = "Hit_ShieldImpulse" } },
			VFX = { { At = 0.08, Id = "Dash_Dust" } },
		},
		Knight_HeavySlash = {
			Id = "Knight_HeavySlash", Name = "Тяжёлое рассечение", Description = "Длинный замах и широкий разрез: высокий урон, кровотечение и отбрасывание.", Kind = "Skill",
			Clip = "Knight_HeavySlash", Duration = 1.1, Cooldown = 10, ResourceCost = 30, CancelAfter = 0.9, Targeting = "Aim", Icon = "⟋", UnlockLevel = 2, SuperArmor = { 0.2, 0.7 },
			Hits = { { At = 0.62, Shape = cone(11.5, 160), Damage = { Scale = 2.6, Type = "Physical" }, Poise = 40, Reaction = "Heavy", Knockback = 26, Statuses = { { Id = "Bleed", Duration = 5, Magnitude = 4, Stacks = 2 } }, VFX = "Hit_HeavySlash" } },
			VFX = { { At = 0.15, Id = "Windup_Steel" }, { At = 0.5, Id = "Arc_HeavySlash" } },
		},
		Knight_IronGuard = {
			Id = "Knight_IronGuard", Name = "Железная стойка", Description = "На 5 с снижает входящий урон на 40% и даёт непоколебимость. Провоцирует ближайших врагов.", Kind = "Skill",
			Clip = "Knight_IronGuard", Duration = 0.6, Cooldown = 18, ResourceCost = 20, Targeting = "Self", Icon = "⛨", UnlockLevel = 3, MoveLock = false,
			SelfStatuses = { { Id = "Guarded", Duration = 5, Magnitude = 0.6 } },
			Hits = { { At = 0.3, Shape = sphere(14), Damage = { Scale = 0.25, Type = "Physical", CanBlock = false, CanDodge = false }, Reaction = "None", VFX = "Pulse_IronGuard" } },
			VFX = { { At = 0.25, Id = "Aura_IronGuard" } },
		},
		Knight_BannerCall = {
			Id = "Knight_BannerCall", Name = "Клич знамени", Description = "Боевой клич: вы и союзники в 25 studs получаете +10% урона и скорости на 8 с и восстанавливаете здоровье.", Kind = "Skill",
			Clip = "Knight_BannerCall", Duration = 0.9, Cooldown = 25, ResourceCost = 30, Targeting = "Self", Icon = "⚑", UnlockLevel = 4,
			SelfStatuses = { { Id = "Rallied", Duration = 8 } },
			Hits = { { At = 0.45, Shape = sphere(25), Heal = { Scale = 0.6, Flat = 20, Target = "Allies" }, Statuses = { { Id = "Rallied", Duration = 8 } }, VFX = "Pulse_Banner" } },
		},
		Knight_RoyalJudgment = {
			Id = "Knight_RoyalJudgment", Name = "Королевский приговор", Description = "Прыжок и удар освящённым клинком в землю: огромный урон по области, сбивает с ног, затем волна света.", Kind = "Ultimate",
			Clip = "Knight_RoyalJudgment", Duration = 2.0, UltimateCost = 100, Targeting = "Aim", Icon = "♛", Invulnerable = { 0.15, 1.05 },
			Moves = { { At = 0.25, Distance = 10, Time = 0.55 } },
			Hits = {
				{ At = 0.95, Shape = sphere(14), Damage = { Scale = 4.5, Type = "Holy", CanBlock = false }, Poise = 120, Reaction = "Knockdown", Knockback = 30, Statuses = { { Id = "Knockdown", Duration = 1.4 } }, VFX = "Impact_RoyalJudgment", Telegraph = true },
				{ At = 1.4, Shape = { Type = "Ring", Inner = 6, Radius = 22 }, Damage = { Scale = 1.5, Type = "Holy" }, Poise = 30, Reaction = "Light", VFX = "Wave_Holy" },
			},
			VFX = { { At = 0.05, Id = "Charge_Holy" }, { At = 0.95, Id = "Ground_Sigil_Holy" } },
		},
	},
	Passives = {
		{ Name = "Закалённый в строю", Description = "Блок тратит на 20% меньше выносливости.", Mods = { { Flag = "BlockEfficiency", Value = 0.2 } } },
		{ Name = "Клятва щита", Description = "Успешное парирование восстанавливает 20 Решимости.", Mods = { { Flag = "ParryRefund", Value = 20 } } },
	},
	Specs = {
		{ Id = "Defender", Name = "Защитник", NameEn = "Defender", Description = "Железная стойка отражает 30% заблокированного урона; +15% брони.", Mods = { { Flag = "GuardReflect", Value = 0.3 }, { Stat = "Armor", Op = "Mul", Value = 1.15 }, { Action = "Knight_IronGuard", Path = "Cooldown", Op = "Mul", Value = 0.75 } } },
		{ Id = "Warlord", Name = "Полководец", NameEn = "Warlord", Description = "Клич знамени дольше и сильнее; Тяжёлое рассечение делает цели уязвимыми.", Mods = { { Action = "Knight_BannerCall", Path = "Cooldown", Op = "Mul", Value = 0.7 }, { Action = "Knight_HeavySlash", Path = "Hits.1.Statuses", Op = "Append", Value = { Id = "Vulnerable", Duration = 5, Magnitude = 1.2 } } } },
		{ Id = "Vanguard", Name = "Авангард", NameEn = "Vanguard", Description = "Удар щитом превращается в длинный таран; выпады дальше и сильнее.", Mods = { { Action = "Knight_ShieldBash", Path = "Moves.1.Distance", Op = "Set", Value = 16 }, { Action = "Knight_ShieldBash", Path = "Cooldown", Op = "Mul", Value = 0.8 }, { Action = "Knight_Light3", Path = "Hits.1.Damage.Scale", Op = "Add", Value = 0.4 } } },
	},
	Talents = {
		{ Key = "T1", Level = 2, Choices = {
			{ Id = "K_Bulwark", Name = "Бастион", Description = "+12% здоровья.", Mods = { { Stat = "MaxHealth", Op = "Mul", Value = 1.12 } } },
			{ Id = "K_Edge", Name = "Острая кромка", Description = "+6% шанса крита.", Mods = { { Stat = "CritChance", Op = "Add", Value = 0.06 } } },
		} },
		{ Key = "T2", Level = 4, Choices = {
			{ Id = "K_Riposte", Name = "Ответный удар", Description = "Парирование восстанавливает ещё 15 Решимости.", Mods = { { Flag = "ParryRefund", Value = 15 } } },
			{ Id = "K_Momentum", Name = "Натиск", Description = "Удар щитом перезаряжается на 2 с быстрее.", Mods = { { Action = "Knight_ShieldBash", Path = "Cooldown", Op = "Add", Value = -2 } } },
		} },
		{ Key = "T3", Level = 6, Choices = {
			{ Id = "K_Executioner", Name = "Палач", Description = "+25% урона по целям ниже 30% здоровья.", Mods = { { Flag = "ExecuteBonus", Value = 1.25 } } },
			{ Id = "K_Vigil", Name = "Бдение", Description = "+30% восстановления здоровья, +10% лечения.", Mods = { { Stat = "HealthRegen", Op = "Mul", Value = 1.3 }, { Stat = "Recovery", Op = "Add", Value = 0.1 } } },
		} },
		{ Key = "T4", Level = 8, Choices = {
			{ Id = "K_Crown", Name = "Воля короны", Description = "Шкала высшей способности заполняется на 25% быстрее.", Mods = { { Flag = "UltimateGain", Value = 1.25 } } },
			{ Id = "K_Iron", Name = "Железная кожа", Description = "+10% брони и сопротивления.", Mods = { { Stat = "Armor", Op = "Mul", Value = 1.1 }, { Stat = "Resistance", Op = "Mul", Value = 1.1 } } },
		} },
	},
}

-- ════════════════════════════════════════════════════════════════════════════
-- MAGE — стихийная магия. Ресурс: Мана.
-- ════════════════════════════════════════════════════════════════════════════
local Mage: ClassDef = {
	Id = "Mage",
	Name = "Маг",
	NameEn = "Mage",
	Role = "Магический урон",
	Identity = "Стихийная энергия, контроль дистанции, щиты",
	Description = "Выпускник Академии Ауренхольма. Управляет чистой энергией, огнём и льдом, держит врагов на расстоянии.",
	Phase1 = true,
	Color = rgb(120, 140, 255),
	Resource = { Type = "Mana", Name = "Мана", Color = rgb(90, 140, 255), StartFull = true },
	BaseStats = { MaxHealth = 160, MaxResource = 130, MaxStamina = 90, Strength = 5, Dexterity = 8, Intelligence = 15, Vitality = 8, Armor = 10, Resistance = 22, CritChance = 0.06, CritDamage = 1.55, MoveSpeed = 16, HealthRegen = 1.5, ResourceRegen = 7, StaminaRegen = 22, Haste = 0, Recovery = 1 },
	PerLevel = { MaxHealth = 19, MaxResource = 9, Intelligence = 2.2, Vitality = 1, Dexterity = 0.5, Armor = 2, Resistance = 4 },
	PowerScaling = { Attack = { Strength = 0.5, Dexterity = 0.3 }, Spell = { Intelligence = 1.25 } },
	Weapons = { MainHand = "Staff" },
	StarterKit = { "staff_apprentice", "armor_apprentice_chest", "armor_apprentice_legs", "potion_health_minor", "potion_health_minor", "potion_mana_minor" },
	AnimSet = "Mage",
	Bar = { Light = "Mage_Light1", Heavy = "Mage_Heavy", Secondary = "Mage_ManaShield", Dodge = "Mage_Blink", Skill1 = "Mage_ArcaneBolt", Skill2 = "Mage_FlameWave", Skill3 = "Mage_RuneWard", Skill4 = "Mage_FrostRing", Ultimate = "Mage_MeteorFragment" },
	Actions = {
		Mage_Light1 = {
			Id = "Mage_Light1", Name = "Искра", Description = "Быстрый самонаводящийся разряд.", Kind = "Light",
			Clip = "Mage_Light1", Duration = 0.5, CancelAfter = 0.3, ComboNext = "Mage_Light2", ComboWindow = 0.5, Targeting = "Aim", Icon = "✶", MoveLock = false,
			Projectiles = { { At = 0.2, Speed = 140, Range = 85, Radius = 1.2, Damage = { Scale = 0.75, Type = "Arcane" }, Poise = 6, Reaction = "Light", Homing = 2.5, Visual = "Proj_Spark" } },
		},
		Mage_Light2 = {
			Id = "Mage_Light2", Name = "Искра", Description = "Второй разряд с другой руки.", Kind = "Light",
			Clip = "Mage_Light2", Duration = 0.5, CancelAfter = 0.3, ComboNext = "Mage_Light3", ComboWindow = 0.5, Targeting = "Aim", Icon = "✶", MoveLock = false,
			Projectiles = { { At = 0.18, Speed = 140, Range = 85, Radius = 1.2, Damage = { Scale = 0.75, Type = "Arcane" }, Poise = 6, Reaction = "Light", Homing = 2.5, Visual = "Proj_Spark" } },
		},
		Mage_Light3 = {
			Id = "Mage_Light3", Name = "Тройная искра", Description = "Веер из трёх разрядов.", Kind = "Light",
			Clip = "Mage_Light3", Duration = 0.75, CancelAfter = 0.55, Targeting = "Aim", Icon = "✶",
			Projectiles = { { At = 0.35, Speed = 130, Range = 80, Radius = 1.2, Damage = { Scale = 0.6, Type = "Arcane" }, Poise = 8, Reaction = "Light", Count = 3, Spread = 9, Homing = 1.5, Visual = "Proj_Spark" } },
		},
		Mage_Heavy = {
			Id = "Mage_Heavy", Name = "Чародейский взрыв", Description = "Сгусток энергии взрывается в выбранной точке.", Kind = "Heavy",
			Clip = "Mage_Heavy", Duration = 1.1, CancelAfter = 0.9, ResourceCost = 12, Targeting = "Ground", Range = 45, Icon = "✺",
			Hits = { { At = 0.78, Shape = sphere(7.5), Damage = { Scale = 2.0, Type = "Arcane" }, Poise = 30, Reaction = "Heavy", Knockback = 12, VFX = "Impact_Arcane", Telegraph = true } },
			VFX = { { At = 0.1, Id = "Charge_Arcane" } },
		},
		Mage_ManaShield = {
			Id = "Mage_ManaShield", Name = "Мана-щит", Description = "Удерживайте: −60% урона, поглощённый урон расходует ману вместо выносливости. Без парирования.", Kind = "Block",
			Clip = "Mage_ShieldStart", Duration = 0.2, Targeting = "Aim", Icon = "◈",
		},
		Mage_Blink = {
			Id = "Mage_Blink", Name = "Мерцание", Description = "Мгновенный короткий перенос сквозь атаки.", Kind = "Dodge",
			Clip = "Dodge_Blink", Duration = 0.38, StaminaCost = STANDARD_DODGE_COST, Invulnerable = { 0.0, 0.26 }, Targeting = "Aim", Icon = "⇢",
			Moves = { { At = 0.04, Distance = 16, Time = 0.1 } },
			VFX = { { At = 0.0, Id = "Blink_Out" }, { At = 0.14, Id = "Blink_In" } },
		},
		Mage_ArcaneBolt = {
			Id = "Mage_ArcaneBolt", Name = "Чародейская стрела", Description = "Тяжёлый снаряд с понятной траекторией; взрывается при попадании.", Kind = "Skill",
			Clip = "Mage_ArcaneBolt", Duration = 0.7, Cooldown = 4, ResourceCost = 14, CancelAfter = 0.5, Targeting = "Aim", Icon = "➶", UnlockLevel = 1,
			Projectiles = { { At = 0.38, Speed = 110, Range = 95, Radius = 1.8, Damage = { Scale = 1.8, Type = "Arcane" }, Poise = 25, Reaction = "Heavy", Homing = 1.2, Explode = sphere(5), Visual = "Proj_ArcaneBolt" } },
			VFX = { { At = 0.05, Id = "Charge_Arcane" } },
		},
		Mage_FlameWave = {
			Id = "Mage_FlameWave", Name = "Огненная волна", Description = "Направленная волна пламени: поджигает и отбрасывает.", Kind = "Skill",
			Clip = "Mage_FlameWave", Duration = 0.95, Cooldown = 9, ResourceCost = 25, CancelAfter = 0.75, Targeting = "Aim", Icon = "♨", UnlockLevel = 2,
			Hits = { { At = 0.45, Shape = cone(17, 70), Damage = { Scale = 2.0, Type = "Fire" }, Poise = 30, Reaction = "Heavy", Knockback = 24, Statuses = { { Id = "Burn", Duration = 4, Magnitude = 5 } }, VFX = "Impact_Fire" } },
			VFX = { { At = 0.1, Id = "Charge_Fire" }, { At = 0.42, Id = "Wave_Fire" } },
		},
		Mage_RuneWard = {
			Id = "Mage_RuneWard", Name = "Руническая защита", Description = "Кольцо рун поглощает урон (1.6× силы заклинаний) и снижает входящий урон на 15% на 8 с.", Kind = "Skill",
			Clip = "Mage_RuneWard", Duration = 0.7, Cooldown = 20, ResourceCost = 30, Targeting = "Self", Icon = "ᛟ", UnlockLevel = 3, MoveLock = false,
			Shield = { At = 0.3, Scale = 1.6, Duration = 8 },
			SelfStatuses = { { Id = "Warded", Duration = 8 } },
			VFX = { { At = 0.3, Id = "Aura_RuneWard" } },
		},
		Mage_FrostRing = {
			Id = "Mage_FrostRing", Name = "Ледяное кольцо", Description = "Кольцо холода вокруг мага: замедляет и сковывает врагов на 1.5 с.", Kind = "Skill",
			Clip = "Mage_FrostRing", Duration = 0.8, Cooldown = 14, ResourceCost = 25, Targeting = "Self", Icon = "❄", UnlockLevel = 4,
			Hits = { { At = 0.4, Shape = sphere(12), Damage = { Scale = 1.2, Type = "Frost" }, Poise = 20, Reaction = "Light", Statuses = { { Id = "Root", Duration = 1.5 }, { Id = "Slow", Duration = 4, Magnitude = 0.5 } }, VFX = "Nova_Frost" } },
			VFX = { { At = 0.05, Id = "Charge_Frost" } },
		},
		Mage_MeteorFragment = {
			Id = "Mage_MeteorFragment", Name = "Осколок метеора", Description = "Призывает обломок звезды: область обозначается заранее, удар поджигает и сбивает с ног.", Kind = "Ultimate",
			Clip = "Mage_MeteorFragment", Duration = 2.2, UltimateCost = 100, Targeting = "Ground", Range = 60, Icon = "☄", SuperArmor = { 0, 2.2 },
			Hits = { { At = 1.6, Shape = sphere(16), Damage = { Scale = 6.0, Type = "Fire", CanBlock = false }, Poise = 120, Reaction = "Knockdown", Knockback = 35, Statuses = { { Id = "Knockdown", Duration = 1.2 }, { Id = "Burn", Duration = 6, Magnitude = 8, Stacks = 2 } }, VFX = "Impact_Meteor", Telegraph = true } },
			VFX = { { At = 0.1, Id = "Channel_Meteor" }, { At = 0.6, Id = "Meteor_Fall" } },
		},
	},
	Passives = {
		{ Name = "Резонанс", Description = "Критические заклинания восстанавливают 4 маны.", Mods = { { Flag = "CritManaRefund", Value = 4 } } },
		{ Name = "Тренированный разум", Description = "+5% к ускорению перезарядки.", Mods = { { Stat = "Haste", Op = "Add", Value = 0.05 } } },
	},
	Specs = {
		{ Id = "Elementalist", Name = "Элементалист", NameEn = "Elementalist", Description = "Огонь и лёд сильнее: волна пламени шире, кольцо льда больше и дольше сковывает.", Mods = { { Action = "Mage_FlameWave", Path = "Hits.1.Shape.Angle", Op = "Set", Value = 100 }, { Action = "Mage_FlameWave", Path = "Hits.1.Damage.Scale", Op = "Add", Value = 0.6 }, { Action = "Mage_FrostRing", Path = "Hits.1.Shape.Radius", Op = "Set", Value = 16 } } },
		{ Id = "ArcaneScholar", Name = "Чародей-учёный", NameEn = "Arcane Scholar", Description = "Чародейская стрела пробивает цели и перезаряжается быстрее; +10% маны.", Mods = { { Action = "Mage_ArcaneBolt", Path = "Projectiles.1.Pierce", Op = "Set", Value = 2 }, { Action = "Mage_ArcaneBolt", Path = "Cooldown", Op = "Set", Value = 2.5 }, { Stat = "MaxResource", Op = "Mul", Value = 1.1 } } },
		{ Id = "BattleMage", Name = "Боевой маг", NameEn = "Battle Mage", Description = "Руническая защита укрывает союзников; мерцание оставляет щит; +15% брони.", Mods = { { Flag = "AllyShield", Value = 1 }, { Flag = "ShieldOnDodge", Value = 0.4 }, { Stat = "Armor", Op = "Mul", Value = 1.15 } } },
	},
	Talents = {
		{ Key = "T1", Level = 2, Choices = {
			{ Id = "M_Focus", Name = "Сосредоточение", Description = "+15% восстановления маны.", Mods = { { Stat = "ResourceRegen", Op = "Mul", Value = 1.15 } } },
			{ Id = "M_Ember", Name = "Тлеющий уголь", Description = "+5% шанса крита.", Mods = { { Stat = "CritChance", Op = "Add", Value = 0.05 } } },
		} },
		{ Key = "T2", Level = 4, Choices = {
			{ Id = "M_Glyph", Name = "Плотные руны", Description = "Руническая защита поглощает на 40% больше.", Mods = { { Action = "Mage_RuneWard", Path = "Shield.Scale", Op = "Mul", Value = 1.4 } } },
			{ Id = "M_Quick", Name = "Быстрые пальцы", Description = "Огненная волна перезаряжается на 2 с быстрее.", Mods = { { Action = "Mage_FlameWave", Path = "Cooldown", Op = "Add", Value = -2 } } },
		} },
		{ Key = "T3", Level = 6, Choices = {
			{ Id = "M_Shatter", Name = "Раскол", Description = "Ледяное кольцо делает цели уязвимыми.", Mods = { { Action = "Mage_FrostRing", Path = "Hits.1.Statuses", Op = "Append", Value = { Id = "Vulnerable", Duration = 4, Magnitude = 1.2 } } } },
			{ Id = "M_Siphon", Name = "Сифон", Description = "5% урона заклинаниями возвращается здоровьем.", Mods = { { Flag = "LifeSteal", Value = 0.05 } } },
		} },
		{ Key = "T4", Level = 8, Choices = {
			{ Id = "M_Star", Name = "Звёздный зов", Description = "Шкала высшей способности заполняется на 25% быстрее.", Mods = { { Flag = "UltimateGain", Value = 1.25 } } },
			{ Id = "M_Mind", Name = "Бездонный разум", Description = "+15% силы заклинаний.", Mods = { { Stat = "SpellPower", Op = "Mul", Value = 1.15 } } },
		} },
	},
}

-- ════════════════════════════════════════════════════════════════════════════
-- RANGER — лук, метки, контроль дистанции. Ресурс: Концентрация.
-- ════════════════════════════════════════════════════════════════════════════
local Ranger: ClassDef = {
	Id = "Ranger",
	Name = "Следопыт",
	NameEn = "Ranger",
	Role = "Дальний бой",
	Identity = "Метки, ловушки и контроль дистанции",
	Description = "Разведчик пограничья. Отмечает цель, держит дистанцию и решает бой точными выстрелами.",
	Phase1 = true,
	Color = rgb(120, 180, 90),
	Resource = { Type = "Focus", Name = "Концентрация", Color = rgb(150, 210, 110), StartFull = true, GainOnHit = 3 },
	BaseStats = { MaxHealth = 175, MaxResource = 100, MaxStamina = 110, Strength = 8, Dexterity = 15, Intelligence = 7, Vitality = 9, Armor = 16, Resistance = 14, CritChance = 0.08, CritDamage = 1.6, MoveSpeed = 16.5, HealthRegen = 1.8, ResourceRegen = 8, StaminaRegen = 26, Haste = 0, Recovery = 1 },
	PerLevel = { MaxHealth = 22, Dexterity = 2.2, Strength = 0.6, Vitality = 1.2, Armor = 3, Resistance = 2.5 },
	PowerScaling = { Attack = { Dexterity = 1.05, Strength = 0.25 }, Spell = { Dexterity = 0.6, Intelligence = 0.5 } },
	Weapons = { MainHand = "Longbow" },
	StarterKit = { "bow_hunter", "armor_scout_chest", "armor_scout_legs", "potion_health_minor", "potion_health_minor", "potion_health_minor" },
	AnimSet = "Ranger",
	Bar = { Light = "Ranger_Light1", Heavy = "Ranger_BowBash", Secondary = "Ranger_AimedShot", Dodge = "Ranger_Dodge", Skill1 = "Ranger_QuickShot", Skill2 = "Ranger_MarkedTarget", Skill3 = "Ranger_EvasiveStep", Skill4 = "Ranger_ThornSnare", Ultimate = "Ranger_RainOfThorns" },
	Actions = {
		Ranger_Light1 = {
			Id = "Ranger_Light1", Name = "Выстрел", Description = "Быстрый выстрел навскидку.", Kind = "Light",
			Clip = "Ranger_Light1", Duration = 0.45, CancelAfter = 0.3, ComboNext = "Ranger_Light2", ComboWindow = 0.5, Targeting = "Aim", Icon = "➴", MoveLock = false,
			Projectiles = { { At = 0.22, Speed = 190, Range = 115, Radius = 1.0, Damage = { Scale = 0.72, Type = "Physical" }, Poise = 6, Reaction = "Light", Homing = 1.0, Gravity = 6, Visual = "Proj_Arrow" } },
		},
		Ranger_Light2 = {
			Id = "Ranger_Light2", Name = "Выстрел", Description = "Повторный выстрел.", Kind = "Light",
			Clip = "Ranger_Light2", Duration = 0.45, CancelAfter = 0.3, ComboNext = "Ranger_Light3", ComboWindow = 0.5, Targeting = "Aim", Icon = "➴", MoveLock = false,
			Projectiles = { { At = 0.2, Speed = 190, Range = 115, Radius = 1.0, Damage = { Scale = 0.72, Type = "Physical" }, Poise = 6, Reaction = "Light", Homing = 1.0, Gravity = 6, Visual = "Proj_Arrow" } },
		},
		Ranger_Light3 = {
			Id = "Ranger_Light3", Name = "Двойной выстрел", Description = "Две стрелы веером.", Kind = "Light",
			Clip = "Ranger_Light3", Duration = 0.7, CancelAfter = 0.5, Targeting = "Aim", Icon = "➴",
			Projectiles = { { At = 0.34, Speed = 200, Range = 115, Radius = 1.0, Damage = { Scale = 0.65, Type = "Physical" }, Poise = 8, Reaction = "Light", Count = 2, Spread = 5, Homing = 0.8, Gravity = 6, Visual = "Proj_Arrow" } },
		},
		Ranger_BowBash = {
			Id = "Ranger_BowBash", Name = "Удар луком", Description = "Удар плечом лука и отскок назад: отбрасывает и выводит из равновесия.", Kind = "Heavy",
			Clip = "Ranger_BowBash", Duration = 0.75, CancelAfter = 0.55, StaminaCost = 15, Targeting = "Aim", Icon = "⤺",
			Hits = { { At = 0.28, Shape = cone(7.5, 110), Damage = { Scale = 1.0, Type = "Physical" }, Poise = 40, Reaction = "Heavy", Knockback = 45, VFX = "Hit_Blunt" } },
			Moves = { { At = 0.4, Distance = -7, Time = 0.2 } },
		},
		Ranger_AimedShot = {
			Id = "Ranger_AimedShot", Name = "Прицельный выстрел", Description = "Удерживайте, чтобы натянуть тетиву (до 3× урона, пробивает цели). Отпустите для выстрела.", Kind = "Secondary",
			Clip = "Ranger_AimedRelease", Duration = 0.45, ResourceCost = 10, Targeting = "Aim", Icon = "◎", Charge = { Min = 0.25, Max = 1.4, DamageMax = 3.0 },
			Projectiles = { { At = 0.05, Speed = 260, Range = 150, Radius = 1.1, Damage = { Scale = 1.1, Type = "Physical", CritBonus = 0.1 }, Poise = 30, Reaction = "Heavy", Pierce = 2, Gravity = 2, Visual = "Proj_ArrowCharged" } },
		},
		Ranger_Dodge = {
			Id = "Ranger_Dodge", Name = "Перекат", Description = "Быстрый перекат.", Kind = "Dodge",
			Clip = "Dodge_Roll", Duration = 0.55, StaminaCost = STANDARD_DODGE_COST, Invulnerable = { 0.03, 0.32 }, Targeting = "Aim", Icon = "↷",
			Moves = { { At = 0.02, Distance = 14, Time = 0.38 } },
		},
		Ranger_QuickShot = {
			Id = "Ranger_QuickShot", Name = "Шквал стрел", Description = "Три стремительных выстрела подряд.", Kind = "Skill",
			Clip = "Ranger_QuickShot", Duration = 0.9, Cooldown = 6, ResourceCost = 20, CancelAfter = 0.75, Targeting = "Aim", Icon = "⋙", UnlockLevel = 1,
			Projectiles = {
				{ At = 0.22, Speed = 210, Range = 115, Radius = 1.0, Damage = { Scale = 0.85, Type = "Physical" }, Poise = 8, Reaction = "Light", Homing = 1.5, Gravity = 4, Visual = "Proj_Arrow" },
				{ At = 0.42, Speed = 210, Range = 115, Radius = 1.0, Damage = { Scale = 0.85, Type = "Physical" }, Poise = 8, Reaction = "Light", Homing = 1.5, Gravity = 4, Visual = "Proj_Arrow" },
				{ At = 0.62, Speed = 210, Range = 115, Radius = 1.0, Damage = { Scale = 1.05, Type = "Physical" }, Poise = 14, Reaction = "Light", Homing = 1.5, Gravity = 4, Visual = "Proj_Arrow" },
			},
		},
		Ranger_MarkedTarget = {
			Id = "Ranger_MarkedTarget", Name = "Метка охотника", Description = "Помечает цель на 10 с: она получает на 20% больше урона от всех источников и видна сквозь скрытность.", Kind = "Skill",
			Clip = "Ranger_MarkedTarget", Duration = 0.55, Cooldown = 12, ResourceCost = 15, Targeting = "Target", Range = 70, Icon = "◎", UnlockLevel = 2, MoveLock = false,
			Projectiles = { { At = 0.25, Speed = 240, Range = 75, Radius = 1.2, Damage = { Scale = 0.5, Type = "Physical" }, Reaction = "Light", Homing = 8, Statuses = { { Id = "Marked", Duration = 10, Magnitude = 1.2 } }, Visual = "Proj_MarkArrow" } },
		},
		Ranger_EvasiveStep = {
			Id = "Ranger_EvasiveStep", Name = "Шаг уклонения", Description = "Отскок назад с выстрелом в прыжке: замедляет цель, даёт ускорение.", Kind = "Skill",
			Clip = "Ranger_EvasiveStep", Duration = 0.6, Cooldown = 10, ResourceCost = 10, Targeting = "Aim", Icon = "⇠", UnlockLevel = 3, Invulnerable = { 0, 0.3 },
			Moves = { { At = 0.02, Distance = -15, Time = 0.3 } },
			Projectiles = { { At = 0.32, Speed = 200, Range = 100, Radius = 1.1, Damage = { Scale = 1.0, Type = "Physical" }, Poise = 15, Reaction = "Light", Homing = 2, Statuses = { { Id = "Slow", Duration = 3, Magnitude = 0.55 } }, Visual = "Proj_Arrow" } },
			SelfStatuses = { { Id = "Haste", Duration = 3, Magnitude = 1.3 } },
			VFX = { { At = 0.02, Id = "Leaves_Burst" } },
		},
		Ranger_ThornSnare = {
			Id = "Ranger_ThornSnare", Name = "Терновый силок", Description = "Бросает силок в точку: колючие лозы опутывают врагов на 2.5 с и вызывают кровотечение.", Kind = "Skill",
			Clip = "Ranger_ThornSnare", Duration = 0.7, Cooldown = 14, ResourceCost = 20, Targeting = "Ground", Range = 35, Icon = "❦", UnlockLevel = 4,
			Hits = { { At = 0.55, Shape = sphere(6.5), Damage = { Scale = 0.6, Type = "Nature" }, Reaction = "Light", Statuses = { { Id = "Root", Duration = 2.5 }, { Id = "Bleed", Duration = 5, Magnitude = 3, Stacks = 2 } }, VFX = "Snare_Thorns", Telegraph = true } },
		},
		Ranger_RainOfThorns = {
			Id = "Ranger_RainOfThorns", Name = "Дождь шипов", Description = "Залп в небо: четыре волны терновых стрел накрывают выбранную область и замедляют врагов.", Kind = "Ultimate",
			Clip = "Ranger_RainOfThorns", Duration = 2.4, UltimateCost = 100, Targeting = "Ground", Range = 55, Icon = "☔",
			Hits = {
				{ At = 0.9, Shape = sphere(14), Damage = { Scale = 1.4, Type = "Nature" }, Poise = 15, Reaction = "Light", Statuses = { { Id = "Slow", Duration = 3, Magnitude = 0.5 } }, VFX = "Rain_Thorns", Telegraph = true },
				{ At = 1.3, Shape = sphere(14), Damage = { Scale = 1.4, Type = "Nature" }, Poise = 15, Reaction = "Light", VFX = "Rain_Thorns" },
				{ At = 1.7, Shape = sphere(14), Damage = { Scale = 1.4, Type = "Nature" }, Poise = 15, Reaction = "Light", VFX = "Rain_Thorns" },
				{ At = 2.1, Shape = sphere(14), Damage = { Scale = 1.8, Type = "Nature" }, Poise = 40, Reaction = "Heavy", Statuses = { { Id = "Root", Duration = 1.5 } }, VFX = "Rain_Thorns" },
			},
			VFX = { { At = 0.35, Id = "Volley_Sky" } },
		},
	},
	Passives = {
		{ Name = "Глаз охотника", Description = "+20% урона по помеченным целям.", Mods = { { Flag = "MarkedBonus", Value = 1.2 } } },
		{ Name = "Лёгкий шаг", Description = "Можно стрелять обычными атаками на ходу.", Mods = {} },
	},
	Specs = {
		{ Id = "Pathfinder", Name = "Первопроходец", NameEn = "Pathfinder", Description = "Ловушки и мобильность: силок больше и перезаряжается быстрее, шаг уклонения длиннее.", Mods = { { Action = "Ranger_ThornSnare", Path = "Hits.1.Shape.Radius", Op = "Set", Value = 9 }, { Action = "Ranger_ThornSnare", Path = "Cooldown", Op = "Mul", Value = 0.7 }, { Action = "Ranger_EvasiveStep", Path = "Moves.1.Distance", Op = "Set", Value = -20 } } },
		{ Id = "Hawkeye", Name = "Соколиный глаз", NameEn = "Hawkeye", Description = "Прицельный выстрел заряжается быстрее и бьёт сильнее; +10% урона крита.", Mods = { { Action = "Ranger_AimedShot", Path = "Charge.Max", Op = "Set", Value = 1.0 }, { Action = "Ranger_AimedShot", Path = "Charge.DamageMax", Op = "Set", Value = 3.6 }, { Stat = "CritDamage", Op = "Add", Value = 0.1 } } },
		{ Id = "Beastwarden", Name = "Страж зверей", NameEn = "Beastwarden", Description = "Метка охотника распространяется на врагов рядом с целью и ослабляет их.", Mods = { { Action = "Ranger_MarkedTarget", Path = "Projectiles.1.Explode", Op = "Set", Value = { Type = "Sphere", Radius = 8 } }, { Action = "Ranger_MarkedTarget", Path = "Projectiles.1.Statuses", Op = "Append", Value = { Id = "Weakened", Duration = 6, Magnitude = 0.85 } } } },
	},
	Talents = {
		{ Key = "T1", Level = 2, Choices = {
			{ Id = "R_Keen", Name = "Зоркость", Description = "+6% шанса крита.", Mods = { { Stat = "CritChance", Op = "Add", Value = 0.06 } } },
			{ Id = "R_Wind", Name = "Попутный ветер", Description = "+8% скорости передвижения.", Mods = { { Stat = "MoveSpeed", Op = "Mul", Value = 1.08 } } },
		} },
		{ Key = "T2", Level = 4, Choices = {
			{ Id = "R_Volley", Name = "Шквал", Description = "Шквал стрел перезаряжается на 1.5 с быстрее.", Mods = { { Action = "Ranger_QuickShot", Path = "Cooldown", Op = "Add", Value = -1.5 } } },
			{ Id = "R_Barbs", Name = "Зазубрины", Description = "Обычные стрелы вызывают кровотечение.", Mods = { { Action = "Ranger_Light3", Path = "Projectiles.1.Statuses", Op = "Append", Value = { Id = "Bleed", Duration = 4, Magnitude = 2, Chance = 0.5 } } } },
		} },
		{ Key = "T3", Level = 6, Choices = {
			{ Id = "R_Predator", Name = "Хищник", Description = "Убийство сокращает все перезарядки на 1.5 с.", Mods = { { Flag = "KillCooldownRefund", Value = 1.5 } } },
			{ Id = "R_Hide", Name = "Плащ из шкур", Description = "+15% брони и здоровья.", Mods = { { Stat = "Armor", Op = "Mul", Value = 1.15 }, { Stat = "MaxHealth", Op = "Mul", Value = 1.08 } } },
		} },
		{ Key = "T4", Level = 8, Choices = {
			{ Id = "R_Storm", Name = "Буря шипов", Description = "Шкала высшей способности заполняется на 25% быстрее.", Mods = { { Flag = "UltimateGain", Value = 1.25 } } },
			{ Id = "R_Deadeye", Name = "Без промаха", Description = "+15% силы атаки.", Mods = { { Stat = "AttackPower", Op = "Mul", Value = 1.15 } } },
		} },
	},
}

-- ════════════════════════════════════════════════════════════════════════════
-- ASSASSIN — парные кинжалы, тень и яд. Ресурс: Энергия.
-- ════════════════════════════════════════════════════════════════════════════
local Assassin: ClassDef = {
	Id = "Assassin",
	Name = "Убийца",
	NameEn = "Assassin",
	Role = "Мобильность и точечный урон",
	Identity = "Скрытность, быстрые перемещения, яды",
	Description = "Тень в переулках Ауренхольма. Появляется за спиной, отравляет и исчезает прежде, чем враг поймёт, что случилось.",
	Phase1 = true,
	Color = rgb(150, 110, 200),
	Resource = { Type = "Energy", Name = "Энергия", Color = rgb(230, 210, 90), StartFull = true },
	BaseStats = { MaxHealth = 170, MaxResource = 100, MaxStamina = 120, Strength = 9, Dexterity = 15, Intelligence = 6, Vitality = 9, Armor = 14, Resistance = 12, CritChance = 0.12, CritDamage = 1.65, MoveSpeed = 17, HealthRegen = 1.8, ResourceRegen = 14, StaminaRegen = 28, Haste = 0, Recovery = 1 },
	PerLevel = { MaxHealth = 21, Dexterity = 2.2, Strength = 0.8, Vitality = 1.1, Armor = 2.5, Resistance = 2 },
	PowerScaling = { Attack = { Dexterity = 1.0, Strength = 0.35 }, Spell = { Dexterity = 0.5, Intelligence = 0.5 } },
	Weapons = { MainHand = "Dagger", OffHand = "Dagger" },
	StarterKit = { "daggers_cutpurse", "armor_shade_chest", "armor_shade_legs", "potion_health_minor", "potion_health_minor", "potion_health_minor" },
	AnimSet = "Assassin",
	Bar = { Light = "Assassin_Light1", Heavy = "Assassin_Lunge", Secondary = "Assassin_Deflect", Dodge = "Assassin_ShadowDash", Skill1 = "Assassin_TwinCut", Skill2 = "Assassin_ShadowStep", Skill3 = "Assassin_VenomMark", Skill4 = "Assassin_SmokeVeil", Ultimate = "Assassin_PhantomFlurry" },
	Actions = {
		Assassin_Light1 = {
			Id = "Assassin_Light1", Name = "Порез", Description = "Быстрый удар правым клинком.", Kind = "Light",
			Clip = "Assassin_Light1", Duration = 0.38, CancelAfter = 0.24, ComboNext = "Assassin_Light2", ComboWindow = 0.4, Targeting = "Aim", Icon = "†",
			Hits = { { At = 0.15, Shape = cone(7, 100), Damage = { Scale = 0.65, Type = "Physical" }, Poise = 6, Reaction = "Light", VFX = "Hit_Cut" } },
			VFX = { { At = 0.08, Id = "Trail_DaggerR" } },
		},
		Assassin_Light2 = {
			Id = "Assassin_Light2", Name = "Порез", Description = "Удар левым клинком.", Kind = "Light",
			Clip = "Assassin_Light2", Duration = 0.38, CancelAfter = 0.24, ComboNext = "Assassin_Light3", ComboWindow = 0.4, Targeting = "Aim", Icon = "†",
			Hits = { { At = 0.15, Shape = cone(7, 100), Damage = { Scale = 0.65, Type = "Physical" }, Poise = 6, Reaction = "Light", VFX = "Hit_Cut" } },
			VFX = { { At = 0.08, Id = "Trail_DaggerL" } },
		},
		Assassin_Light3 = {
			Id = "Assassin_Light3", Name = "Перекрёстный удар", Description = "Оба клинка крест-накрест.", Kind = "Light",
			Clip = "Assassin_Light3", Duration = 0.62, CancelAfter = 0.46, Targeting = "Aim", Icon = "†",
			Hits = {
				{ At = 0.2, Shape = cone(7.5, 110), Damage = { Scale = 0.6, Type = "Physical" }, Poise = 8, Reaction = "Light", VFX = "Hit_Cut" },
				{ At = 0.36, Shape = cone(7.5, 110), Damage = { Scale = 0.75, Type = "Physical" }, Poise = 14, Reaction = "Light", VFX = "Hit_CrossCut" },
			},
			VFX = { { At = 0.12, Id = "Trail_DaggerR" }, { At = 0.28, Id = "Trail_DaggerL" } },
		},
		Assassin_Lunge = {
			Id = "Assassin_Lunge", Name = "Пронзающий выпад", Description = "Стремительный выпад на 10 studs. +30% шанса крита.", Kind = "Heavy",
			Clip = "Assassin_Lunge", Duration = 0.8, CancelAfter = 0.6, StaminaCost = 15, Targeting = "Aim", Icon = "➹",
			Moves = { { At = 0.24, Distance = 10, Time = 0.14 } },
			Hits = { { At = 0.36, Shape = line(12, 4), Damage = { Scale = 2.0, Type = "Physical", CritBonus = 0.3 }, Poise = 30, Reaction = "Heavy", VFX = "Hit_Pierce" } },
			VFX = { { At = 0.22, Id = "Dash_Shadow" } },
		},
		Assassin_Deflect = {
			Id = "Assassin_Deflect", Name = "Отражение", Description = "Удерживайте: −35% урона. Окно парирования 0.3 с; удачное парирование усиливает следующий удар.", Kind = "Block",
			Clip = "Assassin_DeflectStart", Duration = 0.3, Targeting = "Aim", Icon = "⟊",
		},
		Assassin_ShadowDash = {
			Id = "Assassin_ShadowDash", Name = "Теневой рывок", Description = "Растворяется в тени на короткий рывок.", Kind = "Dodge",
			Clip = "Dodge_Dash", Duration = 0.42, StaminaCost = 20, Invulnerable = { 0.0, 0.3 }, Targeting = "Aim", Icon = "⇢",
			Moves = { { At = 0.02, Distance = 15, Time = 0.24 } },
			VFX = { { At = 0, Id = "Dash_Shadow" } },
		},
		Assassin_TwinCut = {
			Id = "Assassin_TwinCut", Name = "Двойной разрез", Description = "Два последовательных удара с вращением: кровотечение.", Kind = "Skill",
			Clip = "Assassin_TwinCut", Duration = 0.7, Cooldown = 5, ResourceCost = 25, CancelAfter = 0.55, Targeting = "Aim", Icon = "✂", UnlockLevel = 1,
			Hits = {
				{ At = 0.2, Shape = cone(8, 140), Damage = { Scale = 1.1, Type = "Physical" }, Poise = 12, Reaction = "Light", Statuses = { { Id = "Bleed", Duration = 5, Magnitude = 3 } }, VFX = "Hit_Cut" },
				{ At = 0.42, Shape = cone(8, 140), Damage = { Scale = 1.25, Type = "Physical" }, Poise = 18, Reaction = "Light", Statuses = { { Id = "Bleed", Duration = 5, Magnitude = 3 } }, VFX = "Hit_CrossCut" },
			},
			VFX = { { At = 0.15, Id = "Trail_DaggerR" }, { At = 0.36, Id = "Trail_DaggerL" } },
		},
		Assassin_ShadowStep = {
			Id = "Assassin_ShadowStep", Name = "Шаг тени", Description = "Перемещается за спину цели и бьёт в уязвимое место. Даёт усиление на 3 с.", Kind = "Skill",
			Clip = "Assassin_ShadowStep", Duration = 0.5, Cooldown = 10, ResourceCost = 20, Targeting = "Target", Range = 30, Icon = "◐", UnlockLevel = 2, Invulnerable = { 0, 0.2 },
			Moves = { { At = 0.05, Distance = 0, Time = 0.12, ToTarget = true } },
			Hits = { { At = 0.3, Shape = cone(7, 90), Damage = { Scale = 1.6, Type = "Physical", CritBonus = 0.25 }, Poise = 25, Reaction = "Heavy", VFX = "Hit_Backstab" } },
			SelfStatuses = { { Id = "Empowered", Duration = 3, Magnitude = 1.2 } },
			VFX = { { At = 0, Id = "Blink_Shadow" } },
		},
		Assassin_VenomMark = {
			Id = "Assassin_VenomMark", Name = "Метка яда", Description = "Отравляет цель: яд и ослабление её атак на 6 с.", Kind = "Skill",
			Clip = "Assassin_VenomMark", Duration = 0.5, Cooldown = 12, ResourceCost = 20, Targeting = "Aim", Icon = "☣", UnlockLevel = 3,
			Hits = { { At = 0.2, Shape = cone(7.5, 90), Damage = { Scale = 0.6, Type = "Nature" }, Reaction = "Light", Statuses = { { Id = "Venom", Duration = 8, Magnitude = 4, Stacks = 3 }, { Id = "Weakened", Duration = 6, Magnitude = 0.8 } }, VFX = "Hit_Venom" } },
		},
		Assassin_SmokeVeil = {
			Id = "Assassin_SmokeVeil", Name = "Дымовая завеса", Description = "Бросает дымовую бомбу: враги рядом замедлены, вы уходите в скрытность на 4 с.", Kind = "Skill",
			Clip = "Assassin_SmokeVeil", Duration = 0.5, Cooldown = 20, ResourceCost = 30, Targeting = "Self", Icon = "☁", UnlockLevel = 4, MoveLock = false,
			Hits = { { At = 0.2, Shape = sphere(11), Reaction = "None", Statuses = { { Id = "Slow", Duration = 3, Magnitude = 0.5 } }, VFX = "Smoke_Bomb" } },
			SelfStatuses = { { Id = "Stealth", Duration = 4 }, { Id = "Haste", Duration = 4, Magnitude = 1.25 } },
		},
		Assassin_PhantomFlurry = {
			Id = "Assassin_PhantomFlurry", Name = "Призрачный шквал", Description = "Серия из семи стремительных ударов теневыми клонами и завершающий удар, выводящий из равновесия.", Kind = "Ultimate",
			Clip = "Assassin_PhantomFlurry", Duration = 2.2, UltimateCost = 100, Targeting = "Aim", Icon = "✵", Invulnerable = { 0.1, 2.0 },
			Moves = { { At = 0.05, Distance = 8, Time = 0.12 } },
			Hits = {
				{ At = 0.3, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 0.5, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 0.7, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 0.9, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 1.1, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 1.3, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 1.5, Shape = sphere(10), Damage = { Scale = 0.9, Type = "Shadow" }, Poise = 8, Reaction = "Light", VFX = "Hit_Phantom" },
				{ At = 1.85, Shape = sphere(11), Damage = { Scale = 2.6, Type = "Shadow", CanBlock = false }, Poise = 90, Reaction = "Heavy", Statuses = { { Id = "Stagger", Duration = 1.2 } }, VFX = "Impact_PhantomFinal" },
			},
			VFX = { { At = 0.1, Id = "Phantom_Clones" } },
		},
	},
	Passives = {
		{ Name = "Удар в спину", Description = "+25% шанса крита при атаке со спины.", Mods = { { Flag = "BackstabCrit", Value = 0.25 } } },
		{ Name = "Острые рефлексы", Description = "Удачное парирование усиливает следующий удар на 50%.", Mods = { { Flag = "ParryEmpower", Value = 1.5 } } },
	},
	Specs = {
		{ Id = "Shadow", Name = "Тень", NameEn = "Shadow", Description = "Шаг тени перезаряжается мгновенно при убийстве; скрытность дольше.", Mods = { { Flag = "KillCooldownRefund", Value = 4 }, { Action = "Assassin_SmokeVeil", Path = "SelfStatuses.1.Duration", Op = "Set", Value = 6 } } },
		{ Id = "Phantom", Name = "Фантом", NameEn = "Phantom", Description = "Теневой рывок дальше и оставляет щит; призрачный шквал дольше бьёт.", Mods = { { Action = "Assassin_ShadowDash", Path = "Moves.1.Distance", Op = "Set", Value = 20 }, { Flag = "ShieldOnDodge", Value = 0.35 }, { Action = "Assassin_PhantomFlurry", Path = "Hits.8.Damage.Scale", Op = "Add", Value = 1.2 } } },
		{ Id = "Venom", Name = "Яд", NameEn = "Venom", Description = "Яд сильнее и распространяется: двойной разрез отравляет, метка яда бьёт по области.", Mods = { { Action = "Assassin_TwinCut", Path = "Hits.2.Statuses", Op = "Append", Value = { Id = "Venom", Duration = 6, Magnitude = 3, Stacks = 2 } }, { Action = "Assassin_VenomMark", Path = "Hits.1.Shape", Op = "Set", Value = { Type = "Sphere", Radius = 9 } } } },
	},
	Talents = {
		{ Key = "T1", Level = 2, Choices = {
			{ Id = "A_Edge", Name = "Бритва", Description = "+12% урона критов.", Mods = { { Stat = "CritDamage", Op = "Add", Value = 0.12 } } },
			{ Id = "A_Light", Name = "Лёгкая поступь", Description = "+10% скорости восстановления выносливости.", Mods = { { Stat = "StaminaRegen", Op = "Mul", Value = 1.1 } } },
		} },
		{ Key = "T2", Level = 4, Choices = {
			{ Id = "A_Thirst", Name = "Жажда", Description = "4% урона возвращается здоровьем.", Mods = { { Flag = "LifeSteal", Value = 0.04 } } },
			{ Id = "A_Swift", Name = "Стремительность", Description = "Двойной разрез перезаряжается на 1.5 с быстрее.", Mods = { { Action = "Assassin_TwinCut", Path = "Cooldown", Op = "Add", Value = -1.5 } } },
		} },
		{ Key = "T3", Level = 6, Choices = {
			{ Id = "A_Finisher", Name = "Добивание", Description = "+30% урона по целям ниже 30% здоровья.", Mods = { { Flag = "ExecuteBonus", Value = 1.3 } } },
			{ Id = "A_Cloak", Name = "Плащ ночи", Description = "+12% здоровья.", Mods = { { Stat = "MaxHealth", Op = "Mul", Value = 1.12 } } },
		} },
		{ Key = "T4", Level = 8, Choices = {
			{ Id = "A_Phantom", Name = "Призрачная воля", Description = "Шкала высшей способности заполняется на 25% быстрее.", Mods = { { Flag = "UltimateGain", Value = 1.25 } } },
			{ Id = "A_Lethal", Name = "Смертоносность", Description = "+8% шанса крита.", Mods = { { Stat = "CritChance", Op = "Add", Value = 0.08 } } },
		} },
	},
}

-- ════════════════════════════════════════════════════════════════════════════
-- Design-only classes (Phase G). Not selectable until fully implemented and tested.
-- ════════════════════════════════════════════════════════════════════════════
type Concept = { Id: string, Name: string, Role: string, Identity: string, Resource: string, Weapon: string, Silhouette: string, Skills: { string }, Ultimate: string, Specs: { string }, Color: Color3 }

local concepts: { Concept } = {
	{ Id = "Berserker", Name = "Берсерк", Role = "Агрессивный ближний бой", Identity = "Усиление при высоком риске: чем меньше здоровья, тем сильнее удары", Resource = "Ярость", Weapon = "Двуручный топор", Silhouette = "Обнажённые плечи, массивный топор за спиной, меховой воротник", Skills = { "Раскол черепа", "Кровавый вихрь", "Рёв ярости", "Бросок топора" }, Ultimate = "Безумие предков", Specs = { "Кровопийца", "Буревестник", "Несокрушимый" }, Color = rgb(190, 60, 40) },
	{ Id = "Paladin", Name = "Паладин", Role = "Защита и поддержка", Identity = "Освящённые ауры и защитные печати", Resource = "Вера", Weapon = "Молот и башенный щит", Silhouette = "Белый табард, нимб-кольцо за спиной, тяжёлый молот", Skills = { "Молот света", "Печать защиты", "Освящённая земля", "Возложение рук" }, Ultimate = "Суд небес", Specs = { "Храмовник", "Каратель", "Хранитель света" }, Color = rgb(240, 220, 150) },
	{ Id = "Cryomancer", Name = "Криомант", Role = "Контроль", Identity = "Замедление, заморозка, ледяные стены", Resource = "Холод", Weapon = "Ледяной жезл", Silhouette = "Плащ с инеем, кристаллы, парящие над плечом", Skills = { "Ледяное копьё", "Стена льда", "Метель", "Морозная броня" }, Ultimate = "Вечная зима", Specs = { "Ледяное сердце", "Буран", "Хрусталь" }, Color = rgb(150, 220, 255) },
	{ Id = "Necromancer", Name = "Некромант", Role = "Проклятия и призыв", Identity = "Управление нежитью и жизненной силой врагов", Resource = "Эссенция душ", Weapon = "Костяная коса-посох", Silhouette = "Рваный капюшон, костяные наплечники, фонарь душ", Skills = { "Поднять скелета", "Костяная тюрьма", "Похищение жизни", "Взрыв трупа" }, Ultimate = "Армия праха", Specs = { "Повелитель костей", "Жнец", "Чумной лекарь" }, Color = rgb(120, 200, 140) },
	{ Id = "Druid", Name = "Друид", Role = "Природа и поддержка", Identity = "Смена формы и восстановление", Resource = "Сила земли", Weapon = "Посох из живого дерева", Silhouette = "Рога из ветвей, плащ из листьев, тотемы", Skills = { "Облик медведя", "Облик волка", "Цветущая земля", "Лозы" }, Ultimate = "Пробуждение рощи", Specs = { "Страж рощи", "Дикий", "Целитель" }, Color = rgb(110, 170, 70) },
	{ Id = "Cleric", Name = "Клирик", Role = "Поддержка", Identity = "Защита и восстановление группы", Resource = "Благодать", Weapon = "Булава и святой символ", Silhouette = "Длинные ризы, кадило, сияющий символ", Skills = { "Исцеляющий свет", "Святой барьер", "Очищение", "Кара" }, Ultimate = "Воскрешение надежды", Specs = { "Целитель", "Инквизитор", "Пастырь" }, Color = rgb(250, 240, 200) },
	{ Id = "Spellblade", Name = "Клинок чар", Role = "Гибрид", Identity = "Зачарованное оружие и короткие заклинания между ударами", Resource = "Резонанс", Weapon = "Рунический длинный меч", Silhouette = "Светящиеся руны на клинке, лёгкий доспех с мантией", Skills = { "Пылающий клинок", "Рунический выпад", "Зеркальный щит", "Разрыв" }, Ultimate = "Клинок тысячи рун", Specs = { "Пламя", "Буря", "Пустота" }, Color = rgb(200, 120, 255) },
	{ Id = "Warlock", Name = "Чернокнижник", Role = "Проклятия", Identity = "Ослабление противников и сделки с тьмой", Resource = "Скверна", Weapon = "Гримуар и кинжал", Silhouette = "Цепи на поясе, парящая книга, рога-капюшон", Skills = { "Проклятие слабости", "Тёмный сгусток", "Пакт крови", "Страх" }, Ultimate = "Врата бездны", Specs = { "Демонолог", "Проклинатель", "Разрушитель" }, Color = rgb(150, 60, 160) },
	{ Id = "Monk", Name = "Монах", Role = "Комбо", Identity = "Непрерывные цепочки атак, ци", Resource = "Ци", Weapon = "Кастеты и посох", Silhouette = "Лёгкие одежды, бинты, чётки", Skills = { "Удар ладони", "Вихрь ног", "Поток ци", "Каменная кожа" }, Ultimate = "Тысяча кулаков", Specs = { "Путь ветра", "Путь горы", "Путь реки" }, Color = rgb(240, 170, 80) },
	{ Id = "Lancer", Name = "Копейщик", Role = "Ближний бой", Identity = "Дальность и контроль пространства", Resource = "Импульс", Weapon = "Копьё и малый щит", Silhouette = "Длинное копьё, высокий шлем с плюмажем", Skills = { "Прыжок дракона", "Круговой взмах", "Заслон копий", "Пронзание" }, Ultimate = "Небесное копьё", Specs = { "Драгун", "Фалангист", "Буревой" }, Color = rgb(90, 130, 200) },
	{ Id = "Duelist", Name = "Дуэлянт", Role = "Точность", Identity = "Контратаки и ритм", Resource = "Ритм", Weapon = "Рапира и дага", Silhouette = "Шляпа с пером, приталенный камзол, плащ на одном плече", Skills = { "Укол", "Ответный выпад", "Финт", "Вызов" }, Ultimate = "Танец клинков", Specs = { "Фехтовальщик", "Дуэлянт крови", "Танцор" }, Color = rgb(220, 90, 90) },
	{ Id = "Marksman", Name = "Стрелок", Role = "Дальний бой", Identity = "Точные одиночные выстрелы", Resource = "Порох", Weapon = "Тяжёлый арбалет", Silhouette = "Длинный плащ, монокуляр, болты на перевязи", Skills = { "Бронебойный болт", "Капкан", "Дымовая шашка", "Разрывной болт" }, Ultimate = "Выстрел в сердце", Specs = { "Снайпер", "Подрывник", "Охотник за головами" }, Color = rgb(170, 140, 100) },
	{ Id = "Summoner", Name = "Призыватель", Role = "Призыв", Identity = "Управление существами", Resource = "Связь", Weapon = "Сфера призыва", Silhouette = "Парящие сферы, мантия с кругами призыва", Skills = { "Дух волка", "Каменный страж", "Огненный бес", "Обмен местами" }, Ultimate = "Призыв древнего", Specs = { "Звероуст", "Элементалист", "Связующий" }, Color = rgb(120, 220, 210) },
	{ Id = "Bard", Name = "Бард", Role = "Поддержка", Identity = "Музыкальные усиления и контроль", Resource = "Вдохновение", Weapon = "Лютня-клинок", Silhouette = "Яркий плащ, лютня за спиной, перо в шляпе", Skills = { "Баллада стойкости", "Песнь быстроты", "Диссонанс", "Колыбельная" }, Ultimate = "Гимн героев", Specs = { "Менестрель", "Скальд", "Сирена" }, Color = rgb(240, 130, 190) },
	{ Id = "Engineer", Name = "Инженер", Role = "Тактика", Identity = "Устройства и конструкции", Resource = "Детали", Weapon = "Гаечный молот и пистоль", Silhouette = "Очки, рюкзак с инструментами, механическая рука", Skills = { "Турель", "Мина", "Щитовой генератор", "Крюк-кошка" }, Ultimate = "Механический голем", Specs = { "Механик", "Подрывник", "Изобретатель" }, Color = rgb(200, 160, 80) },
	{ Id = "ShadowKnight", Name = "Тёмный рыцарь", Role = "Защита и тьма", Identity = "Тёмная энергия, поглощение жизни, самопожертвование", Resource = "Тьма", Weapon = "Двуручный тёмный клинок", Silhouette = "Чёрные латы с рваным плащом, светящиеся прорези шлема", Skills = { "Тёмный разрез", "Цепи тьмы", "Пожирание", "Кровавая стена" }, Ultimate = "Затмение", Specs = { "Пожиратель", "Каратель тьмы", "Страж бездны" }, Color = rgb(90, 70, 120) },
}

local Classes: { [string]: ClassDef } = {
	Knight = Knight,
	Mage = Mage,
	Ranger = Ranger,
	Assassin = Assassin,
}

for _, concept in concepts do
	Classes[concept.Id] = {
		Id = concept.Id,
		Name = concept.Name,
		NameEn = concept.Id,
		Role = concept.Role,
		Identity = concept.Identity,
		Description = concept.Identity,
		Phase1 = false,
		Color = concept.Color,
		Resource = { Type = concept.Resource, Name = concept.Resource, Color = concept.Color, StartFull = true },
		BaseStats = {},
		PerLevel = {},
		PowerScaling = { Attack = {}, Spell = {} },
		Weapons = { MainHand = concept.Weapon },
		StarterKit = {},
		AnimSet = "Humanoid",
		Bar = {},
		Actions = {},
		Passives = {},
		Specs = {},
		Talents = {},
		Concept = { Skills = concept.Skills, Ultimate = concept.Ultimate, Specs = concept.Specs, Silhouette = concept.Silhouette },
	}
end

local Order = { "Knight", "Mage", "Ranger", "Assassin" }
for _, concept in concepts do
	table.insert(Order, concept.Id)
end

-- Flat action lookup (actions are globally unique ids).
local ActionIndex: { [string]: ActionDef } = {}
local ActionClass: { [string]: string } = {}
for classId, def in Classes do
	for actionId, action in def.Actions do
		assert(action.Id == actionId, `action id mismatch {actionId}`)
		ActionIndex[actionId] = action
		ActionClass[actionId] = classId
	end
end

return {
	Classes = Classes,
	Order = Order,
	Phase1 = { "Knight", "Mage", "Ranger", "Assassin" },
	Get = function(id: string): ClassDef?
		return Classes[id]
	end,
	GetAction = function(id: string): ActionDef?
		return ActionIndex[id]
	end,
	ClassOfAction = function(id: string): string?
		return ActionClass[id]
	end,
}
