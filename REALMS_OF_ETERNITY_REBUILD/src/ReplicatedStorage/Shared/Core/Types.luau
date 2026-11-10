--!strict
--[[
	Types — shared data contracts. Every service, controller and config file uses these shapes.
	Changing a type here is a contract change: update all users and the docs.
]]

-- ── Stats ─────────────────────────────────────────────────────────────────────
export type Stats = {
	MaxHealth: number,
	MaxResource: number,
	MaxStamina: number,
	Strength: number,
	Dexterity: number,
	Intelligence: number,
	Vitality: number,
	AttackPower: number, -- scales Physical damage
	SpellPower: number, -- scales elemental / magic damage and healing
	Armor: number, -- mitigates Physical
	Resistance: number, -- mitigates every non-Physical, non-True type
	CritChance: number, -- 0..1
	CritDamage: number, -- multiplier, e.g. 1.5
	MoveSpeed: number, -- studs/s walk speed
	HealthRegen: number, -- per second, out of combat x4
	ResourceRegen: number, -- per second
	StaminaRegen: number, -- per second
	Haste: number, -- 0..0.5 cooldown reduction fraction
	Recovery: number, -- multiplier on healing received
}

export type DamageType = "Physical" | "Fire" | "Frost" | "Nature" | "Shadow" | "Arcane" | "Holy" | "True"
export type Team = "Players" | "Enemies" | "Neutral"
export type CombatantKind = "Player" | "Enemy" | "Elite" | "MiniBoss" | "Boss" | "Ally" | "Summon"
export type Reaction = "None" | "Light" | "Heavy" | "Knockdown"

-- ── Hit shapes (resolved in Logic/Shapes, rendered by TelegraphController) ──────
-- Local space: origin at the actor's root on the ground, -Z forward (Roblox LookVector).
export type Shape = {
	Type: "Sphere" | "Cone" | "Box" | "Ring" | "Line",
	Radius: number?, -- Sphere / Ring outer
	Inner: number?, -- Ring inner radius
	Range: number?, -- Cone length / Line length
	Angle: number?, -- Cone full angle in degrees
	Width: number?, -- Line / Box width (X)
	Length: number?, -- Box length (Z)
	Height: number?, -- vertical tolerance (default 10)
	Offset: Vector3?, -- local offset of the shape origin
}

export type StatusApply = {
	Id: string, -- key in Config/Statuses
	Duration: number,
	Magnitude: number?, -- meaning defined per status (slow fraction, dps, etc.)
	Stacks: number?,
	Chance: number?, -- 0..1, default 1
}

export type DamageSpec = {
	Scale: number, -- multiplier on AttackPower or SpellPower
	Type: DamageType,
	Flat: number?,
	Power: ("Attack" | "Spell")?, -- default: Attack for Physical, Spell otherwise
	CanBlock: boolean?, -- default true
	CanParry: boolean?, -- default true for melee
	CanDodge: boolean?, -- default true
	CritBonus: number?, -- added crit chance
}

export type DamageInfo = {
	Amount: number,
	Type: DamageType,
	Source: any?, -- Combatant
	Ability: string?,
	IsCrit: boolean?,
	CanBlock: boolean?,
	CanParry: boolean?,
	CanDodge: boolean?,
	Poise: number?, -- stagger damage
	Reaction: Reaction?,
	Knockback: Vector3?, -- world-space impulse velocity
	Position: Vector3?, -- impact point (feedback)
	Tags: { [string]: boolean }?,
}

export type DamageResult = {
	Applied: number,
	Absorbed: number,
	Blocked: boolean,
	Parried: boolean,
	Dodged: boolean,
	Killed: boolean,
	IsCrit: boolean,
	GuardBroken: boolean,
}

-- ── Actions (player abilities, enemy attacks) ─────────────────────────────────
export type HitDef = {
	At: number, -- seconds after action start
	Shape: Shape,
	Damage: DamageSpec?,
	Heal: { Scale: number, Flat: number?, Target: ("Self" | "Allies")? }?,
	Poise: number?,
	Reaction: Reaction?,
	Knockback: number?, -- studs/s away from actor
	Statuses: { StatusApply }?,
	MaxTargets: number?,
	VFX: string?, -- impact effect id
	Telegraph: boolean?, -- show ground telegraph from action start until At
}

export type ProjectileDef = {
	At: number,
	Speed: number,
	Range: number,
	Radius: number,
	Damage: DamageSpec?,
	Poise: number?,
	Reaction: Reaction?,
	Statuses: { StatusApply }?,
	Homing: number?, -- turn rate (rad/s) toward current target
	Pierce: number?, -- extra targets
	Count: number?, -- volley size
	Spread: number?, -- degrees between volley projectiles
	Explode: Shape?, -- AoE on impact
	Visual: string, -- client visual id
	Gravity: number?, -- studs/s^2 downward (arrows lob)
}

export type MoveDef = {
	At: number,
	Distance: number, -- studs, along aim (negative = backwards)
	Time: number,
	ToTarget: boolean?, -- dash to target, stopping short
}

export type ActionKind = "Light" | "Heavy" | "Skill" | "Ultimate" | "Dodge" | "Block" | "Secondary"

export type ActionDef = {
	Id: string,
	Name: string, -- display (Russian UI)
	NameEn: string?,
	Description: string,
	Kind: ActionKind,
	Clip: string, -- AnimationLibrary clip name (scaled to Duration)
	Duration: number,
	Cooldown: number?,
	ResourceCost: number?,
	StaminaCost: number?,
	UltimateCost: number?,
	CancelAfter: number?, -- earliest time a new action may interrupt
	ComboNext: string?, -- next light/heavy in chain
	ComboWindow: number?, -- seconds after Duration the chain stays open
	Targeting: ("Aim" | "Target" | "Ground" | "Self")?,
	Range: number?, -- for Ground / Target actions
	Hits: { HitDef }?,
	Projectiles: { ProjectileDef }?,
	Moves: { MoveDef }?,
	SelfStatuses: { StatusApply }?,
	Shield: { At: number, Scale: number, Duration: number }?, -- absorb = Scale * SpellPower
	SuperArmor: { number }?, -- {from, to}
	Invulnerable: { number }?, -- {from, to}
	MoveLock: boolean?, -- root the actor while acting (default true for heavy/skills)
	Charge: { Min: number, Max: number, DamageMax: number }?, -- hold-to-charge
	VFX: { { At: number, Id: string } }?, -- cast-side effects (windup, trails)
	Sound: string?,
	Icon: string, -- glyph shown on the skill bar
	UnlockLevel: number?,
}

-- ── Persistence ───────────────────────────────────────────────────────────────
export type Appearance = {
	BodyType: number, -- 1..2 (frame variant)
	Height: number, -- -1..1 slider
	SkinTone: number, -- index into race palette
	Face: number,
	Hair: string,
	HairColor: number,
	EyeColor: number,
	Feature: string, -- race-specific detail (horns, ears, beard ...)
	FeatureColor: number,
	Marking: number, -- 0 = none
}

export type ItemInstance = {
	Uid: string,
	Id: string,
	Qty: number,
	Locked: boolean?,
	Favorite: boolean?,
	Acquired: number?,
}

export type QuestProgress = {
	Stage: number,
	Progress: { number },
	Started: number,
}

export type CharacterRecord = {
	Id: string,
	Name: string,
	Race: string,
	Class: string,
	Appearance: Appearance,
	Level: number,
	XP: number,
	Gold: number,
	Spec: string?,
	Talents: { [string]: number }, -- tier key -> choice index
	Inventory: { [string]: ItemInstance }, -- uid -> item
	InventoryCapacity: number,
	Equipment: { [string]: string }, -- slot -> uid
	Hotbar: { string }, -- consumable item ids for keys 1..4
	Quests: {
		Active: { [string]: QuestProgress },
		Completed: { [string]: number },
		Tracked: string?,
	},
	World: {
		Position: { number }?, -- {x, y, z} last safe position
		Waystone: string, -- respawn anchor id
		Discovered: { [string]: boolean },
		Flags: { [string]: boolean },
	},
	Bosses: { [string]: number }, -- bossId -> kill count
	Rewards: { [string]: boolean }, -- once-only reward keys (anti double-claim)
	Reputation: { [string]: number },
	Professions: { [string]: number },
	PlayTime: number,
	Created: number,
	LastPlayed: number,
}

export type Settings = {
	Keybinds: { [string]: string },
	CameraSensitivity: number,
	MusicVolume: number,
	SfxVolume: number,
	DamageNumbers: boolean,
	CameraShake: boolean,
	Quality: string,
}

export type Profile = {
	Version: number,
	Characters: { [string]: CharacterRecord },
	Order: { string },
	LastCharacter: string?,
	Settings: Settings,
	Bank: { Gold: number, Items: { [string]: ItemInstance }, Capacity: number },
	Achievements: { [string]: number },
	Created: number,
	SessionLock: { JobId: string, Time: number }?,
}

return {}
